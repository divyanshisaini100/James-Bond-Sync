# Signaling Server

WebSocket-based signaling server used for device discovery, presence, pairing,
and WebRTC offer/answer/ICE exchange. Clipboard data is never routed through
this service.

## Run locally

```bash
npm install
npm start
```

By default it listens on `ws://localhost:8080`. Set `PORT` to change it.
