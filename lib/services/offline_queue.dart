import '../models/clipboard_item.dart';

class OfflineQueue {
  final Map<String, List<ClipboardItem>> _queuedByDevice = <String, List<ClipboardItem>>{};

  void enqueue(String deviceId, ClipboardItem item) {
    final queue = _queuedByDevice.putIfAbsent(deviceId, () => <ClipboardItem>[]);
    queue.add(item);
  }

  List<ClipboardItem> drainForDevice(String deviceId) {
    final queue = _queuedByDevice.remove(deviceId);
    return queue ?? <ClipboardItem>[];
  }
}
