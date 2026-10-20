/** Geracao de ids e tokens. Port para os casos de uso ficarem deterministicos nos testes. */
export interface IdGenerator {
  uuid(): string;
  token(): string;
}
