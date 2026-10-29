import { once } from 'node:events';
import { createServer, type Server, type Socket } from 'node:net';
import { Aedes, type AedesOptions } from 'aedes';
import { afterEach, describe, expect, it } from 'vitest';
import type { CommandMessage } from '../../src/domain/terminal/messages.js';
import { MqttMessageBus } from '../../src/infrastructure/mqtt/mqtt-message-bus.js';
import { NOW, TERMINAL, UUID_A, UUID_CMD, silentLogger } from '../support/terminal-fakes.js';

const command: CommandMessage = {
  v: 1,
  messageId: UUID_A,
  terminalId: TERMINAL,
  timestamp: NOW.toISOString(),
  commandId: UUID_CMD,
  expiresAt: new Date(NOW.getTime() + 10_000).toISOString(),
  action: 'open',
};

interface Running {
  broker: Aedes;
  tcp: Server;
  sockets: Set<Socket>;
  url: string;
}

const cleanups: (() => Promise<void>)[] = [];

async function startBroker(options: AedesOptions = {}): Promise<Running> {
  const broker = await Aedes.createBroker(options);
  const sockets = new Set<Socket>();
  const tcp = createServer((socket) => {
    sockets.add(socket);
    socket.on('close', () => sockets.delete(socket));
    broker.handle(socket);
  });
  tcp.listen(0, '127.0.0.1');
  await once(tcp, 'listening');
  const { port } = tcp.address() as { port: number };
  const running = { broker, tcp, sockets, url: `mqtt://127.0.0.1:${port}` };
  cleanups.push(() => stopBroker(running));
  return running;
}

async function stopBroker({ broker, tcp, sockets }: Running): Promise<void> {
  for (const socket of sockets) socket.destroy();
  if (tcp.listening) await new Promise<void>((resolve) => tcp.close(() => resolve()));
  if (!broker.closed) await new Promise<void>((resolve) => broker.close(() => resolve()));
}

async function connect(url: string, publishTimeoutMs?: number) {
  let closed = false;
  const bus = await MqttMessageBus.connect(
    { url, clientId: `dt13-${Math.random().toString(16).slice(2)}`, publishTimeoutMs },
    { ...silentLogger, warn: (msg) => { if (msg === 'mqtt conexao fechada') closed = true; } },
  );
  cleanups.push(() => Promise.race([bus.close(), new Promise<void>((resolve) => setTimeout(resolve, 500))]));
  return { bus, isClosed: () => closed };
}

afterEach(async () => {
  while (cleanups.length > 0) await cleanups.pop()?.();
});

describe('DT-13: MqttMessageBus nao pendura a publicacao', () => {
  it('publica e resolve com o broker confirmando', async () => {
    const running = await startBroker();
    const { bus } = await connect(running.url);

    await expect(bus.publish('commands', command)).resolves.toBeUndefined();
  });

  it('falha na hora quando o broker caiu depois de conectar', async () => {
    const running = await startBroker();
    const { bus, isClosed } = await connect(running.url);
    await stopBroker(running);
    while (!isClosed()) await new Promise((resolve) => setTimeout(resolve, 10));

    const started = Date.now();
    await expect(bus.publish('commands', command)).rejects.toThrow('mqtt desconectado');
    expect(Date.now() - started).toBeLessThan(100);
  });

  it('desiste no prazo quando o broker nao confirma a entrega', async () => {
    // Sem chamar o callback, o broker nunca envia o PUBACK.
    const running = await startBroker({ authorizePublish: () => {} });
    const { bus } = await connect(running.url, 150);

    const started = Date.now();
    await expect(bus.publish('commands', command)).rejects.toThrow('sem confirmacao no prazo');
    expect(Date.now() - started).toBeGreaterThanOrEqual(140);
  });
});
