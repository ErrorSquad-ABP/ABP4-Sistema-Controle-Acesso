# Estado atual e auditoria Trello × projeto — 02/11/2026 · board reconferido em 08/11/2026 · DT-16 mergeada em 09/11/2026

## Recorte e método

- Código local versionado: `66fe44a` (HEAD no início da auditoria). Os arquivos locais não rastreados não contam como entrega integrada.
- Conferência remota posterior, ainda em 02/11/2026: branch local `main`; após `git fetch origin`, `HEAD` e `origin/main` apontavam para `66fe44a`, com **0 commits à frente e 0 atrás** (`git rev-list --left-right --count HEAD...origin/main`). Não foi feito pull antes da auditoria; a conferência posterior confirmou que o código auditado coincidia com a `main` remota naquele momento. A documentação resultante foi separada na branch `fix/auditoria-documentacao`, sem incluir os arquivos locais anteriores à auditoria; nenhum push foi realizado nesta etapa.
- Fonte viva: [ERRORSQUAD ABP 4DSM](https://trello.com/b/AxZZyPyN/errorsquad-abp-4dsm), consultado autenticado em 02/11/2026 e reconferido em 08/11/2026. Foram lidos listas, descrições e checklists dos cards abertos, além dos comentários de US-14/21/22/32/37 e DT-10 para distinguir o escopo original do entregue.
- Cruzamento com rotas, casos de uso, schema/migrations, app, firmware, workflows, testes e evidências versionadas. Durante a auditoria original nenhum card foi movido, editado ou comentado.
- Reconferência de 08/11/2026: o board foi recontado (63 abertos, 43 concluídos), os cards **DT-23** e **DT-24** foram criados para rastrear as pendências de US-20/RF13 e DT-11, US-20/DT-11 receberam comentário e a descrição da DT-22 foi sincronizada. Em 09/11 a **DT-16 foi mergeada no PR #51**, levando o quadro a **44 concluídos e 19 abertos**. A auditoria de código continua no recorte de 02/11 (`66fe44a`).
- **Implementado** abaixo significa que há código e testes correspondentes no repositório; não certifica todos os itens da DoD (review de colega, configuração de secrets/proteção de branch e demonstração). Evidência histórica não é uma execução nova. Não foram acessados os painéis de GitHub, Neon ou Render nem repetidas as demonstrações Wokwi/Figma.

## Resumo

Atualização posterior ao recorte: a [DT-23](evidencias/dt-23.md) corrige localmente o teto da geofence. O diagnóstico abaixo permanece histórico; não descreve essa alteração como já implantada.

O projeto tem API com autenticação, usuários, autorizações, decisão QR, histórico, outbox e processamento MQTT; app com login/sessão e scanner local; firmware com display QR, servo e feedback. **Ainda não é um sistema completo demonstrado com app e terminal reais**: faltam envio QR pelo app, NFC/GPS no firmware, TLS no terminal e validação física.

| Lista no Trello | Cards (09/11/2026, pós-merge #51) |
|---|---:|
| Sprint 1 | 0 |
| Product Backlog | 9 |
| Sprint 2 | 1 |
| Dívida Técnica | 3 |
| Em review | 0 |
| Em andamento | 5 |
| Concluído | **44 (26 US + 18 DT)** |
| Bloqueado | 1 |
| **Total de cards abertos (não arquivados)** | **63 (39 US + 24 DT)** |

Esses 44 são o status declarado no quadro, **não 44 aceites integralmente comprovados**. Em 02/11 a distribuição era Sprint 2 = 4, Product Backlog = 11, Dívida Técnica = 1 e Em andamento = 0, com 61/43; em 08/11, com DT-23/DT-24, ficou 63/43; em 09/11, com a DT-16 mergeada no #51, ficou 63/44 (26 US + 18 DT). A Sprint 2 ainda está em curso (Review em 11/11); não há decisão observada que autorize declarar US-28/29 transferidas para S3.

## Divergências e ações recomendadas

| Card / assunto | Constatação | Ação recomendada ao time |
|---|---|---|
| [DT-11](https://trello.com/c/NPjUiiVS) | Concluído, mas `ci-backend`, `cd-backend`, `ci-firmware` e parte de `ci-mobile` usam tags mutáveis (`actions/checkout@v7`, `actions/setup-node@v7`, `subosito/flutter-action@v2` etc.). Não há configuração Dependabot versionada. Só parte das Actions do mobile está por SHA | Escopo restante rastreado na [DT-24](https://trello.com/c/pFJlVpZ0); o aceite “pinar SHAs revisados + Dependabot” não está atendido |
| [US-37](https://trello.com/c/AY5WYJa8) | Concluído, mas o próprio comentário de 27/10 diz que falta criar o serviço Render. Existem entry point, keep-alive e blueprint, não prova de MQTT persistente em produção | Separação “implementado × deploy validado” registrada em comentário de 08/11; URL/health e log de conexão ao broker continuam pendentes |
| [US-10](https://trello.com/c/wlc92VBv) | Checklist “Scanner QR lendo código real” completo; `evidencias/us-10-scanner.md` diz que câmera real não foi validada e DT-12 está bloqueada | Aceite físico vinculado à DT-12 em comentário de 08/11; o esqueleto entregue permanece válido |
| [US-22](https://trello.com/c/nsDhMYsD) | Renderização existe; comentário de 27/10 ainda registra demonstração visual Wokwi/hardware pendente. O worker só envia QR para terminais vistos `online`, e o firmware atual não publica status/heartbeat | Demonstração visual continua pendente; presença/status do terminal é a US-24. Registrado em comentário de 08/11, sem apresentar o E2E Node como prova do display |
| [US-14](https://trello.com/c/Azo9dR08) | Descrição mencionava login, refresh e logout. Comentário de 26/10 exclui refresh/logout do contrato v1; código oferece `POST /auth/login` e `GET /auth/me`. Logout no app apaga a sessão local, não revoga JWT no servidor | Descrição alinhada em 08/11: sem refresh/logout no servidor; logout local e expiração exigem novo login |
| [US-21](https://trello.com/c/0DggOIne) | Descrição prometia todas as tentativas; comentários fecham somente consulta. Hoje o backend também decide/registra QR e NFC simulado, mas o leitor NFC do ESP32 é vazio | Descrição alinhada em 08/11: consulta de histórico; leitura/publicação NFC física segue na US-23 |
| [US-16](https://trello.com/c/AaVJ4uOQ) / RF03 | `startsAt`/`endsAt` formam intervalo contínuo; não existe janela diária independente. Situação é calculada | Confirmar com PO/professor se o intervalo satisfaz “datas/horários”; registrar decisão, sem anunciar janela diária implementada |
| [US-20](https://trello.com/c/fUsL5phE) / RF13 | Geofence funciona com raio do local, default 100, **sem teto absoluto de 100 m**. Prova local: com `radiusMeters: 200`, uma posição a ~149,89 m foi autorizada pela política. A descrição `OUT_OF_RANGE` no schema REST ainda diz “mais de 100 m”, divergindo da configuração admitida pela regra | Correção rastreada na [DT-23](https://trello.com/c/FLCzZ6TX): limitar o raio a 100 m ou obter aceite explícito de outra regra. O título “≤100m” não é uma garantia para toda configuração; US-39 já pede que o cadastro não amplie esse limite |
| DT-22 | Ainda em Dívida Técnica; descrição dizia que não havia estratégia, mas `evidencias/dt-22.md` já registra decisão, estimativa e procedimento | Descrição sincronizada em 08/11/2026: estratégia documentada, medição de corrente/continuidade pendente (US-34). Não declarar consumo medido |

### Riscos operacionais associados

- `render.yaml` não declara `DATABASE_URL`, `QR_TOKEN_SECRET` nem `JWT_SECRET`. Configurá-los no painel é necessário: QR secret é obrigatório no carregamento de env; o modo real exige banco/schema; o worker e a API devem compartilhar a chave QR. O blueprint isolado não comprova um serviço funcional.
- `/healthz` sobe antes de inicializar o runtime e responde `status: ok`; um `200` isolado não prova assinatura MQTT nem publicação QR. Conferir também logs de inicialização/conexão e tráfego do terminal.
- A janela DT-21 limita **polling de recuperação**, não toda consulta ao Neon: boot, expurgos e tráfego normal ainda acessam o banco. Os custos documentados são estimativas, não medição de produção.
- DT-16 foi mergeada no PR #51 em 09/11. O PR implementa prazos server-side (lock 3 s, statement 3,5 s, idle 20 s), descarte de conexão em timeout do cliente e listener de `'error'` nas pools; a contenção é classificada como `busy` (warn), não erro. Continuam como limites documentados a validação no pooler do Neon e o cenário de callback travado dentro da transação de acesso.
- Dependências: `npm audit --json` reportou **11 entradas moderadas** na cadeia ESLint/TypeScript-ESLint, propagadas de `minimatch` ([GHSA-g3hv-75wg-m249](https://github.com/advisories/GHSA-g3hv-75wg-m249)). São entradas no relatório, não 11 falhas independentes. `npm audit --omit=dev --json` retornou **zero alertas**. Tratar na US-33; nenhum `audit fix`, downgrade sugerido ou atualização de manifesto/lockfile foi aplicado.

## Conferência de todos os cards em “Concluído”

Os caminhos nesta tabela são relativos à raiz do repositório. A coluna de conclusão descreve o alcance técnico, não altera o status do Trello.

| Card | Evidência no projeto | Conclusão da conferência |
|---|---|---|
| US-01 | Pastas do monorepo, `README.md`, `docs/guides/`, `.github/CODEOWNERS`, templates e `infra/docker-compose.dev.yml` | Estrutura implementada; proteção atual da branch e execução do compose não revalidadas |
| US-02 | `.github/workflows/ci-{backend,mobile,firmware}.yml`, `trello-link.yml`, badges | Automação implementada; vínculo exige secrets/vars. CI atual no GitHub não consultado |
| US-03 | `backend/src/{domain,application,infrastructure,main}`, `backend/Dockerfile`, `tests/integration/http.test.ts`, guia de caso de uso | Implementado |
| US-04 | `docs/architecture/contratos-mqtt.md`, `backend/src/main/{mqtt-consumer,sim-terminal}.ts`, `tests/unit/payload-parser.test.ts` | Implementado para simulação/local |
| US-05 | `backend/prisma/schema.prisma`, `migrations/`, `seed.ts`, modelo ER | Schema/migrations/seed implementados; aplicação de todas as migrations em produção não auditada |
| US-06 | `docs/api/openapi.yaml`, `backend/src/main/http/contract/`, `tests/unit/openapi-document.test.ts` | Contrato e geração implementados; rotas v1 originais já possuem implementação real |
| US-07 | `firmware/platformio.ini`, módulos, config exemplo, `wokwi/`, `evidencias/us-07-wokwi.md` | Esqueleto implementado; NFC/GPS presentes como arquivos não significam leitura funcional |
| US-08 | `firmware/src/modules/{door,feedback,display}.cpp`, testes host, `evidencias/us-08-wokwi.md` | Implementado, com evidência histórica simulada; não certifica montagem física |
| US-09 | `mobile/lib/core/{router,theme}`, `app.dart`, `mobile/test/` | Esqueleto implementado |
| US-10 | `mobile/lib/features/scanner/`, testes e `evidencias/us-10-scanner.md` | Esqueleto implementado; aceite de câmera real não comprovado (DT-12) |
| US-11 | `docs/scrum/`, backlog, DoD, sprints e templates | Documentos presentes; plano original preservado e estado atual corrigido nesta auditoria |
| US-12 | `design/README.md`, PNGs versionados em `design/figma/`, tema/Figtree no app | Assets presentes; aprovação visual/Figma vivo não revalidada; mockups não são telas implementadas |
| US-13 | `cd-backend.yml`, `backend/src/index.ts`, guia de deploy, `/health` público | Código de CD presente e API/banco observados; secrets e execução recente do workflow não auditados |
| US-14 | `backend/src/main/http/routes/auth.routes.ts`, `middlewares/auth.ts`, testes unitários/integrados de auth | Login/JWT/RBAC implementados; corte de refresh/logout documentado nos comentários, não na descrição |
| US-15 | `users.routes.ts`, casos de uso/repositórios e `tests/integration/users.test.ts` | CRUD admin implementado; exclusão lógica, não destruição do histórico |
| US-16 | `authorizations.routes.ts`, schemas e `tests/integration/authorizations.test.ts` | Criação implementada como intervalo contínuo; ressalva RF03 acima |
| US-17 | Mesmas rotas/testes de autorizações, filtros e cancelamento | Implementado na API, não na interface admin do app |
| US-18 | `GET /me/authorizations`, `tests/unit/list-my-authorizations.test.ts` | Implementado na API; tela continua US-28 |
| US-19 | `qr-credential.use-cases.ts`, `hmac-qr-token-signer.ts`, `tests/integration/credentials.test.ts` | Assinatura/validação e TTL de 10 s implementados |
| US-20 | `access-policy.ts`, `decide-access.use-case.ts`, testes de política/QR e `evidencias/us-20.md` | Decisão QR implementada; limite depende do raio cadastrado, sem teto absoluto (correção na DT-23) |
| US-21 | `access-events.routes.ts`, repositórios e caso de uso de decisão | Consulta implementada; gravação QR/NFC no backend, integração com leitor físico ainda pendente |
| US-22 | `firmware/src/modules/display.cpp`, `include/display_layout.h`, testes QR/display; `worker-runtime.ts` | Código de display implementado; demonstração visual e presença/status pendentes |
| US-26 | `firmware/tests/test_mqtt_command.cpp`, `door.cpp`, `evidencias/us-26-mqtt-servo.md` | Comando/expiração/dedup/servo implementados; herança da US-08 documentada |
| US-27 | `mobile/lib/features/auth/`, sessão/cofre/cliente autenticado, testes | Login real e persistência implementados; logout é local e expiração requer novo login |
| US-32 | `backend/tests/e2e/access.e2e.ts`, etapas E2E em CI/CD | Implementado com terminal Node, broker e banco temporários; não executa app Flutter, ESP32 ou câmera |
| US-37 | `backend/src/main/worker.ts`, `mqtt/keep-alive.ts`, `render.yaml` | Implementação presente; operação no Render não comprovada |
| DT-01 | `config/access-decider.ts`, `env.ts`, `worker-runtime.ts`, testes de segurança/E2E | Modo real padrão, demo proibido em produção e validação antes do broker implementados |
| DT-02 | `TerminalCommand`, `postgres-command-store.ts`, testes de ACK/restart/E2E | Registro persistente compartilhado implementado |
| DT-03 | `Terminal`, resolução do local e testes de terminal desconhecido/inativo | Mapeamento implementado; não é CRUD admin de locais (US-39) |
| DT-04 | Schema de evento com local nulo, contrato REST e teste de histórico | Implementado |
| DT-05 | `postgres-event-deduplicator.ts`, frescor no parser/decisão e testes E2E | Dedup persistente/rollback/replay implementados; espera limitada tratada na DT-16 (#51) |
| DT-07 | `backend/prisma/{seed,provision,provision-admin}.ts`, `tests/unit/seed-guard.test.ts`, CI | Proteções de seed/provisionamento implementadas |
| DT-09 | Etapa `db:migrate:deploy` antes do deploy em `cd-backend.yml`, rollback em `deploy.md` | Gate de migrations implementado; produção não migrada por esta auditoria |
| DT-10 | Build/artefato/install em `ci-mobile.yml`, scripts host e `evidencias/dt-10-build-android-ci.md` | Empacotamento/emulador com evidência histórica; câmera/GPS/aparelho físico não cobertos |
| DT-11 | `uses:` nos workflows e ausência de `.github/dependabot.*` | **Aceite não atendido**: pinagem apenas parcial, Dependabot ausente (correção na DT-24) |
| DT-13 | Outbox `publishedAt`, relay, testes de falha/restart e `evidencias/dt-13.md` | Recuperação implementada; respeita validade original e janela DT-21 |
| DT-14 | `config/connection-budget.ts`, composição separada e teste de rajada E2E | Orçamento por instância implementado/documentado; não é teto global nem medição no Neon |
| DT-15 | Expurgo de `ProcessedAccessMessage`, índice, agendamento, métricas no health e testes | Retenção implementada; execução real no Render não observada |
| DT-16 | Prazos server-side da reserva, descarte de conexão, listener de erro e classificação `busy`; testes de contenção em `tests/integration/postgres-event-deduplicator.test.ts` e `tests/unit/terminal-use-cases.test.ts`; evidência `dt-16.md` | Implementado no #51; coberto no CI com Postgres efêmero; pooler do Neon não observado |
| DT-17 | Consulta/lock de candidatas em `postgres-access-repository.ts`, testes e `evidencias/dt-17.md` | Implementado; plano/massa histórica registrados como evidência anterior |
| DT-18 | Expurgo de `TerminalCommand`, testes de retenção/ACK tardio e `evidencias/dt-18.md` | Implementado |
| DT-19 | Limite QR, `firmware/tests/test_{qr_token,display_qr}.cpp`, evidência | Capacidade implementada/testável no host; não equivale a câmera lendo TFT real |
| DT-20 | Respostas 429/503 nos schemas/operações/YAML e testes de contrato | Implementado |
| DT-21 | `relay-window.ts`, guard no runtime, testes de fuso/bordas e evidência | Janela implementada; custo real não medido |

## O que continua aberto

| Lista | Cards e situação verificada |
|---|---|
| Sprint 2 | **US-24** (GPS vazio/heartbeat pendente) |
| Product Backlog | **US-28** (sem tela de autorizações), **US-30/31** (sem admin/histórico completos no app), **US-33/34/35/36/38/39** (segurança final, hardware, diagramas finais, relatório, distribuição web e cadastro de locais) |
| Dívida Técnica | **DT-22** (estratégia documentada; sem medição de corrente/continuidade), **DT-23** (teto de 100 m na geofence), **DT-24** (pins por SHA + Dependabot) |
| Em andamento | **US-23** (leitor NFC vazio no firmware), **US-25** (retry básico, sem persistência local completa), **US-29** (scanner não chama o backend), **DT-06** (`WiFiClient`, sem TLS), **DT-08** (sem allowlist CORS no app Express) |
| Bloqueado | **DT-12**: câmera/GPS/aparelho reais não comprovados; o build Android no emulador não remove o bloqueio físico |

**DT-16 mergeada em 09/11 (#51):** os prazos da reserva e o tratamento de contenção estão implementados e cobertos no CI; a validação no pooler do Neon e o callback travado dentro da transação de acesso seguem como limites documentados em [`evidencias/dt-16.md`](evidencias/dt-16.md).

## Verificações desta auditoria

### Produção (somente leitura)

Em 02/11/2026, o primeiro GET ao health público retornou **503**; nova consulta às **19:02:27 UTC** respondeu **200**:

```json
{"status":"ok","version":"6b6aa26","uptimeSeconds":66,"timestamp":"2026-11-02T19:02:27.974Z","database":"ok"}
```

URL: <https://abp-4-sistema-controle-acesso.vercel.app/health>. A causa da primeira falha não foi diagnosticada. Isso comprova resposta da API/conectividade do banco naquele instante, não disponibilidade contínua, schema integral, fluxo de acesso ou worker Render. O HEAD local é posterior e contém documentação; não confundir `66fe44a` com a versão efetivamente publicada.

### Checagens locais

- Node local: `v24.22.0`.
- Primeira tentativa de `npm test` e `flutter test`: excederam 120 s, sem conclusão. Execuções com concorrência reduzida foram iniciadas em seguida.
- Backend antes de sincronizar dependências: `npm test -- --maxWorkers=1` obteve **285 testes passando, 31 ignorados e 11 suítes com falha de importação** (`jose`/`aedes` ausentes); `npm run typecheck` também acusou dependências ausentes e Prisma Client antigo (`terminal` inexistente no cliente gerado). São bloqueios do ambiente inicial, não evidência suficiente de defeito no código versionado.
- Mobile: `flutter test --no-pub --concurrency=1` concluiu com **93/93 testes passando**. São testes unitários/widgets, não câmera/GPS reais ou instalação física.
- Mobile: `flutter analyze --no-pub` concluiu **sem issues** (405,9 s).
- Preparação concluída: `npm ci` (450 pacotes) e `npm run db:generate` (Prisma Client 7.10.1). Manifestos/lockfile não foram alterados.
- Backend após preparação: `npm test -- --maxWorkers=1` → **357 passando, 31 ignorados; 41 arquivos passando e 8 ignorados**. As suítes condicionadas a `DATABASE_URL` não foram executadas nessa rodada; não contar os ignorados como aprovação.
- `npm run lint` e `npm run typecheck`: **aprovados** após preparação. Os erros iniciais de dependências/cliente gerado não se repetiram.
- `npm run test:e2e`: **build aprovado e 29/29 cenários E2E passando**, com PostgreSQL temporário, broker MQTT e processos API/worker locais separados (172,59 s). O diretório temporário foi direcionado para a pasta local de temporários. O E2E não usa o Flutter/ESP32 físicos nem comprova deploy no Render; não substitui todas as suítes de integração ignoradas acima.
- Firmware: PlatformIO/compilador host não localizados nos caminhos consultados. Build, testes C++ e Wokwi não repetidos; evidências anteriores mantidas como históricas.
- Prova isolada da regra de geofence executada com Node, importando `backend/src/domain/access/access-policy.ts`: contexto válido, local em `(-23, -45)`, `radiusMeters=200`, posição `(-22.998652, -45)` → `action: open`, `distanceMeters: 149.89076111687928`. Nenhum banco/terminal real foi usado ou alterado.
- Documentação: links locais dos 11 Markdown alterados/criados conferidos (nenhum destino ausente); tabela auditada contém exatamente 44 cards únicos após a DT-16. `git diff --check` sem problemas de whitespace.

### Reprodução da divergência de 100 m

Na pasta `backend`, executar com Node 24 (suporte a TypeScript sem build):

```javascript
// Salvar fora de src/ ou executar com node --input-type=module -e '<codigo>'.
import { decideAccess } from './src/domain/access/access-policy.ts';
const now = new Date('2026-11-02T12:00:00Z');
console.log(decideAccess({
  terminal: { id: 'audit', active: true, location: {
    id: 'local', name: 'Auditoria', active: true,
    latitude: -23, longitude: -45, radiusMeters: 200,
  } },
  user: { id: 'user', name: 'Auditoria', role: 'RESIDENT', active: true },
  authorizations: [{ id: 'auth', userId: 'user', locationId: 'local',
    startsAt: new Date('2026-11-01'), endsAt: new Date('2026-11-03'),
    maxUses: 1, usedCount: 0, canceledAt: null }],
  credentialValid: true, method: 'QR',
  position: { latitude: -22.998652, longitude: -45 }, now,
}));
```

## Próximos passos para aceite real

1. Executar DT-24 (pins/Dependabot) e DT-23 (teto de 100 m); alinhar descrições de US-14/21 e o aceite físico de US-10.
2. Fechar envio QR pelo app (US-29), TLS (DT-06) e presença/status do terminal; demonstrar QR renovando no TFT (US-22).
3. Validar deploy Render com banco/schema e secrets configurados, conexão MQTT e ACK correlacionado (US-37).
4. Implementar NFC/GPS e concluir DT-12/US-34 com aparelho e terminal reais; coletar medidas DT-22.
5. Refinar US-39 e a interpretação RF03; manter as demais telas/admin/entrega final explicitamente no backlog.
