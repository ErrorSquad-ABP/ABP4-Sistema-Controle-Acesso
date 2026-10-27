import { describe, expect, it, vi } from 'vitest';
import { provisionAdmin, type ProvisionDb } from '../../prisma/provision-admin.js';
import {
  assertDemoSeedAllowed,
  parseProvisionConfig,
  SeedRefusedError,
} from '../../src/shared/seed-guard.js';

const LOCAL_URL = 'postgresql://abp4:abp4@localhost:5436/abp4?schema=public';
const NEON_URL = 'postgresql://user:pass@ep-x-pooler.neon.tech/db?sslmode=require';

describe('assertDemoSeedAllowed', () => {
  it('libera banco local fora de producao e devolve a URL', () => {
    expect(assertDemoSeedAllowed({ DATABASE_URL: LOCAL_URL })).toBe(LOCAL_URL);
    expect(assertDemoSeedAllowed({ NODE_ENV: 'development', DATABASE_URL: 'postgres://u:p@127.0.0.1/db' })).toBeTruthy();
    expect(assertDemoSeedAllowed({ NODE_ENV: 'test', DATABASE_URL: 'postgres://u:p@postgres:5432/db' })).toBeTruthy();
  });

  it('recusa em producao, mesmo com banco local e com ALLOW_DEMO_SEED', () => {
    const base = { DATABASE_URL: LOCAL_URL, ALLOW_DEMO_SEED: 'true' };

    expect(() => assertDemoSeedAllowed({ ...base, NODE_ENV: 'production' })).toThrow(SeedRefusedError);
    expect(() => assertDemoSeedAllowed({ ...base, VERCEL_ENV: 'production' })).toThrow(/producao/);
  });

  it('recusa banco remoto sem opt-in explicito', () => {
    expect(() => assertDemoSeedAllowed({ DATABASE_URL: NEON_URL })).toThrow(/ep-x-pooler\.neon\.tech/);
    expect(() => assertDemoSeedAllowed({ DATABASE_URL: NEON_URL, ALLOW_DEMO_SEED: '1' })).toThrow(SeedRefusedError);
  });

  it('aceita banco remoto com ALLOW_DEMO_SEED=true fora de producao', () => {
    expect(assertDemoSeedAllowed({ DATABASE_URL: NEON_URL, ALLOW_DEMO_SEED: 'true' })).toBe(NEON_URL);
  });

  it('nao confunde host remoto que apenas contem "localhost"', () => {
    const url = 'postgresql://u:p@localhost.evil.example/db';

    expect(() => assertDemoSeedAllowed({ DATABASE_URL: url })).toThrow(SeedRefusedError);
  });

  it('recusa DATABASE_URL ausente, vazia ou invalida', () => {
    expect(() => assertDemoSeedAllowed({})).toThrow(/DATABASE_URL/);
    expect(() => assertDemoSeedAllowed({ DATABASE_URL: '  ' })).toThrow(/DATABASE_URL/);
    expect(() => assertDemoSeedAllowed({ DATABASE_URL: 'nao-e-url' })).toThrow(/URL valida/);
  });
});

describe('parseProvisionConfig', () => {
  const valid = {
    DATABASE_URL: NEON_URL,
    ADMIN_EMAIL: ' Admin@Empresa.com.br ',
    ADMIN_PASSWORD: 'uma-senha-longa-123',
  };

  it('aceita producao e banco remoto, normalizando o e-mail', () => {
    expect(parseProvisionConfig({ ...valid, NODE_ENV: 'production', ADMIN_NAME: ' Ana ' })).toEqual({
      databaseUrl: NEON_URL,
      adminName: 'Ana',
      adminEmail: 'admin@empresa.com.br',
      adminPassword: 'uma-senha-longa-123',
    });
  });

  it('usa nome padrao quando ADMIN_NAME nao e informado', () => {
    expect(parseProvisionConfig(valid).adminName).toBe('Administrador');
  });

  it('recusa e-mail ausente, malformado ou do dominio de demonstracao', () => {
    expect(() => parseProvisionConfig({ ...valid, ADMIN_EMAIL: undefined })).toThrow(/ADMIN_EMAIL/);
    expect(() => parseProvisionConfig({ ...valid, ADMIN_EMAIL: 'sem-arroba' })).toThrow(/ADMIN_EMAIL/);
    expect(() => parseProvisionConfig({ ...valid, ADMIN_EMAIL: 'admin@abp4.local' })).toThrow(/demonstra/);
  });

  it('recusa senha ausente ou curta', () => {
    expect(() => parseProvisionConfig({ ...valid, ADMIN_PASSWORD: undefined })).toThrow(/ADMIN_PASSWORD/);
    expect(() => parseProvisionConfig({ ...valid, ADMIN_PASSWORD: 'curta123' })).toThrow(/ADMIN_PASSWORD/);
  });

  it('recusa DATABASE_URL ausente', () => {
    expect(() => parseProvisionConfig({ ...valid, DATABASE_URL: undefined })).toThrow(/DATABASE_URL/);
  });
});

describe('provisionAdmin', () => {
  const config = { adminName: 'Ana', adminEmail: 'ana@empresa.com.br', adminPassword: 'uma-senha-longa-123' };

  function fakeDb(existing: { id: string } | null) {
    const create = vi.fn().mockResolvedValue({});
    const findUnique = vi.fn().mockResolvedValue(existing);
    return { db: { user: { findUnique, create } } as ProvisionDb, create, findUnique };
  }

  it('cria administrador ativo com hash scrypt e salt aleatorio, sem gravar a senha', async () => {
    const first = fakeDb(null);
    const second = fakeDb(null);

    expect(await provisionAdmin(first.db, config)).toBe('created');
    await provisionAdmin(second.db, config);

    const a = first.create.mock.calls[0]![0].data;
    const b = second.create.mock.calls[0]![0].data;
    expect(a).toMatchObject({ name: 'Ana', email: 'ana@empresa.com.br', role: 'ADMIN' });
    expect(a.passwordHash).toMatch(/^scrypt\$16384\$8\$1\$[0-9a-f]{32}\$[0-9a-f]{128}$/);
    expect(a.passwordHash).not.toContain(config.adminPassword);
    expect(a.passwordHash).not.toBe(b.passwordHash);
    expect(a.id).not.toBe(b.id);
  });

  it('nao altera nada quando o e-mail ja existe', async () => {
    const { db, create, findUnique } = fakeDb({ id: 'existente' });

    expect(await provisionAdmin(db, config)).toBe('already-exists');
    expect(findUnique).toHaveBeenCalledWith({ where: { email: 'ana@empresa.com.br' } });
    expect(create).not.toHaveBeenCalled();
  });
});
