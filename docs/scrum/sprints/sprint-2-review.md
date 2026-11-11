# Sprint 2 — Review (11/11, 19h30)

- **Participantes:** ErrorSquad (6) · Prof. Leandro Toss Hoffmann (banca)
- **Goal da sprint:** fluxo QR real ponta-a-ponta, admin na API e deploy seguro
- **Fechamento atualizado:** 11/11/2026 · **Commit de referência:** `a0625d7`
- **Histórias da S2:** **12/13 concluídas no quadro** — resta US-28; ressalva de comprovação em US-22
- **Antecipações da S3:** US-20, US-32, DT-23, DT-24 e software da US-23 (NFC integrado, card em review)

> Roteiro atualizado em 11/11, sem hardware disponível. Feedback do stakeholder e decisões devem ser preenchidos durante a review; não há aceite final presumido.

## Apresentação (10–15 min)

Material de apoio com 12 slides 16:9: [roteiro e capturas](../../entrega/apresentacao-sprint2/README.md). PDF e PPTX são gerados localmente com `python docs/entrega/apresentacao-sprint2/gerar.py` e não ficam versionados.

1. **Objetivo e incremento (1–2 min):** 12/13 no quadro, app integrado, limites do aceite físico.
2. **Funcionamento do app real (4 min):** login, sessão/Home, scanner e telas `GRANTED`/`DENIED` por posição dentro/fora de 100 m.
3. **Decisão e rastreabilidade (3 min):** eventos no banco, idempotência sem consumo extra, comandos/ACKs e NFC autorizado/desconhecido.
4. **Terminal, qualidade e operação (2–3 min):** NFC integrado, ACK adiado até `idle`, evidência física anterior, testes, API publicada e worker MQTT no Render conectado ao EMQX.
5. **Pendências e discussão (1–3 min):** US-28, bancada, heartbeat/GPS, offline e admin; registrar feedback sem antecipar decisões.

**O que as capturas provam:** PostgreSQL 17 isolado (`5448`), Mosquitto (`1888`), API Express (`3012`), worker separado e Flutter web (`5012`), com decisor real e sem alteração do produto. Chromium com câmera fake Y4M e geolocalização sintética alimentou o scanner real. Status `online`, terminal e ACKs são simulados, pois US-24 não envia heartbeat. O [JSON sanitizado](../../entrega/apresentacao-sprint2/capturas/execucao-local.json) registra decisões, eventos e correlações. Não comprova câmera/GPS físicos, ESP32 conectado nem atuação de servo; build web local não é US-38 publicada.

## Demos (por card)

| Card | O que mostrar | Evidência |
|---|---|---|
| US-14 | Login JWT, perfis e bloqueio de rota por perfil | `/auth/login`, `/auth/me`, testes de auth |
| US-15 | CRUD de usuários e proteção do último ADMIN | `/users`, PR #33 |
| US-16/17 | Criar, consultar e cancelar autorização; conflito `409` | `/authorizations`, PR #36 |
| US-18 | `GET /me/authorizations` com status e paginação | contrato em `/docs` |
| US-19 | Token QR `v1.<terminal>.<iat>.<ttl>.<hmac>` com 25 s | PR #27/#64, testes de credencial |
| US-20 | Pedido QR dentro e fora de 100 m, evento e comando | [evidência](../../entrega/evidencias/us-20.md), PR #42 |
| US-21 | Histórico de eventos com filtros e decisão gravada | PR #26 |
| US-22 | Código de renderização e evidência disponível; demonstração visual física pendente. Identificar status sintético `online` na demo | PR #26; não prometer display físico nesta review |
| US-23 | NFC RC522 integrado; decisão negativa/positiva e ACKs locais simulados; evidência física anterior com servo desligado | PR #67, [evidência](../../entrega/evidencias/us-23-nfc-rc522.md); revisão de 11/11 sem nova gravação |
| US-26 | Comando `open` e ACK do simulador; distinguir da atuação física e da evidência anterior do Wokwi | [evidência](../../entrega/evidencias/us-26-mqtt-servo.md) |
| US-27 | Login real, sessão persistida e logout local | PR #43 |
| US-29 | Scanner envia pedido autenticado e mostra liberação/negativa; posição sintética dentro/fora de 100 m | PR #55 integrado em 10/11, [evidência](../../entrega/evidencias/us-29.md) e capturas do app real |
| US-37 | Worker MQTT com outbox, dedup e relay | serviço `abp4-mqtt-worker` no ar desde 11/11, com `mqtt conectado`, assinatura e `/healthz` ok ([evidência](../../entrega/evidencias/us-37.md)) |
| DT-06 | TLS no ESP32 contra o EMQX e negativos de certificado | [evidência](../../entrega/evidencias/dt-06.md) |
| DT-23 | Migration e CHECK de 1–100 m em produção | [evidência](../../entrega/evidencias/dt-23.md) |
| DT-24 | Actions por SHA e Dependabot no repositório | [evidência](../../entrega/evidencias/dt-24.md) |

