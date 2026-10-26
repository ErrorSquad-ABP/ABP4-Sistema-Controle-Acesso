# US-17 — revisão da fase 3

Revisão realizada em 26/10/2026 contra o contrato atual e as regras de domínio.

## Resultado

- Camadas da fase 1: status derivado pela regra documentada; filtro de status usa a mesma referência temporal passada pelo caso de uso; filtros aplicados antes de contar e paginar; ordenação determinística por `startsAt` decrescente e `id` crescente.
- Cancelamento: persiste `canceledAt` e `cancelReason`; rejeita registros já cancelados/expirados e usa atualização condicional ao snapshot para detectar alterações concorrentes.
- Integração HTTP da fase 2: pendente. A US-14 não implementou autenticação, identidade confiável ou middleware de perfil no backend. Portanto, não foi criada rota administrativa sem proteção, e os critérios HTTP (ADMIN/dono, ordenação real da rota, validação HTTP e testes Supertest) não estão concluídos.
- Contrato e mobile: não alterados nesta revisão.

## Verificações

Executadas no diretório `backend`:

| Comando | Resultado |
|---|---|
| `npm run lint` | passou |
| `npm run typecheck` | passou |
| `npm test` | passou — 11 arquivos, 127 testes |

A US-17 não deve ser considerada pronta para uso HTTP até a US-14 fornecer mecanismos reais de autenticação e perfil e a integração protegida receber seus testes de integração.
