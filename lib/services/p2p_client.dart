import '../models/clipboard_item.dart';

typedef ClipboardItemHandler = void Function(ClipboardItem item, String fromDeviceId);

abstract class P2PClient {
  void setOnIncoming(ClipboardItemHandler handler);
  Future<void> connectToDevice(String deviceId);
  Future<void> sendToDevice(String deviceId, ClipboardItem item);
  Future<void> broadcast(Iterable<String> deviceIds, ClipboardItem item);
  void dispose();
}

class StubP2PClient implements P2PClient {
  ClipboardItemHandler? _handler;

  @override
  void setOnIncoming(ClipboardItemHandler handler) {
    _handler = handler;
  }

  @override
  Future<void> connectToDevice(String deviceId) async {
    // Placeholder for WebRTC session initialization.
  }

  @override
  Future<void> sendToDevice(String deviceId, ClipboardItem item) async {
    // Placeholder for WebRTC DataChannel send.
  }

  @override
  Future<void> broadcast(Iterable<String> deviceIds, ClipboardItem item) async {
    for (final deviceId in deviceIds) {
      await sendToDevice(deviceId, item);
    }
  }

  @override
  void dispose() {
    _handler = null;
  }
}
