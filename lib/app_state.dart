import 'package:flutter/foundation.dart';

import 'models/paired_device.dart';
import 'services/clipboard_service.dart';
import 'services/history_store.dart';
import 'services/offline_queue.dart';
import 'services/pairing_manager.dart';
import 'services/p2p_client.dart';
import 'services/signaling_client.dart';
import 'services/sync_engine.dart';

class AppState extends ChangeNotifier {
  AppState()
      : historyStore = HistoryStore(),
        pairingManager = PairingManager(),
        clipboardService = ClipboardService(),
        offlineQueue = OfflineQueue(),
        p2pClient = StubP2PClient(),
        signalingClient = StubSignalingClient() {
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
  }

  final String localDeviceId = 'device-${DateTime.now().millisecondsSinceEpoch}';
  final HistoryStore historyStore;
  final PairingManager pairingManager;
  final ClipboardService clipboardService;
  final OfflineQueue offlineQueue;
  final P2PClient p2pClient;
  final SignalingClient signalingClient;
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

  @override
  void dispose() {
    pairingManager.removeListener(notifyListeners);
    historyStore.removeListener(notifyListeners);
    stop();
    super.dispose();
  }
}
