# James-Bond-Sync
Universal clipboard sync across devices via encrypted P2P connections. No cloud
storage; clipboard data travels directly between paired devices.
✨ Features
Core Functionality

🔄 Real-time P2P Sync - Instant clipboard synchronization via WebRTC DataChannels
📱 Multi-Device Support - Connect unlimited devices with QR code pairing
🟢 Live Presence - See which devices are online/offline in real-time
📜 Clipboard History - Browse and restore previously synced items
📦 Offline Queue - Automatically syncs when offline devices reconnect
🖼️ Multi-Format Support - Text, images, and files up to 500MB
Privacy & Security

🔒 Zero Server Storage - All clipboard data stays on your devices
🔐 End-to-End Encryption - WebRTC DTLS-SRTP encryption
🚫 No Tracking - No analytics, no data collection
🏠 Self-Hosted Option - Run your own signaling server

## Production Signaling & TURN

This app uses a WebSocket signaling server for discovery + WebRTC signaling.
Clipboard payloads are never routed through the server.

### 1) Deploy the signaling server

```
cd signaling_server
npm install
PORT=8080 node server.js
```

Expose it behind a domain like `wss://signal.example.com`.

### 2) Run a TURN server (Coturn)

Install and run Coturn (example):

```
turnserver -a -o \
  -u user:pass \
  --realm example.com \
  --listening-port 3478 \
  --min-port 49152 --max-port 65535
```

### 3) Configure the app

Pass the signaling URL and TURN credentials:

```
flutter run \
  --dart-define=SIGNALING_URL=wss://signal.example.com \
  --dart-define=TURN_URLS=turn:turn.example.com:3478 \
  --dart-define=TURN_USERNAME=user \
  --dart-define=TURN_CREDENTIAL=pass
```

Notes:
- Use `wss://` in production.
- Make sure UDP 3478 + UDP 49152-65535 are open for TURN relay.
