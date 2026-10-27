/** Verifica assinatura, emissor, audiencia e validade; devolve o subject autenticado. */
export interface IdentityVerifier { verify(token: string): Promise<string> }
