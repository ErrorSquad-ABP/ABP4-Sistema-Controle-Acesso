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
import {
  AccessEventPage,
  AccessResult,
} from '../../src/main/http/contract/schemas/access-events.schemas.js';
import { SimulatedTerminal } from '../../src/main/sim/simulated-terminal.js';
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
const children: ChildProcess[] = [];
const qrMessages: { token: string; expiresAt: string }[] = [];
const terminals = new Map<string, SimulatedTerminal>();
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
  await waitFor(
    () => {
      if (worker.exitCode !== null) throw new Error(consumer.output());
      return consumer.output();
    },
    (output) => output.includes('mqtt assinando'),
  );
}

async function commandRow(requestId: string) {
  return (
    await pool.query<{ payload: { action: string; commandId: string }; ackStatus: string | null }>(
      'SELECT payload,"ackStatus" FROM "TerminalCommand" WHERE "requestId"=$1',
      [requestId],
    )
  ).rows[0];
}

async function waitCommandAck(requestId: string) {
  return waitFor(() => commandRow(requestId), (row) => row?.ackStatus !== null && row !== undefined);
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
    if (topic.endsWith('/qr')) {
      qrMessages.push({ token: message.token ?? '', expiresAt: message.expiresAt ?? '' });
      return;
    }
    if (!topic.endsWith('/commands') || !autoAck) return;
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
        silentLogger,
      );
      terminals.set(message.terminalId, terminal);
    }
    void terminal.onMessage(topic, payload);
  });
  await observer.subscribeAsync(['terminals/+/commands', 'terminals/+/qr'], { qos: 1 });

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
  if (tempDirectory) await rm(tempDirectory, { recursive: true, force: true });
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
