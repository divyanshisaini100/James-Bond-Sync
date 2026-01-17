import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/clipboard_item.dart';
import 'p2p_client.dart';
import 'signaling_client.dart';

class WebRtcP2PClient implements P2PClient {
  WebRtcP2PClient({
    required this.localDeviceId,
    required SignalingClient signalingClient,
    Map<String, dynamic>? rtcConfig,
  })  : _signalingClient = signalingClient,
        _rtcConfig = rtcConfig ??
            <String, dynamic>{
              'iceServers': [
                {'urls': 'stun:stun.l.google.com:19302'},
              ],
            };

  final String localDeviceId;
  final SignalingClient _signalingClient;
  final Map<String, _PeerSession> _sessions = <String, _PeerSession>{};
  ClipboardItemHandler? _incomingHandler;

  final Map<String, dynamic> _rtcConfig;

  @override
  void setOnIncoming(ClipboardItemHandler handler) {
    _incomingHandler = handler;
  }

  @override
  Future<void> connectToDevice(String deviceId) async {
    if (_sessions.containsKey(deviceId)) {
      return;
    }
    final session = await _createSession(deviceId, isCaller: true);
    _sessions[deviceId] = session;
    await session.createOffer();
  }

  @override
  Future<void> sendToDevice(String deviceId, ClipboardItem item) async {
    var session = _sessions[deviceId];
    if (session == null) {
      await connectToDevice(deviceId);
      session = _sessions[deviceId];
    }
    session?.sendItem(item);
  }

  @override
  Future<void> broadcast(Iterable<String> deviceIds, ClipboardItem item) async {
    for (final deviceId in deviceIds) {
      await sendToDevice(deviceId, item);
    }
  }

  void handleOffer(String fromDeviceId, String sdp) async {
    final session = _sessions.putIfAbsent(
      fromDeviceId,
      () => _PeerSession(
        deviceId: fromDeviceId,
        localDeviceId: localDeviceId,
        rtcConfig: _rtcConfig,
        signalingClient: _signalingClient,
        onIncoming: _incomingHandler,
      ),
    );
    await session.applyOffer(sdp);
  }

  void handleAnswer(String fromDeviceId, String sdp) async {
    final session = _sessions[fromDeviceId];
    if (session == null) {
      return;
    }
    await session.applyAnswer(sdp);
  }

  void handleIce(String fromDeviceId, Map<String, dynamic> candidate) async {
    final session = _sessions[fromDeviceId];
    if (session == null) {
      return;
    }
    await session.addIceCandidate(candidate);
  }

  @override
  void dispose() {
    for (final session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();
  }

  Future<_PeerSession> _createSession(String deviceId, {required bool isCaller}) async {
    final session = _PeerSession(
      deviceId: deviceId,
      localDeviceId: localDeviceId,
      rtcConfig: _rtcConfig,
      signalingClient: _signalingClient,
      onIncoming: _incomingHandler,
    );
    await session.initialize(isCaller: isCaller);
    return session;
  }
}

class _PeerSession {
  _PeerSession({
    required this.deviceId,
    required this.localDeviceId,
    required this.rtcConfig,
    required SignalingClient signalingClient,
    required ClipboardItemHandler? onIncoming,
  })  : _signalingClient = signalingClient,
        _onIncoming = onIncoming;

  final String deviceId;
  final String localDeviceId;
  final Map<String, dynamic> rtcConfig;
  final SignalingClient _signalingClient;
  final ClipboardItemHandler? _onIncoming;

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  final List<ClipboardItem> _pending = <ClipboardItem>[];

  Future<void> initialize({required bool isCaller}) async {
    _peerConnection = await createPeerConnection(rtcConfig);
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate == null) {
        return;
      }
      _signalingClient.sendIceCandidate(deviceId, candidate.toMap());
    };
    _peerConnection!.onDataChannel = (channel) {
      _dataChannel = channel;
      _wireDataChannel();
    };

    if (isCaller) {
      final channel = await _peerConnection!.createDataChannel(
        'clipboard',
        RTCDataChannelInit()..ordered = true,
      );
      _dataChannel = channel;
      _wireDataChannel();
    }
  }

  Future<void> createOffer() async {
    final pc = _peerConnection;
    if (pc == null) {
      return;
    }
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await _signalingClient.sendOffer(deviceId, offer.sdp ?? '');
  }

  Future<void> applyOffer(String sdp) async {
    final pc = _peerConnection ?? await createPeerConnection(rtcConfig);
    _peerConnection ??= pc;
    pc.onIceCandidate = (candidate) {
      if (candidate == null) {
        return;
      }
      _signalingClient.sendIceCandidate(deviceId, candidate.toMap());
    };
    pc.onDataChannel = (channel) {
      _dataChannel = channel;
      _wireDataChannel();
    };

    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    await _signalingClient.sendAnswer(deviceId, answer.sdp ?? '');
  }

  Future<void> applyAnswer(String sdp) async {
    final pc = _peerConnection;
    if (pc == null) {
      return;
    }
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }

  Future<void> addIceCandidate(Map<String, dynamic> candidate) async {
    final pc = _peerConnection;
    if (pc == null) {
      return;
    }
    final ice = RTCIceCandidate(
      candidate['candidate'] as String?,
      candidate['sdpMid'] as String?,
      candidate['sdpMLineIndex'] as int?,
    );
    await pc.addCandidate(ice);
  }

  void sendItem(ClipboardItem item) {
    if (_dataChannel == null || _dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      _pending.add(item);
      return;
    }
    _dataChannel!.send(RTCDataChannelMessage(jsonEncode(item.toJson())));
  }

  void _wireDataChannel() {
    final channel = _dataChannel;
    if (channel == null) {
      return;
    }
    channel.onMessage = (message) {
      if (message.isBinary) {
        return;
      }
      final Map<String, dynamic> payload = jsonDecode(message.text) as Map<String, dynamic>;
      final item = ClipboardItem.fromJson(payload);
      _onIncoming?.call(item, item.deviceId);
    };
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen && _pending.isNotEmpty) {
        final pending = List<ClipboardItem>.from(_pending);
        _pending.clear();
        for (final item in pending) {
          sendItem(item);
        }
      }
    };
  }

  void dispose() {
    _dataChannel?.close();
    _peerConnection?.close();
  }
}
