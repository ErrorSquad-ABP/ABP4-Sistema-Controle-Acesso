# Matriz de requisitos — Desafio 4DSM 2026-2

Fonte dos requisitos: leitura anteriormente registrada de `Desafio 4DSM - 2026-2.pdf` (versão 31/08/2026, FATEC Jacareí). Estado do projeto revisto em **02/11/2026**, código local `66fe44a`, contra o Trello e as evidências versionadas; o PDF não foi relido nesta rodada. Conferência por card e limites de validação em [`auditoria-estado-atual.md`](auditoria-estado-atual.md).

Status: **Atendido** · **Parcial** (parte comprovada) · **Não atendido** · **Não comprovado** (não há evidência no repo).

## Requisitos funcionais

| ID | Requisito | Status | Evidência / lacuna |
|---|---|---|---|
| RF01 | Cadastro de usuários com perfis administrador, condômino e visitante | Atendido | `backend/prisma/schema.prisma` (`UserRole`: `ADMIN`, `RESIDENT`, `VISITOR`); CRUD admin em `POST/PATCH /users` (US-15, #33) |
| RF02 | Cadastro de local de acesso (edifício, portaria, porta, catraca) | **Não atendido** | `AccessLocation` existe no schema e no seed, mas **não há endpoint nem tela** para cadastrar/editar local |
| RF03 | Criação de autorização (pessoa, local, data início/fim, horário inicial/final, usos, situação) | Parcial | US-16 (#36): pessoa, local, `startsAt`/`endsAt` (data+hora), `maxUses`; situação é derivada (ACTIVE/SCHEDULED/EXPIRED/CANCELED). **Não há janela diária** de horário — é um intervalo contínuo |
| RF04 | Consulta de autorizações com filtros | Atendido | US-17 (#36): usuário, local, período, status e paginação em `GET /authorizations` |
| RF05 | Cancelamento de autorização | Atendido | `POST /authorizations/{id}/cancel` com motivo e 409 para já cancelada/expirada (#36) |
| RF06 | Histórico de acessos | Parcial | Leitura em `GET /access-events` e `GET /me/access-events` (#26); gravação do fluxo QR (#42). Telas de histórico no app são US-31 (S3) |
| RF07 | Autenticação do usuário no app | Atendido | `POST /auth/login` (US-14, #26) + sessão persistida no app (US-27, #43) |
| RF08 | Usuário vê suas autorizações no app | Parcial | API `GET /me/authorizations` pronta (US-18, #33); tela é a **US-28**, sem PR |
| RF09 | Leitura de QR Code pelo app | Parcial | Scanner (US-10, #20) e envio da leitura com posição e `requestId` ao backend, com tela de resultado liberado/negado (US-29, [`us-29.md`](evidencias/us-29.md)); testado no `flutter test` e contra o backend real. **Leitura com câmera e GPS de aparelho real não foi executada** (US-34) |
| RF10 | Leitura de NFC pelo terminal | **Não atendido** | `firmware/src/modules/nfc.cpp` é esqueleto ("leitura desabilitada"); US-23 está em Em andamento (plano original S3) |
| RF11 | Terminal com processamento, rede, tela, NFC, sinalização, GPS e abertura | Parcial | Tela, servo, LED, buzzer e MQTT (US-07/08/22); `gps.cpp` e `nfc.cpp` são esqueletos; GPS é US-24 (S3) |
| RF12 | QR gerado no backend e trocado a cada 10 s | Atendido | Backend gera e rotaciona a cada 10 s (US-19, #27) e o worker publica no timer (US-22, #26). A entrega/exibição no TFT depende de presença/status do terminal (US-24, RF11), que é outra lacuna |
| RF13 | Validação QR: autenticidade, validade, local, situação, usos e geofence de 100 m | Parcial | Decisão implementada (DT-01/02/03 #32; US-20 #42), mas usa `location.radiusMeters`, default 100, **sem teto absoluto**: auditoria autorizou ~149,89 m com raio 200 (correção na DT-23). O app já chama o endpoint (US-29), com resultado liberado/negado por motivo, conferido contra o backend real (liberado, fora do alcance, QR vencido, assinatura falsa, terminal desconhecido); a abertura física pelo terminal depende do hardware (US-34) |
| RF14 | Validação NFC pelo backend | Parcial | `DecideAccessUseCase` resolve UID/local, valida credencial/autorização e registra decisão; cenário NFC no E2E simulado. Falta o leitor/publicação real do terminal (US-23); não é ausência de regra NFC no backend |
| RF15 | Liberação do acesso (mecanismo físico ou simulado) | Atendido | Comando `open` via MQTT aciona o servo (US-08 #19, US-26) |
| RF16 | Negação com indicação visual/sonora | Atendido | Feedback `deny` no firmware (LED/buzzer/LCD) |
| RF17 | Registro de toda tentativa de acesso | Parcial | Backend grava decisões QR e NFC simulado (`decide-access.use-case.ts`, E2E); leitor do ESP32 ainda não gera tentativa (RF10). Rejeições de transporte/autenticação/formato não equivalem a eventos de decisão registrados |

## Requisitos não funcionais

| ID | Requisito | Status | Evidência / lacuna |
|---|---|---|---|
| RNF01 | Dispositivo IoT + backend Node/TS + API REST + app móvel | Atendido | Monorepo `firmware/`, `backend/`, `mobile/` |
| RNF02 | Autenticação, proteção de dados e comunicação segura | Parcial | JWT, rate limit, HTTPS na Vercel, Keystore no app, broker de produção com TLS; **firmware sem TLS** (DT-06) |
| RNF03 | Funcionamento com retry/persistência sob falha de conexão | Parcial | Outbox de comandos com retry (DT-13, #37); resiliência do firmware (US-25, alvo S3) em andamento |
| RNF04 | Interface simples, acessível ao público idoso | Parcial | Fonte 2x sem estouro e rótulos acessíveis (US-27, #43); telas de admin com acessibilidade são US-31 (S3) |
| RNF05 | Modularidade e separação de responsabilidades | Atendido | Clean Architecture com regra de camadas verificada no lint (`backend/src/{domain,application,infrastructure,main}`) |
| RNF06 | Banco de dados em nuvem | Atendido | Postgres no Neon; `/health` com `database: ok` |
| RNF07 | Eficiência energética do dispositivo | Parcial | Terminal alimentado pela rede e sem deep sleep por causa do QR de 10 s (RF12); QR só é redesenhado quando o token muda e LEDs/buzzer só ligam no feedback — mecanismos verificáveis no firmware. Falta a medição de corrente e o teste de continuidade ([`evidencias/dt-22.md`](evidencias/dt-22.md), US-34) |
| RNF08 | CI com build, testes e lint | Parcial | Workflows backend (lint/test/build), mobile (analyze/test/APK) e firmware (testes host/build com `-Werror`) presentes. O firmware não tem lint estático dedicado de todos os fontes; o CodeQL roda por default setup, sem workflow versionado, mas não é requisito do RNF08. Checks obrigatórios atuais não revalidados |
| RNF09 | CD automatizado | Atendido | `cd-backend` publica na Vercel após CI; smoke em `/health` |
| RNF10 | Testes automatizados no pipeline | Atendido | Vitest (backend, incl. e2e com Postgres embarcado), Flutter test, testes host do firmware |
| RNF11 | Git com branches, commits descritivos e estratégia | Atendido | Histórico de branches/commits por card e estratégia documentada; proteção atual da `main` não revalidada nesta auditoria |
| RNF12 | Feedback de build/deploy | Atendido | GitHub Actions com checks por etapa |

## Restrições de projeto

| ID | Restrição | Status | Evidência / lacuna |
|---|---|---|---|
| RP01 | Node.js + Express + TypeScript | Atendido | `backend/package.json` (Node 24, Express 5, TS) |
| RP02 | Integração com dispositivo físico (tela, sensores, atuadores) | Parcial | Wokwi com display, servo, LED, buzzer; NFC e GPS são esqueletos (RF11) |
| RP03 | Protocolo IoT (HTTP ou MQTT) | Atendido | MQTT v1 documentado e implementado |
| RP04 | Aplicativo móvel (nativo ou híbrido) | Atendido | Flutter (Android como alvo principal) |
| RP05 | Arquitetura cliente-servidor | Atendido | App, API, worker e terminal com papéis separados |
| RP06 | Desenvolvimento incremental por sprint | Atendido | S1 13/13 e S2 com entregas parciais registradas |
| RP07 | Documentação de arquitetura, diagramas e comunicação | Parcial | `docs/architecture/` com visão geral, contratos MQTT, modelo de dados e ADR; falta diagrama de casos de uso |
| RP08 | Escopo viável, com simulações | Atendido | Wokwi e simulador Node |
| RP09 | Pipeline CI/CD | Atendido | GitHub Actions |
| RP10 | Testes no pipeline (obrigatório) | Atendido | RNF10 |
| RP11 | Deploy automatizado do backend em nuvem | Atendido | Vercel + Neon; `/health` público |
| RP12 | Conteinerização | Parcial | `backend/Dockerfile` e `docker-compose.dev.yml` (Mosquitto + Postgres); app e firmware não são containerizados (esperado) |

## Lacunas por prioridade (Review 2 em 11/11)

1. **RF09 + RF13 (app)**: o app já pede o acesso e mostra o resultado (US-29); falta validar câmera e GPS em aparelho real e a demonstração ponta-a-ponta com o terminal (US-34).
2. **RF08**: tela "minhas autorizações" — US-28 sem PR.
3. **RF02**: cadastro de local não existe em API nem tela.
4. **RF10/RF11/RF14**: NFC e GPS do terminal (US-23 em Em andamento; US-24 na lista Sprint 2). Backend NFC já existe para simulação.
5. **RF17**: registrar tentativa NFC depende de US-23.
6. **RNF02**: TLS no firmware (DT-06) para falar com o broker de produção.
7. **RNF07**: estratégia e orçamento documentados em [`evidencias/dt-22.md`](evidencias/dt-22.md); falta medir corrente no hardware (US-34).
8. **RF03**: confirmar com o professor/PO se "horário inicial/final" exige janela diária dentro do período — hoje é um intervalo contínuo.
9. **RF13**: impor teto de 100 m na regra/configuração; o default no schema não impede autorização além do limite quando o raio é maior. Correção rastreada na DT-23.

Pendências transversais: DT-11 em Concluído sem pinagem completa por SHA/Dependabot (correção na DT-24); deploy Render da US-37 não comprovado; demonstração visual do QR da US-22 e câmera real da US-10/DT-12 ainda pendentes. API respondeu com banco ok em 02/11 (versão `6b6aa26`), após uma primeira resposta 503; não é prova de operação contínua nem de fluxo físico completo.

## Leitura do edital sobre "admin"

O documento descreve **dois** componentes (pág. 1): Terminal de Acesso e Aplicação Móvel. A aplicação móvel é "utilizada pelos usuários para consultar autorizações e efetuar a leitura do QR Code" e "**também é utilizado para administração do sistema e gerenciamento das autorizações**". Ou seja:

- **Admin foi pedido** — como função da aplicação móvel (RF03/04/05 + esse parágrafo), coberto por US-15/16/17 na API e US-30/31 no app (S3).
- **Não há requisito de painel web administrativo.** "Sistemas web" aparece só na frase genérica do desafio; a lista de componentes não inclui frontend web. A demo web (US-38) é entrega adicional do time.
