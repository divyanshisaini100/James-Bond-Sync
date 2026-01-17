# James-Bond-Sync
universal clipboard sync
Universal Clipboard sync is a cross-platform app that seamlessly syncs your clipboard content (text, images, files) across multiple devices using encrypted peer-to-peer connections. No cloud storage, no privacy concerns—your data travels directly between your devices.
🏗️ Architecture
┌─────────────────────────────────────────────────┐
│              UI Layer (Flutter)                 │
│  Dashboard | Pairing | History | Settings       │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│           Signaling Layer (WebSocket)           │
│  Online/Offline Status | WebRTC Handshake       │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│        Transport Layer (WebRTC DataChannel)     │
│  P2P Text/Image/File Transfer (Encrypted)       │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│           Storage Layer (SQLite)                │
│  Devices | History | Offline Queue | Settings   │
└─────────────────────────────────────────────────┘
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
