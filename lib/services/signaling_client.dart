typedef PresenceHandler = void Function(String deviceId, bool isOnline);

abstract class SignalingClient {
  void setOnPresence(PresenceHandler handler);
  Future<void> connect();
  Future<void> disconnect();
}

class StubSignalingClient implements SignalingClient {
  PresenceHandler? _handler;

  @override
  void setOnPresence(PresenceHandler handler) {
    _handler = handler;
  }

  @override
  Future<void> connect() async {
    // Placeholder for WebSocket signaling.
  }

  @override
  Future<void> disconnect() async {
    _handler = null;
  }
}
