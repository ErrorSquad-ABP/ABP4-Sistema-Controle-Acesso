/** Hosts em que `http://` e aceito: o app web em desenvolvimento roda em localhost. */
const LOOPBACK_HOSTS = new Set(['localhost', '127.0.0.1', '[::1]']);

export interface ParsedCorsOrigins {
  origins: string[];
  errors: string[];
}

/**
 * Lista de origens permitidas (CORS_ALLOWED_ORIGINS, separadas por virgula).
 * Cada item precisa ser exatamente uma origem (`esquema://host[:porta]`): sem
 * caminho, sem barra final, sem curinga. Comparacao por igualdade, nunca regex.
 */
export function parseCorsOrigins(raw: string): ParsedCorsOrigins {
  const origins = new Set<string>();
  const errors: string[] = [];

  for (const item of raw.split(',').map((part) => part.trim()).filter(Boolean)) {
    if (item === '*' || item.toLowerCase() === 'null') {
      errors.push(`"${item}" nao e permitido: liste cada origem (ex.: https://app.exemplo.com)`);
      continue;
    }
    let url: URL;
    try {
      url = new URL(item);
    } catch {
      errors.push(`"${item}" nao e uma origem valida (use esquema://host[:porta])`);
      continue;
    }
    if (url.protocol !== 'http:' && url.protocol !== 'https:') {
      errors.push(`"${item}" deve usar http:// ou https://`);
      continue;
    }
    if (url.origin !== item) {
      errors.push(`"${item}" deve ser exatamente uma origem, sem caminho nem barra final; use "${url.origin}"`);
      continue;
    }
    if (url.protocol === 'http:' && !LOOPBACK_HOSTS.has(url.hostname)) {
      errors.push(`"${item}": http:// so e aceito em localhost, 127.0.0.1 e [::1]; use https://`);
      continue;
    }
    origins.add(item);
  }

  return { origins: [...origins], errors };
}
