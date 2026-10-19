/** UID NFC e material de credencial (o banco guarda so o hash): o log fica com o minimo. */
export function maskUid(uid: string): string {
  return uid.length <= 4 ? '****' : `****${uid.slice(-4)}`;
}
