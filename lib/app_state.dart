import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'models/clipboard_item.dart';
import 'models/paired_device.dart';
import 'models/pair_request.dart';
import 'models/pending_pair_outgoing.dart';
import 'services/background_sync_service.dart';
import 'services/clipboard_service.dart';
import 'services/history_store.dart';
import 'services/offline_queue.dart';
import 'services/pairing_manager.dart';
import 'services/p2p_client.dart';
import 'services/identity_service.dart';
import 'services/storage_service.dart';
import 'services/webrtc_p2p_client.dart';
import 'services/signaling_client.dart';
import 'services/sync_engine.dart';

class AppState extends ChangeNotifier {
  AppState() : clipboardService = ClipboardService() {
    storageService = StorageService();
    identityService = IdentityService(storageService: storageService);
    historyStore = HistoryStore(storageService: storageService);
    pairingManager = PairingManager(storageService: storageService);
    offlineQueue = OfflineQueue(storageService: storageService);
    backgroundSyncService = BackgroundSyncService();
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
  late final IdentityService identityService;
  late final HistoryStore historyStore;
  late final PairingManager pairingManager;
  final ClipboardService clipboardService;
  late final BackgroundSyncService backgroundSyncService;
  late final OfflineQueue offlineQueue;
  late final P2PClient p2pClient;
  late final SignalingClient signalingClient;
  late final SyncEngine _syncEngine;
  final List<PairRequest> _pendingPairRequests = <PairRequest>[];
  final List<PendingPairOutgoing> _pendingOutgoing = <PendingPairOutgoing>[];

  bool _isSyncEnabled = true;
  bool _isBackgroundSyncEnabled = false;

  bool get isSyncEnabled => _isSyncEnabled;
  bool get isBackgroundSyncEnabled => _isBackgroundSyncEnabled;
  List<PairRequest> get pendingPairRequests => List.unmodifiable(_pendingPairRequests);
  int get maxBinaryBytes => SyncEngine.maxBinaryBytes;

  Future<void> initialize() async {
    await storageService.init();
    await identityService.init();
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

  Future<void> toggleBackgroundSync(bool enabled) async {
    _isBackgroundSyncEnabled = enabled;
    if (enabled) {
      await backgroundSyncService.enable();
    } else {
      await backgroundSyncService.disable();
    }
    notifyListeners();
  }

  Future<String> addPairedDevice(String id, String name) async {
    final code = _generatePairCode();
    final codeHash = await identityService.hashPairCode(code);
    _pendingOutgoing.add(
      PendingPairOutgoing(deviceId: id, deviceName: name, codeHash: codeHash),
    );
    await signalingClient.requestPair(id, identityService.publicKeyBase64, codeHash);
    return code;
  }

  bool sendBinaryItem({
    required Uint8List bytes,
    required String dataType,
    String? fileName,
    String? mimeType,
  }) {
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final id = '${localDeviceId}_$timestampMs_${_generatePairCode()}';
    final base64Payload = base64Encode(bytes);
    final item = ClipboardItem(
      id: id,
      deviceId: localDeviceId,
      timestampMs: timestampMs,
      dataType: dataType,
      text: '',
      hash: base64Payload.hashCode.toString(),
      payloadBase64: base64Payload,
      fileName: fileName,
      mimeType: mimeType,
      sizeBytes: bytes.length,
    );
    return _syncEngine.sendItem(item);
  }

  String _generatePairCode() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final code = (millis % 1000000).toString().padLeft(6, '0');
    return code;
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

  Future<bool> approvePairRequest(PairRequest request, String code) async {
    final codeHash = await identityService.hashPairCode(code);
    if (codeHash != request.codeHash) {
      return false;
    }
    _pendingPairRequests.removeWhere((r) => r.deviceId == request.deviceId);
    final sharedSecret =
        await identityService.deriveSharedSecretBase64(request.publicKey);
    pairingManager.addDevice(PairedDevice(
      id: request.deviceId,
      name: request.deviceName,
      publicKey: request.publicKey,
      sharedSecret: sharedSecret,
    ));
    await signalingClient.acceptPair(
      request.deviceId,
      identityService.publicKeyBase64,
      codeHash,
    );
    if (p2pClient is WebRtcP2PClient) {
      (p2pClient as WebRtcP2PClient).connectToDevice(request.deviceId);
    }
    notifyListeners();
    return true;
  }

  void rejectPairRequest(String deviceId) {
    _pendingPairRequests.removeWhere((r) => r.deviceId == deviceId);
    notifyListeners();
  }

  void _wireSignalingHandlers() {
    final rtcClient = p2pClient is WebRtcP2PClient ? p2pClient as WebRtcP2PClient : null;
    signalingClient.setOnPairRequest((fromDeviceId, fromDeviceName, publicKey, codeHash) {
      if (_pendingPairRequests.any((r) => r.deviceId == fromDeviceId)) {
        return;
      }
      _pendingPairRequests.add(PairRequest(
        deviceId: fromDeviceId,
        deviceName: fromDeviceName,
        publicKey: publicKey,
        codeHash: codeHash,
      ));
      notifyListeners();
    });
    signalingClient.setOnPairAccept((fromDeviceId, publicKey, codeHash) async {
      if (pairingManager.devices.any((d) => d.id == fromDeviceId)) {
        return;
      }
      final pending = _pendingOutgoing
          .where((p) => p.deviceId == fromDeviceId && p.codeHash == codeHash)
          .toList();
      if (pending.isEmpty) {
        return;
      }
      _pendingOutgoing.removeWhere((p) => p.deviceId == fromDeviceId);
      final sharedSecret = await identityService.deriveSharedSecretBase64(publicKey);
      pairingManager.addDevice(PairedDevice(
        id: fromDeviceId,
        name: pending.first.deviceName,
        publicKey: publicKey,
        sharedSecret: sharedSecret,
      ));
      rtcClient?.connectToDevice(fromDeviceId);
      notifyListeners();
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
