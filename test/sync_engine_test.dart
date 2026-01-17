import 'package:flutter_test/flutter_test.dart';

import 'package:clipboard/models/clipboard_item.dart';
import 'package:clipboard/models/paired_device.dart';
import 'package:clipboard/services/clipboard_service.dart';
import 'package:clipboard/services/history_store.dart';
import 'package:clipboard/services/offline_queue.dart';
import 'package:clipboard/services/pairing_manager.dart';
import 'package:clipboard/services/p2p_client.dart';
import 'package:clipboard/services/signaling_client.dart';
import 'package:clipboard/services/storage_service.dart';
import 'package:clipboard/services/sync_engine.dart';

class _FakeStorageService extends StorageService {
  final Map<String, ClipboardItem> _history = {};
  final Map<String, Map<String, dynamic>> _devices = {};
  final Map<String, List<ClipboardItem>> _queue = {};

  @override
  Future<void> init() async {}

  @override
  Future<List<ClipboardItem>> loadHistory() async => _history.values.toList();

  @override
  Future<void> persistHistoryItem(ClipboardItem item) async {
    _history[item.id] = item;
  }

  @override
  Future<void> clearHistory() async {
    _history.clear();
  }

  @override
  Future<List<PairedDevice>> loadPairedDevices() async => [];

  @override
  Future<void> persistPairedDevice(PairedDevice device) async {
    _devices[device.id] = {'id': device.id, 'name': device.name};
  }

  @override
  Future<void> removePairedDevice(String deviceId) async {
    _devices.remove(deviceId);
  }

  @override
  Future<Map<String, List<ClipboardItem>>> loadOfflineQueue() async => _queue;

  @override
  Future<void> persistQueue(String deviceId, List<ClipboardItem> items) async {
    _queue[deviceId] = items;
  }

  @override
  Future<void> removeQueue(String deviceId) async {
    _queue.remove(deviceId);
  }
}

class _TestClipboardService extends ClipboardService {
  @override
  void startMonitoring({
    required ClipboardTextHandler onText,
    required ClipboardBinaryHandler onBinary,
  }) {}

  @override
  Future<void> setClipboardText(String text, {bool suppressNextRead = false}) async {}
}

class _FakeP2PClient implements P2PClient {
  @override
  void setOnIncoming(ClipboardItemHandler handler) {}

  @override
  Future<void> connectToDevice(String deviceId) async {}

  @override
  Future<void> sendToDevice(String deviceId, ClipboardItem item) async {}

  @override
  Future<void> broadcast(Iterable<String> deviceIds, ClipboardItem item) async {}

  @override
  void dispose() {}
}

void main() {
  test('SyncEngine rejects oversize text payloads', () {
    final storage = _FakeStorageService();
    final history = HistoryStore(storageService: storage);
    final pairing = PairingManager(storageService: storage);
    final queue = OfflineQueue(storageService: storage);
    final engine = SyncEngine(
      localDeviceId: 'device',
      clipboardService: _TestClipboardService(),
      historyStore: history,
      pairingManager: pairing,
      offlineQueue: queue,
      p2pClient: _FakeP2PClient(),
      signalingClient: StubSignalingClient(),
    );

    final text = 'x' * (SyncEngine.maxTextBytes + 1);
    final item = ClipboardItem(
      id: 'id',
      deviceId: 'device',
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      dataType: 'text',
      text: text,
      hash: 'hash',
      sizeBytes: text.length,
    );

    final sent = engine.sendItem(item);
    expect(sent, isFalse);
  });
}
