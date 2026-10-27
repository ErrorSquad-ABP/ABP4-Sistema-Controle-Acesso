import { describe, expect, it } from 'vitest';
import { EXAMPLE_IDS } from '../../src/main/http/contract/operations.js';
import {
  ListAccessEventsQuery,
  QrAccessRequest,
} from '../../src/main/http/contract/schemas/access-events.schemas.js';
import { LoginRequest } from '../../src/main/http/contract/schemas/auth.schemas.js';
import { ValidateQrCredentialRequest, ValidateQrCredentialResponse } from '../../src/main/http/contract/schemas/credentials.schemas.js';
import {
  CreateAuthorizationRequest,
  ListAuthorizationsQuery,
} from '../../src/main/http/contract/schemas/authorizations.schemas.js';
import {
  CreateUserRequest,
  ListUsersQuery,
  UpdateUserRequest,
} from '../../src/main/http/contract/schemas/users.schemas.js';

/** Caminhos dos campos com erro, para asserts legiveis. */
function issuePaths(result: { success: boolean; error?: { issues: { path: PropertyKey[] }[] } }): string[] {
  return result.error?.issues.map((issue) => issue.path.join('.')) ?? [];
}

describe('LoginRequest', () => {
  it('normaliza o e-mail para minusculas', () => {
    const parsed = LoginRequest.parse({ email: 'Maria.Souza@Exemplo.com', password: 'x' });
    expect(parsed.email).toBe('maria.souza@exemplo.com');
  });

  it('rejeita e-mail invalido e senha vazia', () => {
    const result = LoginRequest.safeParse({ email: 'maria', password: '' });
    expect(issuePaths(result)).toEqual(expect.arrayContaining(['email', 'password']));
  });
});

describe('ValidateQrCredentialRequest / Response', () => {
  it('exige qrToken e terminalId validos', () => {
    expect(ValidateQrCredentialRequest.safeParse({ qrToken: 'token', terminalId: 'terminal-01' }).success).toBe(true);
    expect(ValidateQrCredentialRequest.safeParse({ token: 'token', terminalId: 'terminal-01' }).success).toBe(false);
    expect(ValidateQrCredentialRequest.safeParse({ qrToken: '', terminalId: 'terminal-01' }).success).toBe(false);
  });

  it('resposta positiva inclui apenas terminal e expiracao; negativa nao inclui metadados', () => {
    expect(ValidateQrCredentialResponse.safeParse({ valid: true, terminalId: 'terminal-01', expiresAt: '2026-10-26T12:00:10.000Z' }).success).toBe(true);
    expect(ValidateQrCredentialResponse.safeParse({ valid: false }).success).toBe(true);
    const withExtra = ValidateQrCredentialResponse.parse({ valid: true, terminalId: 'terminal-01', expiresAt: '2026-10-26T12:00:10.000Z', decision: 'GRANTED' });
    expect(withExtra).toEqual({ valid: true, terminalId: 'terminal-01', expiresAt: '2026-10-26T12:00:10.000Z' });
  });
});

describe('CreateUserRequest', () => {
  const valid = { name: 'Maria Souza', email: 'maria@exemplo.com', password: 'senha-forte', role: 'VISITOR' };

  it('aceita um cadastro valido', () => {
    expect(CreateUserRequest.safeParse(valid).success).toBe(true);
  });

  it('exige senha com 8+ caracteres e perfil conhecido', () => {
    const result = CreateUserRequest.safeParse({ ...valid, password: '1234567', role: 'SINDICO' });
    expect(issuePaths(result)).toEqual(expect.arrayContaining(['password', 'role']));
  });
});

describe('UpdateUserRequest', () => {
  it('aceita atualizacao parcial', () => {
    expect(UpdateUserRequest.safeParse({ active: false }).success).toBe(true);
  });

  it('rejeita corpo sem nenhum campo', () => {
    expect(UpdateUserRequest.safeParse({}).success).toBe(false);
  });
});

describe('CreateAuthorizationRequest', () => {
  const valid = {
    userId: EXAMPLE_IDS.user,
    locationId: EXAMPLE_IDS.location,
    startsAt: '2026-10-20T14:00:00-03:00',
    endsAt: '2026-10-20T18:00:00-03:00',
    maxUses: 5,
  };

  it('aceita janela valida com offset de fuso', () => {
    expect(CreateAuthorizationRequest.safeParse(valid).success).toBe(true);
  });

  it('rejeita fim antes do inicio', () => {
    const result = CreateAuthorizationRequest.safeParse({ ...valid, endsAt: '2026-10-20T13:00:00-03:00' });
    expect(issuePaths(result)).toEqual(['endsAt']);
  });

  it('rejeita zero usos e ids que nao sao UUID', () => {
    const result = CreateAuthorizationRequest.safeParse({ ...valid, maxUses: 0, userId: '42' });
    expect(issuePaths(result)).toEqual(expect.arrayContaining(['maxUses', 'userId']));
  });
});

describe('QrAccessRequest', () => {
  const valid = {
    qrToken: 'abc',
    terminalId: 'aurora-recepcao',
    position: { latitude: -23.18, longitude: -45.88 },
  };

  it('aceita token + terminal + posicao', () => {
    expect(QrAccessRequest.safeParse(valid).success).toBe(true);
  });

  it('exige terminalId em formato de id de topico MQTT', () => {
    expect(issuePaths(QrAccessRequest.safeParse({ ...valid, terminalId: undefined }))).toEqual(['terminalId']);
    expect(issuePaths(QrAccessRequest.safeParse({ ...valid, terminalId: 'Recepcao/1' }))).toEqual(['terminalId']);
    expect(QrAccessRequest.safeParse({ ...valid, terminalId: 'a'.repeat(64) }).success).toBe(true);
    expect(QrAccessRequest.safeParse({ ...valid, terminalId: 'a'.repeat(65) }).success).toBe(false);
    expect(QrAccessRequest.safeParse({ ...valid, terminalId: '-terminal' }).success).toBe(false);
  });

  it('rejeita coordenadas fora da faixa e token vazio', () => {
    const result = QrAccessRequest.safeParse({ ...valid, qrToken: '', position: { latitude: 91, longitude: -181 } });
    expect(issuePaths(result)).toEqual(
      expect.arrayContaining(['qrToken', 'position.latitude', 'position.longitude']),
    );
  });
});

describe('queries de listagem', () => {
  it('converte paginacao da query string e aplica defaults', () => {
    expect(ListUsersQuery.parse({})).toMatchObject({ page: 1, pageSize: 20 });
    expect(ListUsersQuery.parse({ page: '3', pageSize: '50', active: 'false' })).toMatchObject({
      page: 3,
      pageSize: 50,
      active: false,
    });
  });

  it('limita pageSize a 100', () => {
    expect(ListUsersQuery.safeParse({ pageSize: '101' }).success).toBe(false);
  });

  it('rejeita periodo com `to` antes de `from`', () => {
    const query = { from: '2026-10-31T00:00:00Z', to: '2026-10-01T00:00:00Z' };
    expect(issuePaths(ListAccessEventsQuery.safeParse(query))).toEqual(['to']);
    expect(issuePaths(ListAuthorizationsQuery.safeParse(query))).toEqual(['to']);
  });

  it('rejeita enums desconhecidos nos filtros', () => {
    expect(ListAccessEventsQuery.safeParse({ method: 'BLUETOOTH' }).success).toBe(false);
  });
});
