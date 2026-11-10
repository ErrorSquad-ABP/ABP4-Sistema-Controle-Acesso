import { describe, expect, it } from 'vitest';
import { parseCorsOrigins } from '../../src/main/config/cors-origins.js';

describe('parseCorsOrigins', () => {
  it('vazio ou so espacos = lista vazia, sem erro (CORS desligado)', () => {
    expect(parseCorsOrigins('')).toEqual({ origins: [], errors: [] });
    expect(parseCorsOrigins('  , ,')).toEqual({ origins: [], errors: [] });
  });

  it('aceita origens exatas, ignora espacos e remove duplicados', () => {
    const result = parseCorsOrigins(' https://app.exemplo.com , http://localhost:5000,https://app.exemplo.com ');

    expect(result.errors).toEqual([]);
    expect(result.origins).toEqual(['https://app.exemplo.com', 'http://localhost:5000']);
  });

  it.each(['http://localhost:5000', 'http://127.0.0.1:8080', 'http://[::1]:3000', 'http://localhost'])(
    'aceita http apenas em loopback: %s',
    (origin) => {
      expect(parseCorsOrigins(origin)).toEqual({ origins: [origin], errors: [] });
    },
  );

  it.each([
    ['curinga', '*'],
    ['origem opaca', 'null'],
    ['origem opaca em maiusculas', 'NULL'],
    ['sem esquema', 'app.exemplo.com'],
    ['esquema nao http', 'ftp://app.exemplo.com'],
    ['barra final', 'https://app.exemplo.com/'],
    ['com caminho', 'https://app.exemplo.com/login'],
    ['com credenciais embutidas', 'https://usuario:senha@app.exemplo.com'],
    ['host em maiusculas', 'https://App.Exemplo.com'],
    ['porta padrao explicita', 'https://app.exemplo.com:443'],
    ['http fora de loopback', 'http://app.exemplo.com'],
    ['http em rede privada', 'http://192.168.0.10:3000'],
  ])('recusa %s', (_caso, origin) => {
    const result = parseCorsOrigins(origin);

    expect(result.origins).toEqual([]);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0]).toContain(origin);
  });

  it('sugere a forma correta quando a origem so precisa de normalizacao', () => {
    expect(parseCorsOrigins('https://app.exemplo.com/').errors[0]).toContain('use "https://app.exemplo.com"');
  });

  it('uma origem invalida na lista nao descarta as validas e todas as falhas sao reportadas', () => {
    const result = parseCorsOrigins('https://ok.exemplo.com,*,http://x.exemplo.com');

    expect(result.origins).toEqual(['https://ok.exemplo.com']);
    expect(result.errors).toHaveLength(2);
  });
});
