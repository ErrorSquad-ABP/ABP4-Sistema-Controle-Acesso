/** Verifica se o banco responde. Lanca se estiver inacessivel (rede, credencial, timeout). */
export interface DatabaseProbe {
  ping(): Promise<void>;
}
