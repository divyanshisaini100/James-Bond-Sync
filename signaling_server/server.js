const WebSocket = require('ws');

const PORT = process.env.PORT ? Number(process.env.PORT) : 8080;
const wss = new WebSocket.Server({ port: PORT });
const clients = new Map(); // deviceId -> { ws, deviceName }

function send(ws, message) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(message));
  }
}

function broadcastPresence(deviceId, isOnline) {
  const payload = { type: 'presence', deviceId, isOnline };
  for (const { ws } of clients.values()) {
    send(ws, payload);
  }
}

function sendExistingPresence(ws, currentDeviceId) {
  for (const [deviceId] of clients.entries()) {
    if (deviceId === currentDeviceId) {
      continue;
    }
    send(ws, { type: 'presence', deviceId, isOnline: true });
  }
}

function forwardToDevice(toDeviceId, payload) {
  const target = clients.get(toDeviceId);
  if (!target) {
    return;
  }
  send(target.ws, payload);
}

wss.on('connection', (ws) => {
  let registeredDeviceId = null;

  ws.on('message', (raw) => {
    let message;
    try {
      message = JSON.parse(raw.toString());
    } catch (error) {
      return;
    }

    const type = message.type;
    if (type === 'register') {
      const { deviceId, deviceName } = message;
      if (!deviceId) {
        return;
      }
      registeredDeviceId = deviceId;
      clients.set(deviceId, { ws, deviceName: deviceName || 'Unknown' });
      sendExistingPresence(ws, deviceId);
      broadcastPresence(deviceId, true);
      return;
    }

    const toDeviceId = message.toDeviceId;
    if (!toDeviceId) {
      return;
    }

    switch (type) {
      case 'pair_request':
      case 'pair_accept':
      case 'webrtc_offer':
      case 'webrtc_answer':
      case 'webrtc_ice':
        forwardToDevice(toDeviceId, message);
        break;
      default:
        break;
    }
  });

  ws.on('close', () => {
    if (!registeredDeviceId) {
      return;
    }
    clients.delete(registeredDeviceId);
    broadcastPresence(registeredDeviceId, false);
  });
});

console.log(`Signaling server listening on ws://localhost:${PORT}`);
