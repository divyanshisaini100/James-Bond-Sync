import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

typedef PresenceHandler = void Function(String deviceId, bool isOnline);
typedef PairRequestHandler = void Function(
  String fromDeviceId,
  String fromDeviceName,
  String publicKey,
  String codeHash,
);
typedef PairAcceptHandler = void Function(String fromDeviceId, String publicKey, String codeHash);
typedef RtcOfferHandler = void Function(String fromDeviceId, String sdp);
typedef RtcAnswerHandler = void Function(String fromDeviceId, String sdp);
typedef RtcIceHandler = void Function(String fromDeviceId, Map<String, dynamic> candidate);

abstract class SignalingClient {
  void setOnPresence(PresenceHandler handler);
  void setOnPairRequest(PairRequestHandler handler);
  void setOnPairAccept(PairAcceptHandler handler);
  void setOnOffer(RtcOfferHandler handler);
  void setOnAnswer(RtcAnswerHandler handler);
  void setOnIce(RtcIceHandler handler);

  Future<void> connect();
  Future<void> disconnect();

  Future<void> requestPair(String toDeviceId, String publicKey, String codeHash);
  Future<void> acceptPair(String toDeviceId, String publicKey, String codeHash);
  Future<void> sendOffer(String toDeviceId, String sdp);
  Future<void> sendAnswer(String toDeviceId, String sdp);
  Future<void> sendIceCandidate(String toDeviceId, Map<String, dynamic> candidate);
}

class WebSocketSignalingClient implements SignalingClient {
  WebSocketSignalingClient({
    required this.url,
    required this.deviceId,
    required this.deviceName,
  });

  final String url;
  final String deviceId;
  final String deviceName;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;

  PresenceHandler? _presenceHandler;
  PairRequestHandler? _pairRequestHandler;
  PairAcceptHandler? _pairAcceptHandler;
  RtcOfferHandler? _offerHandler;
  RtcAnswerHandler? _answerHandler;
  RtcIceHandler? _iceHandler;

  @override
  void setOnPresence(PresenceHandler handler) {
    _presenceHandler = handler;
  }

  @override
  void setOnPairRequest(PairRequestHandler handler) {
    _pairRequestHandler = handler;
  }

  @override
  void setOnPairAccept(PairAcceptHandler handler) {
    _pairAcceptHandler = handler;
  }

  @override
  void setOnOffer(RtcOfferHandler handler) {
    _offerHandler = handler;
  }

  @override
  void setOnAnswer(RtcAnswerHandler handler) {
    _answerHandler = handler;
  }

  @override
  void setOnIce(RtcIceHandler handler) {
    _iceHandler = handler;
  }

  @override
  Future<void> connect() async {
    if (_channel != null || _isConnecting) {
      return;
    }
    _shouldReconnect = true;
    _isConnecting = true;
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _subscription = _channel!.stream.listen(
      _handleMessage,
      onDone: _handleDisconnect,
      onError: (_) => _handleDisconnect(),
    );
    _sendMessage({
      'type': 'register',
      'deviceId': deviceId,
      'deviceName': deviceName,
    });
    _isConnecting = false;
    _reconnectAttempts = 0;
  }

