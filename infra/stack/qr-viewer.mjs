// Mostra no navegador o QR atual do terminal-dev-01 (substitui o display do ESP32 no teste).
import http from 'node:http';
import fs from 'node:fs';
import mqtt from 'mqtt';
import QRCode from 'qrcode';

let latest = { png: null, expiresAt: null, receivedAt: null };

const client = mqtt.connect(`mqtts://${process.env.MQTT_HOST}:8883`, {
  username: 'terminal-dev-01',
  password: process.env.TERMINAL_PASSWORD,
  ca: fs.readFileSync('/ca.crt'),
  clientId: `qr-viewer-${Math.random().toString(16).slice(2, 8)}`,
});
client.on('connect', () => {
  console.log('[qr-viewer] conectado; assinando terminals/terminal-dev-01/qr');
  client.subscribe('terminals/terminal-dev-01/qr', { qos: 1 });
});
client.on('error', (e) => console.error('[qr-viewer] erro mqtt:', e.message));
client.on('message', async (_topic, payload) => {
  try {
    const msg = JSON.parse(payload.toString());
    latest = {
      png: await QRCode.toDataURL(msg.token, { width: 480, margin: 2 }),
      expiresAt: msg.expiresAt,
      receivedAt: new Date().toISOString(),
    };
    console.log(`[qr-viewer] qr novo, expira em ${msg.expiresAt}`);
  } catch (e) {
    console.error('[qr-viewer] payload invalido:', e.message);
  }
});

http
  .createServer((req, res) => {
    if (req.url === '/qr.png' && latest.png) {
      res.writeHead(200, { 'Content-Type': 'image/png', 'Cache-Control': 'no-store' });
      return res.end(Buffer.from(latest.png.split(',')[1], 'base64'));
    }
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
    res.end(`<!doctype html><meta name=viewport content="width=device-width"><meta http-equiv=refresh content=2>
<title>QR terminal-dev-01</title><body style="font-family:sans-serif;text-align:center;background:#fff">
<h2>terminal-dev-01</h2>${latest.png ? `<img src="${latest.png}" style="width:min(90vw,480px)">
<p>expira em ${latest.expiresAt}<br>recebido em ${latest.receivedAt}</p>` : '<p>aguardando o primeiro QR...</p>'}
<p style="color:#888">atualiza a cada 2 s; o QR vale 25 s e troca a cada 20 s</p></body>`);
  })
  .listen(8081, () => console.log('[qr-viewer] http://localhost:8081'));
