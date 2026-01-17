import '../models/clipboard_item.dart';
import 'storage_service.dart';

class OfflineQueue {
  OfflineQueue({required StorageService storageService}) : _storageService = storageService;

  final StorageService _storageService;
  final Map<String, List<ClipboardItem>> _queuedByDevice = <String, List<ClipboardItem>>{};

  Future<void> loadFromStorage() async {
    final data = await _storageService.loadOfflineQueue();
    _queuedByDevice
      ..clear()
      ..addAll(data);
  }

  void enqueue(String deviceId, ClipboardItem item) {
    final queue = _queuedByDevice.putIfAbsent(deviceId, () => <ClipboardItem>[]);
    queue.add(item);
    _storageService.persistQueue(deviceId, queue);
  }

  List<ClipboardItem> drainForDevice(String deviceId) {
    final queue = _queuedByDevice.remove(deviceId);
    _storageService.removeQueue(deviceId);
    return queue ?? <ClipboardItem>[];
  }
}
