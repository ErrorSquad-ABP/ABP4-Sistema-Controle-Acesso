import { randomUUID, createHash } from 'node:crypto';
import { spawn, execFileSync, type ChildProcess } from 'node:child_process';
import { once } from 'node:events';
import { createServer } from 'node:net';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import EmbeddedPostgres from 'embedded-postgres';
import { Aedes } from 'aedes';
import { SignJWT } from 'jose';
import pg from 'pg';
import { connectAsync, type MqttClient } from 'mqtt';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { AccessEventPage, AccessResult } from '../../src/main/http/contract/schemas/access-events.schemas.js';
import { SimulatedTerminal } from '../../src/main/sim/simulated-terminal.js';
import { SystemClock } from '../../src/infrastructure/clock/system-clock.js';
import { CryptoIdGenerator } from '../../src/infrastructure/ids/crypto-id-generator.js';
import { silentLogger } from '../support/terminal-fakes.js';
import { PostgresCommandStore } from '../../src/infrastructure/database/postgres-command-store.js';

interface CommandRow { payload: { action: string }; ackStatus: string }

const secret = 'e2e-local-only-'.repeat(4);
const userId = randomUUID();
const adminId = randomUUID();
const locationId = randomUUID();
const otherLocationId = randomUUID();
const authorizationId = randomUUID();
const terminalId = 'terminal-e2e';
const nfcUid = '04E2E001';
let database: EmbeddedPostgres;
let pool: pg.Pool;
let broker: Aedes;
let tcp: ReturnType<typeof createServer>;
let mqtt: MqttClient;
let tempDirectory: string;
let baseUrl: string;
let environment: NodeJS.ProcessEnv;
let worker: ChildProcess;
const children: ChildProcess[] = [];
const commands: Record<string, unknown>[] = [];
const qrMessages: { token: string; terminalId: string; expiresAt: string }[] = [];
let adminToken: string;
let userToken: string;
let autoAck = true;

async function waitFor<T>(read: () => Promise<T> | T, accept: (v: T) => boolean, timeout = 15_000): Promise<T> {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const result = await read();
    if (accept(result)) return result;
    await new Promise((resolve) => setTimeout(resolve, 40));
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
    env: { ...environment, ...overrides }, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
  });
  children.push(child);
  let output = '';
  child.stdout?.on('data', (chunk: Buffer) => { output += chunk.toString(); });
  child.stderr?.on('data', (chunk: Buffer) => { output += chunk.toString(); });
  return { child, output: () => output };
}

async function token(sub: string, key = secret) {
  return new SignJWT({}).setProtectedHeader({ alg: 'HS256' }).setSubject(sub)
    .setIssuer('abp4').setAudience('abp4-api').setIssuedAt().setExpirationTime('1h')
    .sign(new TextEncoder().encode(key));
}

