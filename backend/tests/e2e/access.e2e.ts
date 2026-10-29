import { createHmac, randomUUID } from 'node:crypto';
import { execFileSync, spawn, type ChildProcess } from 'node:child_process';
import { once } from 'node:events';
import { mkdtemp, rm } from 'node:fs/promises';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { Aedes } from 'aedes';
import EmbeddedPostgres from 'embedded-postgres';
import { connectAsync, type MqttClient } from 'mqtt';
import pg from 'pg';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { CryptoIdGenerator } from '../../src/infrastructure/ids/crypto-id-generator.js';
import { SystemClock } from '../../src/infrastructure/clock/system-clock.js';
import { PostgresEventDeduplicator } from '../../src/infrastructure/database/postgres-event-deduplicator.js';
import type { AccessEventMessage, AckMessage, CommandMessage } from '../../src/domain/terminal/messages.js';
import { ACCESS_EVENT_MAX_AGE_MS } from '../../src/domain/terminal/event-freshness.js';
import {
  AccessEventPage,
  AccessResult,
} from '../../src/main/http/contract/schemas/access-events.schemas.js';
import { SimulatedTerminal } from '../../src/main/sim/simulated-terminal.js';
import { withPeakSampling } from '../support/peak-sampler.js';
import { silentLogger } from '../support/terminal-fakes.js';

const QR_SECRET = 'a'.repeat(64);
const JWT_SECRET = 'e2e-jwt-secret-com-32-caracteres-ok';
const DEMO_LOCATION = { latitude: -23.2237, longitude: -45.9009 };
const MEMBER_EMAIL = 'usuario@abp4.local';
const MEMBER_PASSWORD = 'DemoUser123!';
const ADMIN_EMAIL = 'admin@abp4.local';
const ADMIN_PASSWORD = 'DemoAdmin123!';
const TERMINAL = 'terminal-01';
const NFC_UID = '04A1B2C3';

let database: EmbeddedPostgres;
let pool: pg.Pool;
let broker: Aedes;
let tcp: ReturnType<typeof createServer>;
let observer: MqttClient;
let tempDirectory: string;
let baseUrl: string;
let databaseUrl: string;
let mqttUrl: string;
let runtimeEnv: NodeJS.ProcessEnv;
let worker: ChildProcess;
let workerOutput: () => string;
const children: ChildProcess[] = [];
const qrMessages: { token: string; expiresAt: string }[] = [];
const terminals = new Map<string, SimulatedTerminal>();
const receivedCommands: CommandMessage[] = [];
const receivedAcks: AckMessage[] = [];
const terminalExecutions: string[] = [];
const terminalDuplicates: string[] = [];
let memberToken: string;
let adminToken: string;
let autoAck = true;

async function waitFor<T>(
  read: () => Promise<T> | T,
  accept: (value: T) => boolean,
  timeout = 20_000,
): Promise<T> {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const result = await read();
    if (accept(result)) return result;
    await delay(50);
  }
  throw new Error('Timeout aguardando condicao E2E');
}

async function freePort(): Promise<number> {
  const server = createServer();
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const port = (server.address() as { port: number }).port;
  await new Promise<void>((resolve) => server.close(() => resolve()));
  return port;
}

