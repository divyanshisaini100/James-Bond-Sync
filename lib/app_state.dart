import 'package:flutter/foundation.dart';

import 'models/paired_device.dart';
import 'models/pair_request.dart';
import 'services/clipboard_service.dart';
import 'services/history_store.dart';
import 'services/offline_queue.dart';
import 'services/pairing_manager.dart';
import 'services/p2p_client.dart';
import 'services/storage_service.dart';
import 'services/webrtc_p2p_client.dart';
import 'services/signaling_client.dart';
import 'services/sync_engine.dart';

class AppState extends ChangeNotifier {
  AppState() : clipboardService = ClipboardService() {
    storageService = StorageService();
    historyStore = HistoryStore(storageService: storageService);
    pairingManager = PairingManager(storageService: storageService);
    offlineQueue = OfflineQueue(storageService: storageService);
    signalingClient = WebSocketSignalingClient(
      url: _signalingUrl,
      deviceId: _deviceId,
      deviceName: 'Clipboard Device',
    );
    p2pClient = WebRtcP2PClient(
      localDeviceId: _deviceId,
      signalingClient: signalingClient,
      rtcConfig: _buildRtcConfig(),
    );
    _syncEngine = SyncEngine(
      localDeviceId: localDeviceId,
      clipboardService: clipboardService,
      historyStore: historyStore,
      pairingManager: pairingManager,
      offlineQueue: offlineQueue,
      p2pClient: p2pClient,
      signalingClient: signalingClient,
    );
    pairingManager.addListener(notifyListeners);
    historyStore.addListener(notifyListeners);
    _wireSignalingHandlers();
  }

  static final String _deviceId = 'device-${DateTime.now().millisecondsSinceEpoch}';
  static const String _signalingUrl =
      String.fromEnvironment('SIGNALING_URL', defaultValue: 'ws://localhost:8080');
  static const String _turnUrlsEnv = String.fromEnvironment('TURN_URLS');
  static const String _turnUsername = String.fromEnvironment('TURN_USERNAME');
  static const String _turnCredential = String.fromEnvironment('TURN_CREDENTIAL');
  final String localDeviceId = _deviceId;
  late final StorageService storageService;
  late final HistoryStore historyStore;
  late final PairingManager pairingManager;
  final ClipboardService clipboardService;
  late final OfflineQueue offlineQueue;
  late final P2PClient p2pClient;
  late final SignalingClient signalingClient;
  late final SyncEngine _syncEngine;
  final List<PairRequest> _pendingPairRequests = <PairRequest>[];

  bool _isSyncEnabled = true;

  bool get isSyncEnabled => _isSyncEnabled;
  List<PairRequest> get pendingPairRequests => List.unmodifiable(_pendingPairRequests);

  Future<void> initialize() async {
    await storageService.init();
    await historyStore.loadFromStorage();
    await pairingManager.loadFromStorage();
    await offlineQueue.loadFromStorage();
  }

  Future<void> start() async {
    if (_isSyncEnabled) {
      await _syncEngine.start();
    }
  }

  Future<void> stop() async {
    await _syncEngine.stop();
  }

  void toggleSync(bool enabled) {
    _isSyncEnabled = enabled;
    notifyListeners();
    if (enabled) {
      _syncEngine.start();
    } else {
      _syncEngine.stop();
    }
  }

  void addPairedDevice(String id, String name) {
    pairingManager.addDevice(PairedDevice(id: id, name: name));
  }

  void removePairedDevice(String id) {
    pairingManager.removeDevice(id);
  }

  void clearHistory() {
    historyStore.clear();
  }

  void clearAllStorage() async {
    historyStore.clear();
    for (final device in List<PairedDevice>.from(pairingManager.devices)) {
      pairingManager.removeDevice(device.id);
    }
    await storageService.clearAll();
    await offlineQueue.loadFromStorage();
    notifyListeners();
  }

  void approvePairRequest(PairRequest request) {
    _pendingPairRequests.removeWhere((r) => r.deviceId == request.deviceId);
    pairingManager.addDevice(PairedDevice(id: request.deviceId, name: request.deviceName));
    signalingClient.acceptPair(request.deviceId);
    if (p2pClient is WebRtcP2PClient) {
      (p2pClient as WebRtcP2PClient).connectToDevice(request.deviceId);
    }
    notifyListeners();
  }

  void rejectPairRequest(String deviceId) {
    _pendingPairRequests.removeWhere((r) => r.deviceId == deviceId);
    notifyListeners();
  }

  void _wireSignalingHandlers() {
    final rtcClient = p2pClient is WebRtcP2PClient ? p2pClient as WebRtcP2PClient : null;
    signalingClient.setOnPairRequest((fromDeviceId, fromDeviceName) {
      if (_pendingPairRequests.any((r) => r.deviceId == fromDeviceId)) {
        return;
      }
      _pendingPairRequests.add(PairRequest(deviceId: fromDeviceId, deviceName: fromDeviceName));
      notifyListeners();
    });
    signalingClient.setOnPairAccept((fromDeviceId) {
      if (pairingManager.devices.any((d) => d.id == fromDeviceId)) {
        return;
      }
      pairingManager.addDevice(PairedDevice(id: fromDeviceId, name: fromDeviceId));
      rtcClient?.connectToDevice(fromDeviceId);
    });
    signalingClient.setOnOffer((fromDeviceId, sdp) {
      rtcClient?.handleOffer(fromDeviceId, sdp);
    });
    signalingClient.setOnAnswer((fromDeviceId, sdp) {
      rtcClient?.handleAnswer(fromDeviceId, sdp);
    });
    signalingClient.setOnIce((fromDeviceId, candidate) {
      rtcClient?.handleIce(fromDeviceId, candidate);
    });
  }

  Map<String, dynamic> _buildRtcConfig() {
    final iceServers = <Map<String, dynamic>>[
      {'urls': 'stun:stun.l.google.com:19302'},
    ];
    if (_turnUrlsEnv.isNotEmpty) {
      final urls = _turnUrlsEnv.split(',').map((u) => u.trim()).where((u) => u.isNotEmpty).toList();
      if (urls.isNotEmpty) {
        iceServers.add({
          'urls': urls,
          'username': _turnUsername,
          'credential': _turnCredential,
        });
      }
    }
    return {'iceServers': iceServers};
  }

  @override
  void dispose() {
    pairingManager.removeListener(notifyListeners);
    historyStore.removeListener(notifyListeners);
    stop();
    super.dispose();
  }
}
