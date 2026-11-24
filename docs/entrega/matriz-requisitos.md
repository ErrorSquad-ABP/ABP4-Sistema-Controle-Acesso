# Matriz de requisitos — Desafio 4DSM 2026-2

Fonte dos requisitos: leitura anteriormente registrada de `Desafio 4DSM - 2026-2.pdf` (versão 31/08/2026, FATEC Jacareí). Estado do projeto revisto em **02/11/2026**, código local `66fe44a`, contra o Trello e as evidências versionadas; **atualizado em 11/11/2026** com o app e a operação; **atualizado em 24/11/2026** com o fechamento da Sprint 3, o fluxo físico em bancada e a entrega final. O PDF do edital não foi relido nesta rodada. Conferência por card e limites de validação em [`auditoria-estado-atual.md`](auditoria-estado-atual.md); o retrato final está em [`review-3.md`](review-3.md) e no [`relatorio-abnt.pdf`](relatorio/relatorio-abnt.pdf).

Status: **Atendido** · **Parcial** (parte comprovada) · **Não atendido** · **Não comprovado** (não há evidência no repo).

## Requisitos funcionais

| ID | Requisito | Status | Evidência / lacuna |
|---|---|---|---|
| RF01 | Cadastro de usuários com perfis administrador, condômino e visitante | Atendido | `backend/prisma/schema.prisma` (`UserRole`: `ADMIN`, `RESIDENT`, `VISITOR`); CRUD admin em `POST/PATCH /users` (US-15, #33) |
| RF02 | Cadastro de local de acesso (edifício, portaria, porta, catraca) | Atendido | `GET /api/v1/locations` (autenticado, ativos, paginado) e `POST /api/v1/locations` (ADMIN, raio 1–100 m), com tela de locais e novo local (US-39). Cadastro real ("Portaria", 100 m) conferido no PostgreSQL em 11/11 ([`us-29-aparelho.md`](evidencias/us-29-aparelho.md)); não há edição/desativação nesta entrega |
| RF03 | Criação de autorização (pessoa, local, data início/fim, horário inicial/final, usos, situação) | Parcial | US-16 (#36): pessoa, local, `startsAt`/`endsAt` (data+hora), `maxUses`; situação é derivada (ACTIVE/SCHEDULED/EXPIRED/CANCELED). **Não há janela diária** de horário — é um intervalo contínuo |
| RF04 | Consulta de autorizações com filtros | Atendido | US-17 (#36): usuário, local, período, status e paginação em `GET /authorizations` |
| RF05 | Cancelamento de autorização | Atendido | `POST /authorizations/{id}/cancel` com motivo e 409 para já cancelada/expirada (#36) |
| RF06 | Histórico de acessos | Atendido | Leitura em `GET /access-events` e `GET /me/access-events` (#26); gravação do fluxo QR (#42) e NFC real (US-23, #67). Aba Histórico e histórico de acessos no app (US-31) |
| RF07 | Autenticação do usuário no app | Atendido | `POST /auth/login` (US-14, #26) + sessão persistida no app (US-27, #43) |
| RF08 | Usuário vê suas autorizações no app | Atendido | API `GET /me/authorizations` (US-18, #33) e tela "Minhas autorizações" com detalhe (US-28), executada em aparelho em 11/11 ([`us-29-aparelho.md`](evidencias/us-29-aparelho.md)) |
| RF09 | Leitura de QR Code pelo app | Atendido | Scanner (US-10, #20) envia a leitura com posição e `requestId` e mostra resultado liberado/negado (US-29, #55). Leitura com câmera e pedido ao backend observados em aparelho em 11/11 ([`us-29-aparelho.md`](evidencias/us-29-aparelho.md)); sem medição de precisão do GPS e sem terminal físico no fluxo |
| RF10 | Leitura de NFC pelo terminal | Atendido | RC522 SPI integrado (US-23, #67): leitura, publicação MQTT, decisão no backend e feedback; evidência física inicial com RC522 e MQTT observados na placa. O servo estava desabilitado nesse perfil e a abertura física não está implementada |
| RF11 | Terminal com processamento, rede, tela, NFC, sinalização, GPS e abertura | Parcial | Tela, servo (simulado), LED, buzzer, MQTT, NFC e heartbeat/status (US-07/08/22/23/24); `gps.cpp` é esqueleto e o módulo NEO-6M não está disponível, então o terminal não publica GPS; a abertura física da cancela não está implementada |
| RF12 | QR gerado no backend e trocado a cada 25 s | Atendido | Backend gera e rotaciona a cada 25 s, com renovação a cada 20 s (US-19, #27; TTL alterado no #64 em 10/11) e o worker publica no timer (US-22, #26). A entrega no hardware real passa a depender de presença por heartbeat (US-24), implementado no firmware |
| RF13 | Validação QR: autenticidade, validade, local, situação, usos e geofence de 100 m | Atendido | Decisão implementada (DT-01/02/03 #32; US-20 #42); DT-23 impõe teto de 100 m na política e CHECK de 1–100 m no banco, implantada em 10/11 ([evidência](evidencias/dt-23.md)). O app envia o pedido (US-29) e a leitura foi observada em aparelho; a abertura física não foi demonstrada |
| RF14 | Validação NFC pelo backend | Atendido | `DecideAccessUseCase` resolve UID/local, valida credencial/autorização e registra decisão; o RC522 real publica o UID e o fluxo foi exercitado com tag desconhecida e autorizada (US-23, #67). O servo não foi acionado nessa bancada |
| RF15 | Liberação do acesso (mecanismo físico ou simulado) | Atendido | Comando `open` via MQTT aciona o servo (US-08 #19, US-26) |
| RF16 | Negação com indicação visual/sonora | Atendido | Feedback `deny` no firmware (LED/buzzer/LCD) |
| RF17 | Registro de toda tentativa de acesso | Atendido | Backend grava decisões QR e NFC real (US-23), com evento, motivo e comando; histórico consultável (RF06). Falhas de transporte/autenticação/formato não são eventos de decisão |

## Requisitos não funcionais

| ID | Requisito | Status | Evidência / lacuna |
|---|---|---|---|
| RNF01 | Dispositivo IoT + backend Node/TS + API REST + app móvel | Atendido | Monorepo `firmware/`, `backend/`, `mobile/` |
| RNF02 | Autenticação, proteção de dados e comunicação segura | Parcial | JWT, rate limit, HTTPS na Vercel, Keystore no app e TLS do firmware validado no ESP32 ([DT-06](evidencias/dt-06.md)). A [revisão US-33](evidencias/us-33.md) registra o que foi verificado e os riscos que ainda aguardam aceite. |
| RNF03 | Funcionamento com retry/persistência sob falha de conexão | Parcial | Outbox de comandos com retry (DT-13, #37); resiliência do firmware (US-25) pendente, sem retry offline persistente |
| RNF04 | Interface simples, acessível ao público idoso | Parcial | Fonte 2x sem estouro e rótulos acessíveis (US-27); telas de administração e histórico entregues (US-31), mas sem auditoria de acessibilidade registrada nessas telas |
| RNF05 | Modularidade e separação de responsabilidades | Atendido | Clean Architecture com regra de camadas verificada no lint (`backend/src/{domain,application,infrastructure,main}`) |
| RNF06 | Banco de dados em nuvem | Atendido | Postgres no Neon; `/health` com `database: ok` |
| RNF07 | Eficiência energética do dispositivo | Parcial | Projeto documentado (terminal na fonte, sem deep sleep), mecanismos verificáveis (QR só redesenha na troca do token; LEDs/buzzer só no feedback) e orçamento estimado em faixa, com incerteza declarada ([`dt-22.md`](evidencias/dt-22.md)). Consumo não medido e continuidade de 24 h não cronometrada |
| RNF08 | CI com build, testes e lint | Parcial | Workflows backend (lint/test/build), mobile (analyze/test/APK) e firmware (testes host/build com `-Werror`) presentes. O firmware não tem lint estático dedicado de todos os fontes; o CodeQL roda por default setup. Os seis checks obrigatórios e o CodeQL estavam verdes em 24/11/2026 |
| RNF09 | CD automatizado | Atendido | `cd-backend` publica na Vercel após CI; `cd-web` publica a demo com smoke test; smoke em `/health` |
| RNF10 | Testes automatizados no pipeline | Atendido | Vitest (backend, incl. e2e com Postgres embarcado), Flutter test, testes host do firmware |
| RNF11 | Git com branches, commits descritivos e estratégia | Atendido | Histórico de branches/commits por card e estratégia documentada; proteção atual da `main` não revalidada nesta auditoria |
| RNF12 | Feedback de build/deploy | Atendido | GitHub Actions com checks por etapa |

## Restrições de projeto

| ID | Restrição | Status | Evidência / lacuna |
|---|---|---|---|
| RP01 | Node.js + Express + TypeScript | Atendido | `backend/package.json` (Node 24, Express 5, TS) |
| RP02 | Integração com dispositivo físico (tela, sensores, atuadores) | Parcial | Wokwi com display, servo, LED e buzzer; NFC RC522 real (US-23) com evidência física; QR, tag e HCE exercitados na bancada. GPS ficou fora do escopo (módulo indisponível) e a abertura física de uma cancela não está implementada |
| RP03 | Protocolo IoT (HTTP ou MQTT) | Atendido | MQTT v1 documentado e implementado |
| RP04 | Aplicativo móvel (nativo ou híbrido) | Atendido | Flutter (Android como alvo principal) |
| RP05 | Arquitetura cliente-servidor | Atendido | App, API, worker e terminal com papéis separados |
| RP06 | Desenvolvimento incremental por sprint | Atendido | S1 13/13 e S2 com entregas parciais registradas |
| RP07 | Documentação de arquitetura, diagramas e comunicação | Atendido | `docs/architecture/` em Mermaid: [casos de uso](../architecture/casos-de-uso.md), [componentes e implantação dev/prod](../architecture/componentes-implantacao.md), [sequências QR/NFC](../architecture/sequencias.md), modelo de dados, contratos MQTT e ADR, ligados a partir da [visão geral](../architecture/visao-geral.md) (US-35, [evidência](evidencias/us-35.md)) |
| RP08 | Escopo viável, com simulações | Atendido | Wokwi e simulador Node |
| RP09 | Pipeline CI/CD | Atendido | GitHub Actions |
| RP10 | Testes no pipeline (obrigatório) | Atendido | RNF10 |
| RP11 | Deploy automatizado do backend em nuvem | Atendido | Vercel + Neon; `/health` público |
| RP12 | Conteinerização | Parcial | `backend/Dockerfile` e `docker-compose.dev.yml` (Mosquitto + Postgres); app e firmware não são containerizados (esperado) |

## Lacunas por prioridade (estado de 24/11/2026)

1. **RF09 + RF13 (app)**: o app já pede o acesso e mostra o resultado (US-29); falta validar câmera e GPS em aparelho real e a demonstração ponta-a-ponta com o terminal (US-34).
2. **RF08**: tela "minhas autorizações" — US-28 sem PR.
3. **RF02**: cadastro de local não existe em API nem tela.
4. **RF10/RF11/RF14**: NFC e GPS do terminal (US-23 em Em andamento; US-24 na lista Sprint 2). Backend NFC já existe para simulação.
5. **RF17**: registrar tentativa NFC depende de US-23.
6. **RNF02**: a [US-33](evidencias/us-33.md) revisou o repositório. Ainda faltam a validação de headers e CORS no ambiente hospedado, a conclusão da auditoria de dependências e o aceite formal dos riscos registrados. A rotação de segredos registrada em 11/11 não foi revalidada.
7. **RNF07**: estratégia e orçamento documentados em [`evidencias/dt-22.md`](evidencias/dt-22.md); falta medir corrente no hardware (US-34).
8. **RF03**: confirmar com o professor/PO se "horário inicial/final" exige janela diária dentro do período — hoje é um intervalo contínuo.
9. **RF13**: teto de 100 m implantado em produção em 10/11 (#56): migration aplicada, CHECK de 1–100 m confirmada e pré-check sem cadastros inválidos. Falta a US-39 validar o intervalo no cadastro.
1. **Fluxo físico (US-34)**: servo/cancela não implementado; o fluxo app → terminal real não foi demonstrado. O QR foi lido de um monitor e o NFC físico não acionou servo ([`us-29-aparelho.md`](evidencias/us-29-aparelho.md)).
2. **RF11/US-24/US-25**: GPS e heartbeat/status do terminal continuam pendentes; a resiliência offline (retry persistente) também.
4. **RNF07**: estratégia e orçamento documentados em [`evidencias/dt-22.md`](evidencias/dt-22.md); falta medir corrente no hardware (US-34).
5. **RF03**: confirmar com o professor/PO se "horário inicial/final" exige janela diária dentro do período — hoje é um intervalo contínuo.
6. **RNF04**: telas de administração e histórico entregues, sem auditoria de acessibilidade registrada.
7. **RNF08/RNF11**: os seis checks obrigatórios e o CodeQL estavam verdes em 24/11/2026; a proteção da `main` exige uma aprovação e os seis contextos.
8. **Entrega final**: o relatório ABNT, as mídias e o roteiro entraram em 24/11/2026; o PDF está versionado. A apresentação em si e a revisão por pares do relatório dependem da cerimônia. O APK de release em loja não entrou (a execução usou APK debug).

Pendências transversais: o worker no Render foi observado **LIVE** em 11/11, com `mqtt conectado` no EMQX TLS e `/healthz` ok, mas sem medição de continuidade ([`us-37.md`](evidencias/us-37.md)); DT-11 foi fechada pela DT-24, com pinagem por SHA e Dependabot integrados em 10/11 (#56) ([evidência](evidencias/dt-24.md)). A API respondeu com banco ok em 02/11 (versão `6b6aa26`), após uma primeira resposta 503, e em 11/11 (`a0625d7`); isso não é prova de operação contínua nem de fluxo físico completo.

## Leitura do edital sobre "admin"

O documento descreve **dois** componentes (pág. 1): Terminal de Acesso e Aplicação Móvel. A aplicação móvel é "utilizada pelos usuários para consultar autorizações e efetuar a leitura do QR Code" e "**também é utilizado para administração do sistema e gerenciamento das autorizações**". Ou seja:

- **Admin foi pedido** — como função da aplicação móvel (RF03/04/05 + esse parágrafo), coberto por US-15/16/17 na API e US-30/31 no app (S3).
- **Não há requisito de painel web administrativo.** "Sistemas web" aparece só na frase genérica do desafio; a lista de componentes não inclui frontend web. A demo web (US-38) é entrega adicional do time.