function launch(entry: string, overrides: NodeJS.ProcessEnv = {}) {
  const child = spawn(process.execPath, [`dist/main/${entry}.js`], {
    env: { ...runtimeEnv, ...overrides },
    windowsHide: true,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  children.push(child);
  let output = '';
  child.stdout?.on('data', (chunk: Buffer) => {
    output += chunk.toString();
  });
  child.stderr?.on('data', (chunk: Buffer) => {
    output += chunk.toString();
  });
  return { child, output: () => output };
}

async function api(path: string, token: string | undefined, body?: unknown) {
  return fetch(`${baseUrl}/api/v1${path}`, {
    method: body === undefined ? 'GET' : 'POST',
    headers: {
      ...(token === undefined ? {} : { authorization: `Bearer ${token}` }),
      'content-type': 'application/json',
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}

async function login(email: string, password: string): Promise<string> {
  const response = await api('/auth/login', undefined, { email, password });
  expect(response.status, await response.clone().text()).toBe(200);
  const body = (await response.json()) as { accessToken: string };
  return body.accessToken;
}

async function freshQr(): Promise<{ token: string; expiresAt: string }> {
  // O worker publica o QR assinado no ciclo de 10 s para terminais online.
  await observer.publishAsync(
    `terminals/${TERMINAL}/status`,
    JSON.stringify({
      v: 1,
      messageId: randomUUID(),
      terminalId: TERMINAL,
      timestamp: new Date().toISOString(),
      state: 'online',
    }),
    { qos: 1 },
  );
  const message = await waitFor(
    () => qrMessages.at(-1),
    (candidate) => candidate !== undefined && Date.parse(candidate.expiresAt) > Date.now() + 3_000,
    25_000,
  );
  if (!message) throw new Error('QR nao publicado pelo worker');
  return message;
}

function expiredQrToken(): string {
  const issuedAt = Math.floor(Date.now() / 1000) - 600;
  const expiresAt = issuedAt + 10;
  const payload = `v1.${TERMINAL}.${issuedAt}.${expiresAt}`;
  return `${payload}.${createHmac('sha256', QR_SECRET).update(payload).digest('base64url')}`;
}

async function startWorker() {
  const consumer = launch('mqtt-consumer', { TZ: 'UTC' });
  worker = consumer.child;
  workerOutput = consumer.output;
  await waitFor(
    () => {
      if (worker.exitCode !== null) throw new Error(consumer.output());
      return consumer.output();
    },
    (output) => output.includes('mqtt assinando'),
  );
}

async function stopChild(child: ChildProcess) {
  if (child.exitCode !== null || child.signalCode !== null) return;
  const exited = once(child, 'exit');
  child.kill('SIGKILL');
  await exited;
}

interface WorkerTrace {
  type: string;
  messageId?: string;
  command?: CommandMessage;
  error?: string;
}

async function startFaultWorker(terminalId: string, fault = 'none', gated = false) {
  const child = spawn(process.execPath, ['tests/e2e/fixtures/dt05-worker.mjs'], {
    env: { ...runtimeEnv, DT05_TERMINAL: terminalId, DT05_FAULT: fault, DT05_GATE: gated ? '1' : '0' },
    windowsHide: true,
    stdio: ['ignore', 'pipe', 'pipe', 'ipc'],
  });
  children.push(child);
  const traces: WorkerTrace[] = [];
  let output = '';
  child.on('message', (message: WorkerTrace) => { traces.push(message); });
  child.stdout?.on('data', (chunk: Buffer) => { output += chunk.toString(); });
  child.stderr?.on('data', (chunk: Buffer) => { output += chunk.toString(); });
  const waitTrace = (type: string, messageId?: string) => waitFor(() => {
    if (child.exitCode !== null || child.signalCode !== null) throw new Error(output);
    return traces.find((trace) => trace.type === type && (!messageId || trace.messageId === messageId));
  }, (trace) => trace !== undefined);
  await waitTrace('ready');
  return { child, traces, waitTrace };
}

async function completedMessage(id: string) {
  return waitFor(
    async () => (await pool.query('SELECT 1 FROM "ProcessedAccessMessage" WHERE "messageId"=$1', [id])).rowCount,
    (count) => count === 1,
  );
}

async function isolatedNfcAttempt() {
  const locationId = randomUUID();
  const authorizationId = randomUUID();
  const terminalId = `dt05-${randomUUID()}`;
  await pool.query(`INSERT INTO "AccessLocation" (id,name,latitude,longitude,"updatedAt")
    VALUES ($1,'DT05',0,0,now())`, [locationId]);
  await pool.query('INSERT INTO "Terminal" (id,"locationId","updatedAt") VALUES ($1,$2,now())', [terminalId, locationId]);
  await pool.query(`INSERT INTO "Authorization"
    (id,"userId","locationId","startsAt","endsAt","maxUses","updatedAt")
    VALUES ($1,$2,$3,now()-interval '1 hour',now()+interval '1 hour',5,now())`,
  [authorizationId, 'a1000000-0000-4000-8000-000000000002', locationId]);
  const event: AccessEventMessage = {
    v: 1, messageId: randomUUID(), terminalId, timestamp: new Date().toISOString(), type: 'nfc_read', uid: NFC_UID,
  };
  return { event, authorizationId };
}

async function publishAttempt(event: AccessEventMessage) {
  expect(Date.now() - Date.parse(event.timestamp)).toBeLessThan(ACCESS_EVENT_MAX_AGE_MS);
  await observer.publishAsync(`terminals/${event.terminalId}/access-events`, JSON.stringify(event), { qos: 1 });
}

async function expectSingleConsumption(event: AccessEventMessage, authorizationId: string) {
  const events = await pool.query('SELECT decision,"authorizationId" FROM "AccessEvent" WHERE id=$1', [event.messageId]);
  expect(events.rows).toEqual([{ decision: 'GRANTED', authorizationId }]);
  const uses = await pool.query<{ usedCount: number }>('SELECT "usedCount" FROM "Authorization" WHERE id=$1', [authorizationId]);
  expect(uses.rows[0]?.usedCount).toBe(1);
  const commands = await pool.query('SELECT 1 FROM "TerminalCommand" WHERE "requestId"=$1', [event.messageId]);
  expect(commands.rowCount).toBe(1);
}

async function commandRow(requestId: string) {
  return (
    await pool.query<{ payload: CommandMessage; ackStatus: string | null }>(
      'SELECT payload,"ackStatus" FROM "TerminalCommand" WHERE "requestId"=$1',
      [requestId],
    )
  ).rows[0];
}

async function waitCommandAck(requestId: string, timeout = 20_000) {
  return waitFor(() => commandRow(requestId), (row) => row?.ackStatus !== null && row !== undefined, timeout);
}

beforeAll(async () => {
  tempDirectory = await mkdtemp(join(tmpdir(), 'abp4-dt-e2e-'));
  const postgresPort = await freePort();
  database = new EmbeddedPostgres({
    databaseDir: join(tempDirectory, 'postgres'),
    port: postgresPort,
    user: 'abp4',
    password: 'local-e2e',
    persistent: true,
    onLog: () => {},
    onError: () => {},
    postgresFlags: ['-h', '127.0.0.1'],
  });
  await database.initialise();
  await database.start();
  await database.createDatabase('access_e2e');
  await database.createDatabase('unmigrated');

  databaseUrl = `postgresql://abp4:local-e2e@127.0.0.1:${postgresPort}/access_e2e`;
  broker = await Aedes.createBroker();
  const tcpPort = await freePort();
  tcp = createServer(broker.handle);
  tcp.listen(tcpPort, '127.0.0.1');
  await once(tcp, 'listening');
  mqttUrl = `mqtt://127.0.0.1:${tcpPort}`;

  const prismaEnv: NodeJS.ProcessEnv = {
    ...process.env,
    DATABASE_URL: databaseUrl,
    QR_TOKEN_SECRET: QR_SECRET,
    JWT_SECRET,
    LOG_LEVEL: 'silent',
  };
  const prisma = (...args: string[]) =>
    execFileSync(process.execPath, ['node_modules/prisma/build/index.js', ...args], {
      env: prismaEnv,
      timeout: 120_000,
      windowsHide: true,
      stdio: 'pipe',
    });

  prisma('migrate', 'deploy');
  // Schema e migrations nao podem divergir: o proximo `migrate dev` nao pode achar drift.
  prisma('migrate', 'diff', '--from-config-datasource', '--to-schema', 'prisma/schema.prisma', '--exit-code');
  // DT-07: a seed demo exige ambiente nao-producao, mesmo num banco descartavel.
  expect(() =>
    execFileSync(process.execPath, ['node_modules/prisma/build/index.js', 'db', 'seed'], {
      env: { ...prismaEnv, NODE_ENV: 'production' },
      timeout: 120_000,
      windowsHide: true,
      stdio: 'pipe',
    }),
  ).toThrow();
  for (let run = 0; run < 2; run += 1) {
    execFileSync(process.execPath, ['node_modules/prisma/build/index.js', 'db', 'seed'], {
      env: { ...prismaEnv, NODE_ENV: 'development' },
      timeout: 120_000,
      windowsHide: true,
      stdio: 'pipe',
    });
  }

  pool = new pg.Pool({ connectionString: databaseUrl, options: '-c timezone=UTC' });
  const httpPort = await freePort();
  // API e worker rodam em PRODUCAO: demo proibido, decisor real e schema migrado.
  runtimeEnv = {
    ...process.env,
    DATABASE_URL: databaseUrl,
    MQTT_URL: mqttUrl,
    QR_TOKEN_SECRET: QR_SECRET,
    JWT_SECRET,
    NODE_ENV: 'production',
    ACCESS_MODE: 'real',
    LOG_LEVEL: 'info',
    PORT: String(httpPort),
    TZ: 'America/Sao_Paulo',
  };
  baseUrl = `http://127.0.0.1:${httpPort}`;

  observer = await connectAsync(mqttUrl, { clientId: 'abp4-e2e-observer' });
  observer.on('message', (topic, payload) => {
    const message = JSON.parse(payload.toString()) as {
      terminalId: string;
      token?: string;
      expiresAt?: string;
    };
    if (topic.endsWith('/acks')) {
      receivedAcks.push(JSON.parse(payload.toString()) as AckMessage);
      return;
    }
    if (topic.endsWith('/qr')) {
      qrMessages.push({ token: message.token ?? '', expiresAt: message.expiresAt ?? '' });
      return;
    }
    if (!topic.endsWith('/commands')) return;
    receivedCommands.push(JSON.parse(payload.toString()) as CommandMessage);
    if (!autoAck) return;
    let terminal = terminals.get(message.terminalId);
    if (!terminal) {
      terminal = new SimulatedTerminal(
        message.terminalId,
        {
          publish: async (channel, output) => {
            await observer.publishAsync(
              `terminals/${output.terminalId}/${channel}`,
              JSON.stringify(output),
              { qos: 1 },
            );
          },
        },
        new SystemClock(),
        new CryptoIdGenerator(),
        {
          ...silentLogger,
          info: (msg, meta) => {
            if (msg === 'porta aberta (servo + led verde)') terminalExecutions.push(String(meta?.commandId));
          },
          warn: (msg, meta) => {
            if (msg === 'comando repetido: reenviando ack anterior') terminalDuplicates.push(String(meta?.commandId));
          },
        },
      );
      terminals.set(message.terminalId, terminal);
    }
    void terminal.onMessage(topic, payload);
  });
  await observer.subscribeAsync(['terminals/+/commands', 'terminals/+/qr', 'terminals/+/acks'], { qos: 1 });

  const apiProcess = launch('server');
  await waitFor(
    async () => {
      if (apiProcess.child.exitCode !== null) throw new Error(apiProcess.output());
      try {
        return (await fetch(`${baseUrl}/health`)).ok;
      } catch {
        return false;
      }
    },
    Boolean,
  );
  await startWorker();

  memberToken = await login(MEMBER_EMAIL, MEMBER_PASSWORD);
  adminToken = await login(ADMIN_EMAIL, ADMIN_PASSWORD);
}, 180_000);

afterAll(async () => {
  for (const child of children) {
    if (child.exitCode === null && !child.killed) {
      child.kill();
      await once(child, 'exit');
    }
  }
  if (observer) await observer.endAsync(true);
  if (broker) await new Promise<void>((resolve) => broker.close(() => resolve()));
  if (tcp?.listening) await new Promise<void>((resolve) => tcp.close(() => resolve()));
  if (pool) await pool.end();
  if (database) await database.stop();
  // No Windows, handles do PostgreSQL/antivirus podem sobreviver brevemente ao stop.
  if (tempDirectory) await rm(tempDirectory, { recursive: true, force: true, maxRetries: 10, retryDelay: 200 });
}, 90_000);

describe('DT-01: gate antes do MQTT nos dois entry points', () => {
  it('producao sem decisor real encerra sem conectar no broker', async () => {
    const run = launch('mqtt-consumer', { DATABASE_URL: '', MQTT_URL: 'mqtt://127.0.0.1:1' });
    const [code] = await once(run.child, 'exit');
    expect(code).not.toBe(0);
    expect(run.output()).toContain('decisor real');
    expect(run.output()).not.toContain('mqtt conectado');
  });

  it('producao recusa modo demo na validacao de ambiente', async () => {
    const run = launch('mqtt-consumer', { ACCESS_MODE: 'demo' });
    const [code] = await once(run.child, 'exit');
    expect(code).not.toBe(0);
    expect(run.output()).toContain('ACCESS_MODE');
    expect(run.output()).not.toContain('mqtt conectado');
  });

  it('banco sem migrations falha antes do MQTT', async () => {
    const run = launch('mqtt-consumer', {
      DATABASE_URL: databaseUrl.replace('/access_e2e', '/unmigrated'),
    });
    const [code] = await once(run.child, 'exit');
    expect(code).not.toBe(0);
    expect(run.output()).toContain('falha ao inicializar decisor real');
    expect(run.output()).not.toContain('mqtt conectado');
  });

  it('demo explicito fora de producao sobe sem banco, com aviso', async () => {
    const run = launch('mqtt-consumer', {
      NODE_ENV: 'development',
      ACCESS_MODE: 'demo',
      DATABASE_URL: '',
    });
    await waitFor(
      () => {
        if (run.child.exitCode !== null) throw new Error(run.output());
        return run.output();
      },
      (output) => output.includes('mqtt assinando'),
    );
    expect(run.output()).toContain('MODO DEMO');
    run.child.kill();
    await once(run.child, 'exit');
  });
});

describe('DT-05: deduplicacao persistente', () => {
  it('falha de publicacao apos decisao persistida permite retry sem renovar comando ou consumir outro uso', async () => {
    await stopChild(worker);
    let faulty: Awaited<ReturnType<typeof startFaultWorker>> | undefined;
    try {
      const { event, authorizationId } = await isolatedNfcAttempt();
      faulty = await startFaultWorker(event.terminalId, 'before-publish');
      await publishAttempt(event);
      const failure = await faulty.waitTrace('failed', event.messageId);
      expect(failure?.error).toBe('DT05_PUBLICATION_FAILURE');
      const original = (await commandRow(event.messageId))!.payload;
      expect(original.action).toBe('open');
      await expectSingleConsumption(event, authorizationId);
      expect((await pool.query('SELECT 1 FROM "ProcessedAccessMessage" WHERE "messageId"=$1', [event.messageId])).rowCount).toBe(0);
      expect(receivedCommands.filter((command) => command.commandId === original.commandId)).toHaveLength(0);

      expect(Date.parse(original.expiresAt)).toBeGreaterThan(Date.now());
      await publishAttempt(event);
      await faulty.waitTrace('handled', event.messageId);
      await completedMessage(event.messageId);
      expect((await waitCommandAck(event.messageId))?.payload).toEqual(original);
      expect(faulty.traces.filter((trace) => trace.type === 'publish-attempt').map((trace) => trace.command))
        .toEqual([original, original]);
      expect(receivedCommands.filter((command) => command.commandId === original.commandId)).toEqual([original]);
      await expectSingleConsumption(event, authorizationId);
    } finally {
      if (faulty) await stopChild(faulty.child);
      await startWorker();
    }
  });

  it('queda apos publicar e antes do commit retransmite mesmo comando sem segunda abertura', async () => {
    await stopChild(worker);
    const testWorkers: ChildProcess[] = [];
    try {
      const { event, authorizationId } = await isolatedNfcAttempt();
      const faulty = await startFaultWorker(event.terminalId, 'after-publish');
      testWorkers.push(faulty.child);
      await publishAttempt(event);
      const published = await faulty.waitTrace('published-before-commit');
      const original = published!.command!;
      expect(original.action).toBe('open');
      await waitCommandAck(event.messageId);
      await expectSingleConsumption(event, authorizationId);
      expect((await pool.query('SELECT 1 FROM "ProcessedAccessMessage" WHERE "messageId"=$1', [event.messageId])).rowCount).toBe(0);
      expect(terminalExecutions.filter((id) => id === original.commandId)).toHaveLength(1);
      await stopChild(faulty.child);

      const restarted = await startFaultWorker(event.terminalId);
      testWorkers.push(restarted.child);
      expect(Date.parse(original.expiresAt)).toBeGreaterThan(Date.now());
      await publishAttempt(event);
      await restarted.waitTrace('handled', event.messageId);
      await completedMessage(event.messageId);
      await waitFor(() => receivedAcks.filter((ack) => ack.commandId === original.commandId), (acks) => acks.length === 2);
      expect(receivedCommands.filter((command) => command.commandId === original.commandId)).toEqual([original, original]);
      expect(terminalExecutions.filter((id) => id === original.commandId)).toHaveLength(1);
      expect(terminalDuplicates.filter((id) => id === original.commandId)).toHaveLength(1);
      const acks = receivedAcks.filter((ack) => ack.commandId === original.commandId);
      expect(acks[0]?.status).toBe('executed');
      expect(acks[1]).toEqual(acks[0]);
      expect((await commandRow(event.messageId))?.payload).toEqual(original);
      await expectSingleConsumption(event, authorizationId);
    } finally {
      for (const child of testWorkers) await stopChild(child);
      await startWorker();
    }
  });

  it('dois consumidores recebem o mesmo NFC simultaneamente e so um decide, consome e publica', async () => {
    await stopChild(worker);
    const testWorkers: ChildProcess[] = [];
    try {
      const { event, authorizationId } = await isolatedNfcAttempt();
      const first = await startFaultWorker(event.terminalId, 'none', true);
      testWorkers.push(first.child);
      const second = await startFaultWorker(event.terminalId, 'none', true);
      testWorkers.push(second.child);
      await publishAttempt(event);
      // Ambos receberam o mesmo pacote antes de liberar a disputa pela reserva.
      await Promise.all([first.waitTrace('arrived', event.messageId), second.waitTrace('arrived', event.messageId)]);
      first.child.send('release');
      second.child.send('release');
      await Promise.all([first.waitTrace('handled', event.messageId), second.waitTrace('handled', event.messageId)]);
      const decisions = [...first.traces, ...second.traces].filter((trace) => trace.type === 'decide' && trace.messageId === event.messageId);
      expect(decisions).toHaveLength(1);
      await completedMessage(event.messageId);
      const command = (await waitCommandAck(event.messageId))!.payload;
      expect(command.action).toBe('open');
      expect(receivedCommands.filter((received) => received.commandId === command.commandId)).toEqual([command]);
      expect(terminalExecutions.filter((id) => id === command.commandId)).toHaveLength(1);
      await expectSingleConsumption(event, authorizationId);
    } finally {
      for (const child of testWorkers) await stopChild(child);
      await startWorker();
    }
  });

  it('queda do processo durante processamento libera a reserva sem marca orfa', async () => {
    const id = randomUUID();
    const child = spawn(process.execPath, ['--input-type=module', '-e', `
      import pg from 'pg';
      import { PostgresEventDeduplicator } from './dist/infrastructure/database/postgres-event-deduplicator.js';
      const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
      await new PostgresEventDeduplicator(pool).run(process.env.DT05_MESSAGE_ID, async () => {
        console.log('dt05-reserved');
        await new Promise(() => {});
      });
    `], {
      env: { ...runtimeEnv, DT05_MESSAGE_ID: id },
      windowsHide: true,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    children.push(child);
    let output = '';
    child.stdout?.on('data', (chunk: Buffer) => { output += chunk.toString(); });
    child.stderr?.on('data', (chunk: Buffer) => { output += chunk.toString(); });
    await waitFor(() => {
      if (child.exitCode !== null) throw new Error(output);
      return output;
    }, (text) => text.includes('dt05-reserved'));
    child.kill('SIGKILL');
    await once(child, 'exit');
    const restarted = new PostgresEventDeduplicator(pool);
    expect(await restarted.run(id, async () => 'retentativa'))
      .toEqual({ duplicate: false, value: 'retentativa' });
  });

  it('restart do worker nao republica NFC e replay antigo nao gera decisao', async () => {
    const terminalId = 'dt05-nao-cadastrado';
    const topic = `terminals/${terminalId}/access-events`;
    const event: AccessEventMessage = {
      v: 1, messageId: randomUUID(), terminalId, timestamp: new Date().toISOString(),
      type: 'nfc_read', uid: NFC_UID,
    };
    const received: string[] = [];
    const record = (receivedTopic: string, payload: Buffer) => {
      if (receivedTopic === `terminals/${terminalId}/commands`) {
        received.push((JSON.parse(payload.toString()) as { commandId: string }).commandId);
      }
    };
    observer.on('message', record);
    try {
      await observer.publishAsync(topic, JSON.stringify(event), { qos: 1 });
      await completedMessage(event.messageId);
      const original = await waitCommandAck(event.messageId);
      await stopChild(worker);
      await startWorker();
      await publishAttempt(event);
      // Confirma a causa exata do descarte; expirar o evento nao satisfaz o teste.
      await waitFor(() => workerOutput().split('\n').some((line) =>
        line.includes('tentativa duplicada descartada') && line.includes(event.messageId)), Boolean);
      const stale = { ...event, messageId: randomUUID(), timestamp: new Date(Date.now() - 60_000).toISOString() };
      await observer.publishAsync(topic, JSON.stringify(stale), { qos: 1 });
      await waitFor(() => workerOutput().split('\n').some((line) =>
        line.includes('mensagem descartada') && line.includes('"code":"stale"') && line.includes(topic)), Boolean);
      expect(received.filter((id) => id === original!.payload.commandId)).toHaveLength(1);
      expect((await pool.query('SELECT 1 FROM "AccessEvent" WHERE id=$1', [stale.messageId])).rowCount).toBe(0);
      expect(await commandRow(stale.messageId)).toBeUndefined();
    } finally {
      observer.off('message', record);
    }
  });

  it('sobrevive a restart da pool e a mais de 1.000 IDs sem eviccao', async () => {
    const id = randomUUID();
    const firstPool = new pg.Pool({ connectionString: databaseUrl });
    try {
      const first = new PostgresEventDeduplicator(firstPool);
      expect(await first.run(id, async () => 'primeiro')).toEqual({ duplicate: false, value: 'primeiro' });
      for (let i = 0; i < 1_001; i++) {
        await first.run(randomUUID(), async () => i);
      }
    } finally {
      await firstPool.end();
    }
    const restartedPool = new pg.Pool({ connectionString: databaseUrl });
    try {
      const restarted = new PostgresEventDeduplicator(restartedPool);
      expect(await restarted.run(id, async () => { throw new Error('nao deve executar'); }))
        .toEqual({ duplicate: true });
    } finally {
      await restartedPool.end();
    }
  });

  it('rollback libera o ID para outra instancia e concorrencia executa uma vez', async () => {
    const id = randomUUID();
    const first = new PostgresEventDeduplicator(pool);
    const second = new PostgresEventDeduplicator(pool);
    await expect(first.run(id, async () => { throw new Error('decisao falhou'); }))
      .rejects.toThrow('decisao falhou');
    let executions = 0;
    const work = async () => { executions++; return 'ok'; };
    const results = await Promise.all([first.run(id, work), second.run(id, work)]);
    expect(executions).toBe(1);
    expect(results.filter((result) => result.duplicate)).toHaveLength(1);
  });
});

describe('DT-03: terminal, evento e payload de negativa', () => {
  it('o banco valida o identificador e exige local cadastrado', async () => {
    await expect(
      pool.query('INSERT INTO "Terminal" (id,"locationId","updatedAt") VALUES ($1,$2,now())', [
        'terminal/invalido',
        'a1000000-0000-4000-8000-000000000003',
      ]),
    ).rejects.toMatchObject({ code: '23514' });
    await expect(
      pool.query('INSERT INTO "Terminal" (id,"locationId","updatedAt") VALUES ($1,$2,now())', [
        'sem-local',
        randomUUID(),
      ]),
    ).rejects.toMatchObject({ code: '23503' });
  });

  it('terminal desconhecido e negado, auditado sem local e visivel no historico', async () => {
    const messageId = randomUUID();
    const startedAt = Date.now();
    await observer.publishAsync(
      'terminals/nao-cadastrado/access-events',
      JSON.stringify({
        v: 1,
        messageId,
        terminalId: 'nao-cadastrado',
        timestamp: new Date().toISOString(),
        type: 'nfc_read',
        uid: NFC_UID,
      }),
      { qos: 1 },
    );

    const row = await waitFor(
      async () =>
        (
          await pool.query<{
            decision: string;
            reason: string | null;
            terminalId: string | null;
            locationId: string | null;
            occurredAt: Date;
          }>('SELECT * FROM "AccessEvent" WHERE id=$1', [messageId])
        ).rows[0],
      (candidate) => candidate !== undefined,
    );
    expect(row).toMatchObject({ decision: 'DENIED', reason: 'UNKNOWN_TERMINAL', terminalId: 'nao-cadastrado' });
    expect(row?.locationId).toBeNull();
    expect(new Date(row!.occurredAt).getTime()).toBeGreaterThanOrEqual(startedAt - 60_000);

    const response = await api('/access-events?decision=DENIED', adminToken);
    expect(response.status).toBe(200);
    const event = AccessEventPage.parse(await response.json()).items.find((item) => item.id === messageId);
    expect(event).toMatchObject({
      terminalId: 'nao-cadastrado',
      location: null,
      decision: 'DENIED',
      reason: 'UNKNOWN_TERMINAL',
    });

    const command = await waitCommandAck(messageId);
    expect(command?.payload.action).toBe('deny');
  });

  it('NFC resolve o local do terminal e consome a autorizacao', async () => {
    const messageId = randomUUID();
    await observer.publishAsync(
      `terminals/${TERMINAL}/access-events`,
      JSON.stringify({
        v: 1,
        messageId,
        terminalId: TERMINAL,
        timestamp: new Date().toISOString(),
        type: 'nfc_read',
        uid: NFC_UID,
      }),
      { qos: 1 },
    );

    const command = await waitCommandAck(messageId);
    expect(command?.payload.action).toBe('open');
    expect(command?.ackStatus).toBe('executed');

    const event = (await pool.query('SELECT * FROM "AccessEvent" WHERE id=$1', [messageId])).rows[0];
    expect(event.decision).toBe('GRANTED');
    expect(event.locationId).toBe('a1000000-0000-4000-8000-000000000003');
    expect(event.authorizationId).toBe('a1000000-0000-4000-8000-000000000004');
  });
});

describe('US-19 + DT-02: pedido QR assinado, comando persistido e ACK', () => {
  it('QR assinado libera, publica o comando do banco e recebe ACK', async () => {
    const qr = await freshQr();
    const requestId = randomUUID();
    const response = await api('/access-events/qr', memberToken, {
      terminalId: TERMINAL,
      qrToken: qr.token,
      position: DEMO_LOCATION,
      requestId,
    });

    expect(response.status, await response.clone().text()).toBe(200);
    const result = AccessResult.parse(await response.json());
    expect(result).toMatchObject({
      decision: 'GRANTED',
      reason: null,
      event: { id: requestId, terminalId: TERMINAL, location: { id: 'a1000000-0000-4000-8000-000000000003' } },
    });

    const command = await waitCommandAck(requestId);
    expect(command?.payload.action).toBe('open');
    expect(command?.ackStatus).toBe('executed');
  });

  it('repetir o mesmo requestId nao consome a autorizacao de novo', async () => {
    const qr = await freshQr();
    const requestId = randomUUID();
    const body = { terminalId: TERMINAL, qrToken: qr.token, position: DEMO_LOCATION, requestId };
    const before = (
      await pool.query('SELECT "usedCount" FROM "Authorization" WHERE id=$1', [
        'a1000000-0000-4000-8000-000000000004',
      ])
    ).rows[0].usedCount as number;

    const first = AccessResult.parse(await (await api('/access-events/qr', memberToken, body)).json());
    const second = AccessResult.parse(await (await api('/access-events/qr', memberToken, body)).json());

    expect(first.decision).toBe('GRANTED');
    expect(second.event.id).toBe(first.event.id);
    const after = (
      await pool.query('SELECT "usedCount" FROM "Authorization" WHERE id=$1', [
        'a1000000-0000-4000-8000-000000000004',
      ])
    ).rows[0].usedCount as number;
    expect(after - before).toBe(1);
    expect(
      (await pool.query('SELECT count(*)::int AS total FROM "TerminalCommand" WHERE "requestId"=$1', [requestId]))
        .rows[0].total,
    ).toBe(1);
  });

  it('QR expirado, adulterado e fora do raio nao geram comando', async () => {
    const qr = await freshQr();
    const cases = [
      [expiredQrToken(), DEMO_LOCATION, 'CREDENTIAL_EXPIRED'],
      ['v1.terminal-01.1.11.assinatura-invalida', DEMO_LOCATION, 'INVALID_CREDENTIAL'],
      [qr.token, { latitude: 0, longitude: 0 }, 'OUT_OF_RANGE'],
    ] as const;

    for (const [qrToken, position, reason] of cases) {
      const response = await api('/access-events/qr', memberToken, {
        terminalId: TERMINAL,
        qrToken,
        position,
      });
      expect(response.status).toBe(200);
      const result = AccessResult.parse(await response.json());
      expect(result).toMatchObject({ decision: 'DENIED', reason });
      expect(await commandRow(result.event.id)).toBeUndefined();
    }
  });

  it('terminal desativado nega mesmo com QR valido', async () => {
    const qr = await freshQr();
    await pool.query('UPDATE "Terminal" SET active=false WHERE id=$1', [TERMINAL]);
    try {
      const result = AccessResult.parse(
        await (
          await api('/access-events/qr', memberToken, {
            terminalId: TERMINAL,
            qrToken: qr.token,
            position: DEMO_LOCATION,
          })
        ).json(),
      );
      expect(result).toMatchObject({ decision: 'DENIED', reason: 'TERMINAL_INACTIVE' });
    } finally {
      await pool.query('UPDATE "Terminal" SET active=true WHERE id=$1', [TERMINAL]);
    }
  });

  it('comando pendente continua correlacionavel apos reiniciar o worker', async () => {
    const qr = await freshQr();
    autoAck = false;
    try {
      const result = AccessResult.parse(
        await (
          await api('/access-events/qr', memberToken, {
            terminalId: TERMINAL,
            qrToken: qr.token,
            position: DEMO_LOCATION,
          })
        ).json(),
      );
      const command = await commandRow(result.event.id);
      expect(command?.ackStatus).toBeNull();

      worker.kill();
      await once(worker, 'exit');
      await startWorker();

      await observer.publishAsync(
        `terminals/${TERMINAL}/acks`,
        JSON.stringify({
          v: 1,
          messageId: randomUUID(),
          terminalId: TERMINAL,
          timestamp: new Date().toISOString(),
          commandId: command?.payload.commandId,
          status: 'expired',
        }),
        { qos: 1 },
      );
      const acked = await waitFor(
        async () => (await commandRow(result.event.id))?.ackStatus,
        (status) => status === 'expired',
      );
      expect(acked).toBe('expired');
    } finally {
      autoAck = true;
    }
  });

  it('historico exige JWT real e perfil admin no global', async () => {
    expect((await api('/access-events', undefined)).status).toBe(401);
    expect((await api('/access-events', memberToken)).status).toBe(403);
    const mine = await api('/me/access-events', memberToken);
    expect(mine.status).toBe(200);
    expect(AccessEventPage.parse(await mine.json()).items.length).toBeGreaterThan(0);
  });
});

describe('DT-14: orcamento de conexoes da API', () => {
  // Cauda artificial no ramo HTTP: com NFC rapido e HTTP lento o cronometro do
  // NFC nao pode herdar a espera do outro ramo.
  const SLOW_HTTP_TAIL_MS = 5_200;

  it('rajada concorrente respeita o teto por fonte sem travar o NFC do worker', async () => {
    const qr = await freshQr();
    const peaks = new Map<string, number>();
    let samples = 0;
    await withPeakSampling(
      async () => {
        const rows = (
          await pool.query<{ name: string; total: number }>(
            `SELECT application_name AS name, count(*)::int AS total FROM pg_stat_activity
              WHERE datname = current_database() AND application_name LIKE 'abp4-%' GROUP BY 1`,
          )
        ).rows;
        for (const row of rows) peaks.set(row.name, Math.max(peaks.get(row.name) ?? 0, row.total));
        samples += 1;
      },
      async () => {
        // Preparacao dentro do trabalho: se ela falhar, o sampler tambem para.
        const { event } = await isolatedNfcAttempt();
        // So mede depois de o sampler estar de fato coletando.
        await waitFor(() => samples, Boolean, 5_000);
        const nfcStarted = Date.now();
        const nfc = (async () => {
          await publishAttempt(event);
          const acked = await waitCommandAck(event.messageId, 5_000);
          // Do envio do evento ao ACK do terminal: o ramo HTTP nao entra nesta conta.
          return { acked, latency: Date.now() - nfcStarted };
        })();
        const httpBurst = (async () => {
          const responses = await Promise.all([
            ...Array.from({ length: 20 }, () =>
              api('/access-events/qr', memberToken, {
                terminalId: TERMINAL,
                qrToken: qr.token,
                position: DEMO_LOCATION,
                requestId: randomUUID(),
              }),
            ),
            ...Array.from({ length: 10 }, () => api('/access-events?pageSize=50', adminToken)),
          ]);
          await delay(SLOW_HTTP_TAIL_MS);
          return responses;
        })();
        const [{ acked, latency: nfcLatency }, responses] = await Promise.all([nfc, httpBurst]);

        expect(responses.map((response) => response.status)).toEqual(Array(30).fill(200));
        expect(acked?.payload.action).toBe('open');
        // Sem o limite, o Prisma abriria ate 10 conexoes com 10 listagens simultaneas.
        expect(peaks.get('abp4-api-prisma') ?? 0).toBeGreaterThan(0);
        expect(peaks.get('abp4-api-prisma') ?? 0).toBeLessThanOrEqual(3);
        expect(peaks.get('abp4-api-access') ?? 0).toBeGreaterThan(0);
        expect(peaks.get('abp4-api-access') ?? 0).toBeLessThanOrEqual(3);
        expect(peaks.get('abp4-api-probe') ?? 0).toBeLessThanOrEqual(1);
        const apiPeak = [...peaks].filter(([name]) => name.startsWith('abp4-api-')).reduce((sum, [, n]) => sum + n, 0);
        expect(apiPeak).toBeLessThanOrEqual(7);
        expect([...peaks.keys()].filter((name) => name.startsWith('abp4-api-') && name.includes('events'))).toEqual([]);
        expect(peaks.get('abp4-worker-access') ?? 0).toBeLessThanOrEqual(5);
        expect(peaks.get('abp4-worker-events') ?? 0).toBeLessThanOrEqual(2);
        expect(nfcLatency).toBeLessThan(5_000);
      },
    );
  });
});