## O que não entra na entrega

- **US-28** (minhas autorizações no app) não foi iniciada; a API está pronta.
- **US-29 está integrada:** não falta envio nem resultado; falta validar câmera e GPS em aparelho real na US-34/DT-12.
- **US-22** tem código, sem demonstração visual física atual registrada.
- **US-37** está no ar no Render, conectado ao EMQX; falta o ciclo completo com terminal físico.
- **DT-12** e **DT-22** seguem bloqueadas por bancada (câmera/APK e medição de energia).
- **US-23:** software NFC integrado em 11/11 (`a0625d7`), mas card **Em review**. A evidência anterior correlaciona negativa/liberação/ACK com servo desligado; a correção `00ed519` do ACK QoS 1 adiado até `idle` passou em host/build, sem nova gravação física. ACK anterior comprova feedback, não abertura.
- GPS/heartbeat (US-24), resiliência offline (US-25), telas de admin (US-30/31), demo web publicada (US-38) e diagramas seguem pendentes.

## Conferência do fechamento

- **Trello em 11/11, consulta completa:** 63 cards; **49 em listas concluídas (27 US + 22 DT) + 1 em review (US-23)**, 1 em andamento (US-25), 10 na Sprint 3 e 2 bloqueados. A flag `complete` da US-23 não a move para Concluído.
- **Integrações:** PR #68 Supertest (`4152809`) e PR #67 NFC (`a0625d7`), com 6 checks verdes; nenhum PR aberto na consulta. US-29 (#55) e QR de 25 s (#64) já integrados em 10/11.
- **Qualidade em 11/11:** backend CI com PostgreSQL/seed **460/460** em 53 arquivos; local padrão **420 aprovados/40 condicionais a banco pulados**; E2E **31/31**. Mobile: analyze limpo, **215/215** e build web aprovado. Firmware: suíte host completa, incluindo 8 cenários de timing (3 fases + PUBACK, TLS 0/1), e builds físico/Wokwi/TLS/OLED aprovados.
- **Operação:** API pública `version: a0625d7`, `database: ok`; CD backend, CI backend, firmware e CodeQL aprovados. Worker MQTT no Render `live`, com `mqtt conectado` ao EMQX e `/healthz` ok. Links das execuções no [documento de entrega](../../entrega/review-2.md#6-qualidade-e-reprodução-da-demo) e no [registro da US-37](../../entrega/evidencias/us-37.md).

> **Histórico de 10/11 (`1afd624`):** o corte intermediário registrava 11/13, US-28/29 como carry-over, 48/63 cards e 28 PRs. Esses números não substituem o estado atualizado da review de 11/11.

## Feedback do stakeholder (professores/focal point)

- _Preencher durante a review._

## Ações (o que vira card no backlog)

- _Preencher durante a review. Candidatos já mapeados na retro:_
  - implementar US-28 e validar câmera/GPS físicos da US-29 já integrada;
  - concentrar a bancada da US-34 para DT-12, DT-22, revisão NFC e GPS, sem presumir aceite;
  - comprovar o deploy do worker no Render (US-37);
  - registrar demonstração visual do QR (US-22).

## Links

- Repo: https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso
- Board: https://trello.com/b/AxZZyPyN/errorsquad-abp-4dsm
- Documento de entrega: [`../../entrega/review-2.md`](../../entrega/review-2.md)
