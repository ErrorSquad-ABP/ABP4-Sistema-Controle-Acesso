/** UID NFC e material de credencial (o banco guarda so o hash): o log fica com o minimo. */
export function maskUid(uid: string): string {
  return uid.length <= 4 ? '****' : `****${uid.slice(-4)}`;
}

/** Mensagem de erro do driver pode citar a URL do banco: a credencial nao vai para o log. */
export function redactConnectionString(text: string): string {
  return text.replace(/postgres(?:ql)?:\/\/\S+/gi, 'postgresql://***');
}
