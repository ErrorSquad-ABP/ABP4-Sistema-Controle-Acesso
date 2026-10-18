/** Fonte de tempo. Port para os casos de uso nao dependerem de `new Date()` (testavel). */
export interface Clock {
  now(): Date;
}
