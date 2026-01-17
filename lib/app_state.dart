import 'package:flutter/foundation.dart';

import 'models/paired_device.dart';
import 'services/clipboard_service.dart';
import 'services/history_store.dart';
import 'services/offline_queue.dart';
import 'services/pairing_manager.dart';
import 'services/p2p_client.dart';
import 'services/webrtc_p2p_client.dart';
import 'services/signaling_client.dart';
import 'services/sync_engine.dart';

class AppState extends ChangeNotifier {
  AppState()
      : historyStore = HistoryStore(),
        pairingManager = PairingManager(),
        clipboardService = ClipboardService(),
        offlineQueue = OfflineQueue() {
    signalingClient = WebSocketSignalingClient(
      url: 'ws://localhost:8080',
      deviceId: _deviceId,
      deviceName: 'Clipboard Device',
    );
    p2pClient = WebRtcP2PClient(
      localDeviceId: _deviceId,
      signalingClient: signalingClient,
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
  final String localDeviceId = _deviceId;
  final HistoryStore historyStore;
  final PairingManager pairingManager;
  final ClipboardService clipboardService;
  final OfflineQueue offlineQueue;
  late final P2PClient p2pClient;
  late final SignalingClient signalingClient;
  late final SyncEngine _syncEngine;

  bool _isSyncEnabled = true;

  bool get isSyncEnabled => _isSyncEnabled;

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

  void _wireSignalingHandlers() {
    final rtcClient = p2pClient is WebRtcP2PClient ? p2pClient as WebRtcP2PClient : null;
    signalingClient.setOnPairRequest((fromDeviceId, fromDeviceName) {
      // TODO: Replace with user-approved pairing dialog.
      pairingManager.addDevice(PairedDevice(id: fromDeviceId, name: fromDeviceName));
      signalingClient.acceptPair(fromDeviceId);
      rtcClient?.connectToDevice(fromDeviceId);
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

  @override
  void dispose() {
    pairingManager.removeListener(notifyListeners);
    historyStore.removeListener(notifyListeners);
    stop();
    super.dispose();
  }
}
