import 'dart:convert';
import 'dart:math';

import '../models/clipboard_item.dart';
import 'clipboard_service.dart';
import 'history_store.dart';
import 'offline_queue.dart';
import 'pairing_manager.dart';
import 'p2p_client.dart';
import 'signaling_client.dart';

class SyncEngine {
  SyncEngine({
    required this.localDeviceId,
    required ClipboardService clipboardService,
    required HistoryStore historyStore,
    required PairingManager pairingManager,
    required OfflineQueue offlineQueue,
    required P2PClient p2pClient,
    required SignalingClient signalingClient,
  })  : _clipboardService = clipboardService,
        _historyStore = historyStore,
        _pairingManager = pairingManager,
        _offlineQueue = offlineQueue,
        _p2pClient = p2pClient,
        _signalingClient = signalingClient;

  final String localDeviceId;
  final ClipboardService _clipboardService;
  final HistoryStore _historyStore;
  final PairingManager _pairingManager;
  final OfflineQueue _offlineQueue;
  final P2PClient _p2pClient;
  final SignalingClient _signalingClient;

  int _lastAppliedTimestamp = 0;

  Future<void> start() async {
    _clipboardService.startMonitoring(_handleLocalClipboardChange);
    _p2pClient.setOnIncoming(_handleIncomingClipboardItem);
    _signalingClient.setOnPresence(_handlePresence);
    await _signalingClient.connect();
  }

  Future<void> stop() async {
    _clipboardService.dispose();
    _p2pClient.dispose();
    await _signalingClient.disconnect();
  }

  void _handlePresence(String deviceId, bool isOnline) {
    _pairingManager.updatePresence(deviceId, isOnline);
    if (isOnline) {
      final queued = _offlineQueue.drainForDevice(deviceId);
      for (final item in queued) {
        _p2pClient.sendToDevice(deviceId, item);
      }
    }
  }

  void _handleLocalClipboardChange(String text) {
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final id = '${localDeviceId}_$timestampMs_${_randSuffix()}';
    final item = ClipboardItem(
      id: id,
      deviceId: localDeviceId,
      timestampMs: timestampMs,
      dataType: 'text',
      text: text,
      hash: _hashText(text),
    );
    _applyAndBroadcast(item);
  }

  void _handleIncomingClipboardItem(ClipboardItem item, String fromDeviceId) {
    if (_historyStore.containsId(item.id)) {
      return;
    }
    if (item.timestampMs < _lastAppliedTimestamp) {
      return;
    }
    _applyRemoteItem(item);
  }

  void _applyAndBroadcast(ClipboardItem item) {
    _applyLocalItem(item);
    final deviceIds = _pairingManager.devices.map((d) => d.id);
    for (final device in _pairingManager.devices) {
      if (device.isOnline) {
        _p2pClient.sendToDevice(device.id, item);
      } else {
        _offlineQueue.enqueue(device.id, item);
      }
    }
  }

  void _applyLocalItem(ClipboardItem item) {
    _lastAppliedTimestamp = max(_lastAppliedTimestamp, item.timestampMs);
    _historyStore.add(item);
  }

  void _applyRemoteItem(ClipboardItem item) {
    _lastAppliedTimestamp = max(_lastAppliedTimestamp, item.timestampMs);
    _historyStore.add(item);
    _clipboardService.setClipboardText(item.text, suppressNextRead: true);
  }

  String _hashText(String text) {
    final bytes = utf8.encode(text);
    var hash = 0;
    for (final b in bytes) {
      hash = (hash * 31 + b) & 0x7fffffff;
    }
    return hash.toString();
  }

  String _randSuffix() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    return List<String>.generate(4, (_) => alphabet[rand.nextInt(alphabet.length)]).join();
  }
}