  @override
  Future<void> disconnect() async {
    _shouldReconnect = false;
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  Future<void> requestPair(String toDeviceId, String publicKey, String codeHash) async {
    _sendMessage({
      'type': 'pair_request',
      'fromDeviceId': deviceId,
      'fromDeviceName': deviceName,
      'toDeviceId': toDeviceId,
      'publicKey': publicKey,
      'codeHash': codeHash,
    });
  }

  @override
  Future<void> acceptPair(String toDeviceId, String publicKey, String codeHash) async {
    _sendMessage({
      'type': 'pair_accept',
      'fromDeviceId': deviceId,
      'toDeviceId': toDeviceId,
      'publicKey': publicKey,
      'codeHash': codeHash,
    });
  }

  @override
  Future<void> sendOffer(String toDeviceId, String sdp) async {
    _sendMessage({
      'type': 'webrtc_offer',
      'fromDeviceId': deviceId,
      'toDeviceId': toDeviceId,
      'sdp': sdp,
    });
  }

  @override
  Future<void> sendAnswer(String toDeviceId, String sdp) async {
    _sendMessage({
      'type': 'webrtc_answer',
      'fromDeviceId': deviceId,
      'toDeviceId': toDeviceId,
      'sdp': sdp,
    });
  }

  @override
  Future<void> sendIceCandidate(String toDeviceId, Map<String, dynamic> candidate) async {
    _sendMessage({
      'type': 'webrtc_ice',
      'fromDeviceId': deviceId,
      'toDeviceId': toDeviceId,
      'candidate': candidate,
    });
  }

  void _handleMessage(dynamic raw) {
    if (raw is! String) {
      return;
    }
    final Map<String, dynamic> message = jsonDecode(raw) as Map<String, dynamic>;
    final type = message['type'] as String?;
    switch (type) {
      case 'presence':
        _presenceHandler?.call(message['deviceId'] as String, message['isOnline'] as bool);
        break;
      case 'pair_request':
        _pairRequestHandler?.call(
          message['fromDeviceId'] as String,
          message['fromDeviceName'] as String? ?? 'Unknown',
          message['publicKey'] as String,
          message['codeHash'] as String,
        );
        break;
      case 'pair_accept':
        _pairAcceptHandler?.call(
          message['fromDeviceId'] as String,
          message['publicKey'] as String,
          message['codeHash'] as String,
        );
        break;
      case 'webrtc_offer':
        _offerHandler?.call(message['fromDeviceId'] as String, message['sdp'] as String);
        break;
      case 'webrtc_answer':
        _answerHandler?.call(message['fromDeviceId'] as String, message['sdp'] as String);
        break;
      case 'webrtc_ice':
        final candidate =
            Map<String, dynamic>.from(message['candidate'] as Map<dynamic, dynamic>);
        _iceHandler?.call(message['fromDeviceId'] as String, candidate);
        break;
      default:
        break;
    }
  }

  void _sendMessage(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    channel.sink.add(jsonEncode(message));
  }

  void _handleDisconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (!_shouldReconnect) {
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectAttempts += 1;
    final delaySeconds = _reconnectAttempts.clamp(1, 6);
    Future.delayed(Duration(seconds: delaySeconds), () {
      if (_channel != null || _isConnecting) {
        return;
      }
      connect();
    });
  }
}

class StubSignalingClient implements SignalingClient {
  PresenceHandler? _presenceHandler;
  PairRequestHandler? _pairRequestHandler;
  PairAcceptHandler? _pairAcceptHandler;
  RtcOfferHandler? _offerHandler;
  RtcAnswerHandler? _answerHandler;
  RtcIceHandler? _iceHandler;

  @override
  void setOnPresence(PresenceHandler handler) {
    _presenceHandler = handler;
  }

  @override
  void setOnPairRequest(PairRequestHandler handler) {
    _pairRequestHandler = handler;
  }

  @override
  void setOnPairAccept(PairAcceptHandler handler) {
    _pairAcceptHandler = handler;
  }

  @override
  void setOnOffer(RtcOfferHandler handler) {
    _offerHandler = handler;
  }

  @override
  void setOnAnswer(RtcAnswerHandler handler) {
    _answerHandler = handler;
  }

  @override
  void setOnIce(RtcIceHandler handler) {
    _iceHandler = handler;
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> requestPair(String toDeviceId, String publicKey, String codeHash) async {}

  @override
  Future<void> acceptPair(String toDeviceId, String publicKey, String codeHash) async {}

  @override
  Future<void> sendOffer(String toDeviceId, String sdp) async {}

  @override
  Future<void> sendAnswer(String toDeviceId, String sdp) async {}

  @override
  Future<void> sendIceCandidate(String toDeviceId, Map<String, dynamic> candidate) async {}
}