async function api(path: string, bearer = userToken, body?: unknown) {
  return fetch(`${baseUrl}/api/v1${path}`, {
    method: body === undefined ? 'GET' : 'POST',
    headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}

async function freshQr() {
  const count = qrMessages.length;
  for (const state of ['offline', 'online']) {
    await mqtt.publishAsync(`terminals/${terminalId}/status`, JSON.stringify({
      v: 1, messageId: randomUUID(), terminalId, timestamp: new Date().toISOString(), state,
    }), { qos: 1 });
  }
  await waitFor(() => qrMessages.length, (length) => length > count);
  return qrMessages.at(-1)!;
}

async function requestQr(position = { latitude: -23, longitude: -45 }) {
  const qr = await freshQr();
  const response = await api('/access-events/qr', userToken, { terminalId, qrToken: qr.token, position });
  expect(response.status).toBe(200);
  return AccessResult.parse(await response.json());
}

async function startWorker() {
  const consumer = launch('mqtt-consumer', { TZ: 'UTC' });
  worker = consumer.child;
  await waitFor(() => {
    if (worker.exitCode !== null) throw new Error(consumer.output());
    return consumer.output();
  }, (output) => output.includes('mqtt assinando'));
}

beforeAll(async () => {
  tempDirectory = await mkdtemp(join(tmpdir(), 'abp4-dt-e2e-'));
  const postgresPort = await freePort();
  database = new EmbeddedPostgres({ databaseDir: join(tempDirectory, 'postgres'),
    port: postgresPort, user: 'abp4', password: 'local-e2e', persistent: true,
    onLog: () => {}, onError: () => {},
    postgresFlags: ['-h', '127.0.0.1'],
  });
  await database.initialise();
  await database.start();
  await database.createDatabase('access_e2e');
  await database.createDatabase('unmigrated');
  const connectionString = `postgresql://abp4:local-e2e@127.0.0.1:${postgresPort}/access_e2e`;
  pool = new pg.Pool({ connectionString, options: '-c timezone=UTC' });
  broker = await Aedes.createBroker();
  tcp = createServer(broker.handle);
  tcp.listen(0, '127.0.0.1');
  await once(tcp, 'listening');
  const mqttUrl = `mqtt://127.0.0.1:${(tcp.address() as { port: number }).port}`;
  const httpPort = await freePort();
  environment = { ...process.env, DATABASE_URL: connectionString, MQTT_URL: mqttUrl,
    NODE_ENV: 'production', ACCESS_MODE: 'real', LOG_LEVEL: 'info',
    JWT_SECRET: secret, PORT: String(httpPort), TZ: 'America/Sao_Paulo',
  };
  execFileSync(process.execPath, ['node_modules/prisma/build/index.js', 'migrate', 'deploy'], {
    env: environment, timeout: 60_000, windowsHide: true, stdio: 'pipe',
  });
  execFileSync(process.execPath, ['node_modules/prisma/build/index.js', 'migrate', 'diff',
    '--from-config-datasource', '--to-schema', 'prisma/schema.prisma', '--exit-code'], {
    env: environment, timeout: 60_000, windowsHide: true, stdio: 'pipe',
  });
  for (let run = 0; run < 2; run++) {
    execFileSync(process.execPath, ['node_modules/prisma/build/index.js', 'db', 'seed'], {
      env: environment, timeout: 60_000, windowsHide: true, stdio: 'pipe',
    });
  }
  await pool.query(`INSERT INTO "User" (id,name,email,"passwordHash",role,"updatedAt") VALUES
    ($1,'Maria','maria@e2e.local','not-used','RESIDENT',now()),
    ($2,'Admin','admin@e2e.local','not-used','ADMIN',now())`, [userId, adminId]);
  await pool.query(`INSERT INTO "AccessLocation" (id,name,latitude,longitude,"updatedAt") VALUES
    ($1,'Recepcao',-23,-45,now()),($2,'Outro local',-20,-40,now())`, [locationId, otherLocationId]);
  await pool.query(`INSERT INTO "Terminal" (id,"locationId","updatedAt") VALUES ($1,$2,now())`, [terminalId, locationId]);
  await pool.query(`INSERT INTO "Authorization" (id,"userId","locationId","startsAt","endsAt","maxUses","updatedAt")
    VALUES ($1,$2,$3,now()-interval '1 hour',now()+interval '1 hour',10,now())`, [authorizationId,userId,locationId]);
  await pool.query(`INSERT INTO "Credential" (id,"userId",type,"valueHash","updatedAt") VALUES ($1,$2,'NFC',$3,now())`,
    [randomUUID(),userId,createHash('sha256').update(nfcUid).digest('hex')]);
  adminToken = await token(adminId);
  userToken = await token(userId);
  baseUrl = `http://127.0.0.1:${httpPort}`;
  mqtt = await connectAsync(mqttUrl, { clientId: 'abp4-e2e-observer' });
  const terminals = new Map<string, SimulatedTerminal>();
  mqtt.on('message', (topic, payload) => {
    const message = JSON.parse(payload.toString());
    if (topic.endsWith('/qr')) qrMessages.push(message);
    if (topic.endsWith('/commands')) {
      commands.push(message);
      if (autoAck) {
        let terminal = terminals.get(message.terminalId);
        if (!terminal) {
          terminal = new SimulatedTerminal(message.terminalId, {
            publish: async (channel, output) => { await mqtt.publishAsync(`terminals/${output.terminalId}/${channel}`, JSON.stringify(output), { qos: 1 }); },
          }, new SystemClock(), new CryptoIdGenerator(), silentLogger);
          terminals.set(message.terminalId, terminal);
        }
        void terminal.onMessage(topic, payload);
      }
    }
  });
  await mqtt.subscribeAsync(['terminals/+/commands','terminals/+/qr'], { qos: 1 });
  const apiProcess = launch('server');
  await waitFor(async () => {
    if (apiProcess.child.exitCode !== null) throw new Error(apiProcess.output());
    try { return (await fetch(`${baseUrl}/health`)).ok; } catch { return false; }
  }, Boolean);
  await startWorker();
}, 120_000);

afterAll(async () => {
  for (const child of children) {
    if (child.exitCode === null && !child.killed) {
      child.kill();
      await once(child, 'exit');
    }
  }
  if (mqtt) await mqtt.endAsync(true);
  if (broker) await new Promise<void>((resolve) => broker.close(() => resolve()));
  if (tcp?.listening) await new Promise<void>((resolve) => tcp.close(() => resolve()));
  if (pool) await pool.end();
  if (database) await database.stop();
  if (tempDirectory) await rm(tempDirectory, { recursive: true, force: true });
}, 60_000);

describe('DT-01/02/03: HTTP + processos independentes + PostgreSQL + MQTT TCP', () => {
  it('producao encerra sem decisor real e sem tentar conectar no broker', async () => {
    const run = launch('mqtt-consumer', { DATABASE_URL: '', MQTT_URL: 'mqtt://127.0.0.1:1' });
    const [code] = await once(run.child, 'exit');
    expect(code).not.toBe(0);
    expect(run.output()).toContain('decisor real');
    expect(run.output()).not.toContain('mqtt conectado');
  });

  it('producao rejeita modo demo', async () => {
    const run = launch('mqtt-consumer', { ACCESS_MODE: 'demo' });
    const [code] = await once(run.child, 'exit');
    expect(code).not.toBe(0);
    expect(run.output()).toContain('ACCESS_MODE');
  });

  it('demo explicito inicia fora de producao sem depender de decisor ou banco', async () => {
    const run = launch('mqtt-consumer', { NODE_ENV: 'development', ACCESS_MODE: 'demo', DATABASE_URL: '' });
    await waitFor(() => {
      if (run.child.exitCode !== null) throw new Error(run.output());
      return run.output();
    }, (output) => output.includes('mqtt assinando'));
    expect(run.output()).toContain('MODO DEMO');
    run.child.kill();
    await once(run.child, 'exit');
  });

  it('producao falha antes do MQTT se as migrations nao foram aplicadas', async () => {
    const run = launch('mqtt-consumer', { DATABASE_URL: environment.DATABASE_URL!.replace('/access_e2e', '/unmigrated') });
    const [code] = await once(run.child, 'exit');
    expect(code).not.toBe(0);
    expect(run.output()).toContain('falha ao inicializar decisor real');
    expect(run.output()).not.toContain('mqtt conectado');
  });

  it('banco valida o identificador e o vinculo obrigatorio do terminal', async () => {
    await expect(pool.query('INSERT INTO "Terminal" (id,"locationId","updatedAt") VALUES ($1,$2,now())', ['terminal/invalido',locationId]))
      .rejects.toMatchObject({ code: '23514' });
    await expect(pool.query('INSERT INTO "Terminal" (id,"locationId","updatedAt") VALUES ($1,$2,now())', ['sem-local',randomUUID()]))
      .rejects.toMatchObject({ code: '23503' });
  });

  it('terminal desconhecido e negado e consultavel sem local', async () => {
    const startedAt = Date.now();
    const messageId = randomUUID();
    await mqtt.publishAsync('terminals/desconhecido/access-events', JSON.stringify({ v: 1, messageId,
      terminalId: 'desconhecido', timestamp: new Date().toISOString(), type: 'nfc_read', uid: nfcUid }), { qos: 1 });
    await waitFor(async () => (await pool.query('SELECT * FROM "AccessEvent" WHERE id=$1', [messageId])).rows[0], Boolean);
    const response = await api('/access-events?decision=DENIED', adminToken);
    expect(response.status).toBe(200);
    const event = AccessEventPage.parse(await response.json()).items.find((e) => e.id === messageId);
    expect(event).toMatchObject({ terminalId: 'desconhecido', location: null, decision: 'DENIED', reason: 'UNKNOWN_TERMINAL' });
    expect(Date.parse(event!.occurredAt)).toBeGreaterThanOrEqual(startedAt);
    expect(Date.parse(event!.occurredAt)).toBeLessThanOrEqual(Date.now());
    const brazilOffset = (time: number) => new Date(time - 3*60*60*1000).toISOString().replace('Z', '-03:00');
    const period = new URLSearchParams({ from: brazilOffset(startedAt-1000), to: brazilOffset(Date.now()+1000) });
    const filtered = await api(`/access-events?${period}`, adminToken);
    expect(AccessEventPage.parse(await filtered.json()).items.some((e) => e.id === messageId)).toBe(true);
    await waitFor(() => commands.find((c) => c.terminalId === 'desconhecido'), Boolean);
    expect(commands.find((c) => c.terminalId === 'desconhecido')?.action).toBe('deny');
  });

  it('NFC valida credencial e autorizacao do local mapeado', async () => {
    const messageId = randomUUID();
    await mqtt.publishAsync(`terminals/${terminalId}/access-events`, JSON.stringify({ v: 1, messageId,
      terminalId, timestamp: new Date().toISOString(), type: 'nfc_read', uid: nfcUid }), { qos: 1 });
    const row = await waitFor<CommandRow | undefined>(async () => (await pool.query<CommandRow>('SELECT * FROM "TerminalCommand" WHERE "requestId"=$1 AND "ackStatus" IS NOT NULL', [messageId])).rows[0], Boolean);
    expect(row?.ackStatus).toBe('executed');
    expect(row?.payload.action).toBe('open');
    const event = (await pool.query('SELECT * FROM "AccessEvent" WHERE id=$1', [messageId])).rows[0];
    expect(event.locationId).toBe(locationId);
    expect(event.authorizationId).toBe(authorizationId);
  });

  it('API cria comando QR e ACK e correlacionado pelo worker', async () => {
    await mqtt.publishAsync(`terminals/${terminalId}/status`, JSON.stringify({ v: 1, messageId: randomUUID(),
      terminalId, timestamp: new Date().toISOString(), state: 'online' }), { qos: 1 });
    const qr = await waitFor(() => qrMessages.at(-1), Boolean);
    const response = await api('/access-events/qr', userToken, { terminalId, qrToken: qr!.token,
      position: { latitude: -23, longitude: -45 } });
    expect(response.status).toBe(200);
    const result = AccessResult.parse(await response.json());
    expect(result).toMatchObject({ decision: 'GRANTED', reason: null, event: { terminalId, location: { id: locationId } } });
    const command = await waitFor<CommandRow | undefined>(async () => (await pool.query<CommandRow>('SELECT * FROM "TerminalCommand" WHERE "requestId"=$1 AND "ackStatus" IS NOT NULL', [result.event.id])).rows[0], Boolean);
    expect(command?.payload.action).toBe('open');
    expect(command?.ackStatus).toBe('executed');
  });

  it('nega QR invalido e fora da geofence sem enviar abertura', async () => {
    const qr = qrMessages.at(-1)!;
    for (const [qrToken, position, reason] of [
      ['token-inventado', { latitude: -23, longitude: -45 }, 'INVALID_CREDENTIAL'],
      [qr.token, { latitude: 0, longitude: 0 }, 'OUT_OF_RANGE'],
    ] as const) {
      const response = await api('/access-events/qr', userToken, { terminalId, qrToken, position });
      expect(response.status).toBe(200);
      const result = AccessResult.parse(await response.json());
      expect(result).toMatchObject({ decision: 'DENIED', reason });
      expect((await pool.query('SELECT * FROM "TerminalCommand" WHERE "requestId"=$1', [result.event.id])).rowCount).toBe(0);
    }
  });

  it('rotas reais exigem JWT valido e perfil admin para o historico global', async () => {
    expect((await api('/access-events', '')).status).toBe(401);
    expect((await api('/access-events', await token(adminId, 'wrong-key-'.repeat(8)))).status).toBe(401);
    expect((await api('/access-events', userToken)).status).toBe(403);
    expect((await api('/me/access-events', userToken)).status).toBe(200);
    const expired = await new SignJWT({}).setProtectedHeader({ alg: 'HS256' }).setSubject(adminId)
      .setIssuer('abp4').setAudience('abp4-api').setIssuedAt(Math.floor(Date.now()/1000)-7200)
      .setExpirationTime(Math.floor(Date.now()/1000)-3600).sign(new TextEncoder().encode(secret));
    expect((await api('/access-events', expired)).status).toBe(401);
  });

  it('ACK errado nao consome pendencia; ACK repetido nao sobrescreve o resultado', async () => {
    autoAck = false;
    try {
      const result = await requestQr();
      const row = (await pool.query<{ commandId: string }>('SELECT "commandId" FROM "TerminalCommand" WHERE "requestId"=$1', [result.event.id])).rows[0]!;
      const store = new PostgresCommandStore(pool);
      const ack = { v: 1 as const, messageId: randomUUID(), terminalId, timestamp: new Date().toISOString(), commandId: row.commandId, status: 'rejected' as const };
      expect(await store.acknowledge({ ...ack, terminalId: 'outro-terminal' })).toEqual({ status: 'unknown' });
      const otherPool = new pg.Pool({ connectionString: environment.DATABASE_URL });
      try {
        const concurrent = await Promise.all([store.acknowledge(ack), new PostgresCommandStore(otherPool).acknowledge({ ...ack, messageId: randomUUID() })]);
        expect(concurrent.map((v) => v.status).sort()).toEqual(['correlated','duplicate']);
      } finally { await otherPool.end(); }
      expect(await store.acknowledge({ ...ack, messageId: randomUUID(), status: 'executed' })).toEqual({ status: 'duplicate' });
      expect((await pool.query('SELECT "ackStatus" FROM "TerminalCommand" WHERE "commandId"=$1', [row.commandId])).rows[0].ackStatus).toBe('rejected');
    } finally { autoAck = true; }
  });

  it('comando criado pela API continua correlacionavel apos reinicio do worker', async () => {
    autoAck = false;
    try {
      const result = await requestQr();
      const command = (await pool.query('SELECT * FROM "TerminalCommand" WHERE "requestId"=$1', [result.event.id])).rows[0];
      expect(command.ackStatus).toBeNull();
      worker.kill();
      await once(worker, 'exit');
      await startWorker();
      await mqtt.publishAsync(`terminals/${terminalId}/acks`, JSON.stringify({
        v: 1, messageId: randomUUID(), terminalId, timestamp: new Date().toISOString(), commandId: command.commandId, status: 'expired',
      }), { qos: 1 });
      const status = await waitFor(async () => (await pool.query('SELECT "ackStatus" FROM "TerminalCommand" WHERE "commandId"=$1', [command.commandId])).rows[0].ackStatus as string | null, Boolean);
      expect(status).toBe('expired');
    } finally { autoAck = true; }
  });

  it('mudar o local do terminal impede usar autorizacao do local anterior', async () => {
    await pool.query('UPDATE "Terminal" SET "locationId"=$1 WHERE id=$2', [otherLocationId,terminalId]);
    try {
      expect(await requestQr({ latitude: -20, longitude: -40 })).toMatchObject({ decision: 'DENIED', reason: 'NO_AUTHORIZATION', event: { location: { id: otherLocationId } } });
    } finally { await pool.query('UPDATE "Terminal" SET "locationId"=$1 WHERE id=$2', [locationId,terminalId]); }
  });

  it('token QR expirado e terminal desativado geram negativas auditadas', async () => {
    const expiredToken = randomUUID();
    await pool.query('INSERT INTO "TerminalQrToken" ("valueHash","terminalId","expiresAt") VALUES ($1,$2,now()-interval \'1 second\')',
      [createHash('sha256').update(expiredToken).digest('hex'),terminalId]);
    let response = await api('/access-events/qr', userToken, { terminalId, qrToken: expiredToken, position: { latitude: -23, longitude: -45 } });
    expect(AccessResult.parse(await response.json())).toMatchObject({ decision: 'DENIED', reason: 'CREDENTIAL_EXPIRED' });
    await pool.query('UPDATE "Terminal" SET active=false WHERE id=$1', [terminalId]);
    try {
      response = await api('/access-events/qr', userToken, { terminalId, qrToken: expiredToken, position: { latitude: -23, longitude: -45 } });
      expect(AccessResult.parse(await response.json())).toMatchObject({ decision: 'DENIED', reason: 'TERMINAL_INACTIVE' });
    } finally { await pool.query('UPDATE "Terminal" SET active=true WHERE id=$1', [terminalId]); }
  });

  it('duas requisicoes concorrentes nao gastam o mesmo ultimo uso', async () => {
    await pool.query('UPDATE "Authorization" SET "maxUses"="usedCount"+1 WHERE id=$1', [authorizationId]);
    const qr = await freshQr();
    const responses = await Promise.all([1,2].map(() => api('/access-events/qr', userToken, {
      terminalId, qrToken: qr.token, position: { latitude: -23, longitude: -45 },
    })));
    expect(responses.map((r) => r.status)).toEqual([200,200]);
    const results = await Promise.all(responses.map(async (r) => AccessResult.parse(await r.json())));
    expect(results.map((r) => r.decision).sort()).toEqual(['DENIED','GRANTED']);
    expect(results.find((r) => r.decision === 'DENIED')?.reason).toBe('NO_USES_LEFT');
    const count = (await pool.query('SELECT "maxUses","usedCount" FROM "Authorization" WHERE id=$1', [authorizationId])).rows[0];
    expect(count.usedCount).toBe(count.maxUses);
  });
});
