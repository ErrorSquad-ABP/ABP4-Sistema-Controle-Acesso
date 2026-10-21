# Review 1 — Documento de entrega · Sprint 1

## 1. Identificação, equipe e links

- **Curso:** Desenvolvimento de Software Multiplataforma (4DSM) — FATEC Jacareí.
- **Projeto:** ABP 2026-2 · Sistema Integrado de Controle de Acesso.
- **Equipe:** ErrorSquad — João Victor Lopes Rosa (SM), Felipe Pacheco (PO), Carlos Santo, Caio Araujo, Leo Silva e Arthur Facchinetti.
- **Sprint 1:** 15 a 21/10/2026 · **Review:** 21/10/2026, 19h30.
- **Referência da entrega:** branch `main`, commit `18d9fe7`.

| Referência | Link |
|---|---|
| Repositório | [ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso) |
| Board | [ErrorSquad ABP 4DSM](https://trello.com/b/AxZZyPyN/errorsquad-abp-4dsm) |
| Design | [Figma](https://www.figma.com/design/nddGhlwJIi5rMzhvsK5Rkl) |
| API publicada | [/health](https://abp-4-sistema-controle-acesso.vercel.app/health) |

## 2. Objetivo e resultado

**Objetivo:** “Fundação no ar + esqueleto conversando ponta-a-ponta, simulado”.

A sprint entregou a estrutura do projeto, contratos REST/MQTT, modelo de dados, automação de qualidade, API publicada e esqueletos de app e terminal. Foram concluídos **11 dos 13 cards**. US-08 e US-10 não atendem ao aceite completo e seguem para a S2.

**O resultado é uma fundação demonstrável, não um controle de acesso operacional:** não há autenticação real, leitura QR/NFC, geofence ou abertura física integrada.

| Indicador | Resultado no fechamento |
|---|---|
| Cards concluídos | 11/13 — aproximadamente 85% por contagem de cards |
| PRs mergeados até `18d9fe7` | 14 — #2 a #15; inclui os dois PRs de documentação do fechamento |
| Testes de backend | 122 passando |
| Testes de mobile | 12 passando |
| Firmware | Build PlatformIO, testes host e demo Wokwi→Mosquitto registrados |
| Integração contínua | 4 checks obrigatórios: backend, backend-docker, mobile e firmware; CodeQL adicional |
| Proteção da `main` | 1 aprovação obrigatória |
| Deploy registrado | API Vercel, Neon com `database: ok`, versão `d5a0ac0` |
| Design | 23 PNGs exportados |

A S1 não teve estimativa registrada; esses números não representam velocidade por pontos. Os resultados de testes são os registrados no fechamento, não uma nova execução deste documento.

## 3. O que está no ar

- **API na Vercel:** `/health` público com conectividade ao Neon. A versão publicada `d5a0ac0` é distinta do commit de referência do repositório.
- **Contrato REST:** [Swagger UI](https://abp-4-sistema-controle-acesso.vercel.app/docs) e [OpenAPI JSON](https://abp-4-sistema-controle-acesso.vercel.app/openapi.json). As rotas de negócio validam a entrada e retornam `501 NOT_IMPLEMENTED`.
- **MQTT:** consumidor e simulador executados localmente; worker no Render permanece previsto para a S2.
- **Mobile:** executado localmente, sem publicação. O login valida campos, mostra carregamento e termina no aviso de indisponibilidade; não autentica nem cria sessão.
- **Firmware:** executado no Wokwi, conectando ao Mosquitto local. Recebe a mensagem, registra tópico/tamanho na serial e a descarta, sem parser v1, atuação ou ACK.

## 4. Entregas por card

Os 11 cards abaixo foram concluídos. US-10 aparece apenas como entrega parcial na seção 6.

| Card | Entrega efetiva | Evidência no repositório |
|---|---|---|
| US-01 | Monorepo, guias, templates, `CODEOWNERS` e compose Mosquitto/Postgres | [`README`](../../README.md), [`infra/`](../../infra/), [`.github/`](../../.github/) |
| US-02 | CI das três stacks e vínculo automático Trello↔PR | [Workflows](../../.github/workflows/), PR #3 |
| US-03 | Backend em camadas, ambiente validado, healthcheck, erros e Dockerfile | [`backend/src/`](../../backend/src/), [guia de extensão](../architecture/caso-de-uso-modelo.md), PR #2 |
| US-04 | Contrato MQTT v1, consumidor local e simulador Node com tentativa, comando e ACK | [Contrato](../architecture/contratos-mqtt.md), [`mqtt-consumer.ts`](../../backend/src/main/mqtt-consumer.ts), PR #7 |
| US-05 | Modelo Prisma, migration, seed demonstrativa e diagrama ER | [`backend/prisma/`](../../backend/prisma/), [modelo de dados](../architecture/modelo-dados.md), PR #6 |
| US-06 | OpenAPI 3.1 e rotas stub com validação Zod | [OpenAPI](../api/openapi.yaml), [`main/http/`](../../backend/src/main/http/), PR #5 |
| US-07 | Esqueleto modular ESP32, retentativas de conexão e demo Wokwi→Mosquitto | [`firmware/`](../../firmware/), [evidência da demo](evidencias/us-07-wokwi.md), PR #12 |
| US-09 | Flutter com Riverpod, go_router e temas claro/escuro | [`mobile/lib/core/`](../../mobile/lib/core/), PR #4 |
| US-11 | Processo Scrum, backlog de 38 histórias, DoD, sprints e templates | [`docs/scrum/`](../scrum/) |
| US-12 | Design system com Figtree, fluxo do usuário e estados | [`design/`](../../design/), 23 PNGs em `design/figma/` |
| US-13 | CD da API na Vercel e healthcheck conectado ao Neon | [`cd-backend.yml`](../../.github/workflows/cd-backend.yml), [guia de deploy](../guides/deploy.md), PR #8 e correções #10/#11 |

## 5. Qualidade e reprodução da demo

Os workflows, testes e roteiros estão versionados. A evidência da US-07 registra build, testes host, recebimento de mensagem e reconexão; build verde sozinho não comprova a comunicação Wokwi→broker.

### Preparação

Usar o código da `main` de referência, dependências instaladas e os ambientes descritos no [guia local](../guides/como-rodar.md), no [README mobile](../../mobile/README.md) e no [README firmware](../../firmware/README.md). Para Wokwi, são necessários VS Code, extensão/licença ativa e firmware compilado.

### Roteiro

1. **API publicada:** abrir `/health` e mostrar `database: ok`; abrir `/docs` e distinguir contrato de implementação.
2. **MQTT v1 simulado:** subir o broker na raiz:

   ```bash
   docker compose -f infra/docker-compose.dev.yml up -d mosquitto
   ```

   Em dois terminais, a partir de `backend/`:

   ```bash
   npm run mqtt:consumer
   ```

   ```bash
   npm run sim:terminal
   ```

   Mostrar tentativa NFC **sintética**, comando e ACK correlacionado. O decisor da S1 é provisório e libera qualquer UID; isso não demonstra autorização real.

3. **Wokwi:** seguir a preparação em `firmware/README.md`, selecionar `wokwi/wokwi.toml` e iniciar o simulador. Na raiz, publicar:

   ```bash
   docker compose -f infra/docker-compose.dev.yml exec mosquitto mosquitto_pub -h localhost -p 1883 -t terminals/terminal-dev-01/commands -m smoke-us07 -q 1
   ```

   Mostrar o recebimento na serial. Reiniciar o broker com `docker compose -f infra/docker-compose.dev.yml restart mosquitto`, aguardar reconexão e repetir a publicação.

4. **Mobile:** em `mobile/`, executar `flutter run -d chrome`. Mostrar validação de campos e carregamento; uma entrada válida termina no aviso de login indisponível, sem navegação de sucesso.

**São provas separadas:** o simulador Node exercita o contrato v1; o Wokwi comprova transporte e reconexão do esqueleto ESP32, sem interpretar ou executar o comando.

## 6. O que não entrou e por quê

| Card | Estado no fechamento | Continuidade |
|---|---|---|
| US-08 — Herança do protótipo | Não iniciada; servo, LED, buzzer e LCD não foram portados | S2 com **Caio**, sobre o esqueleto da US-07 |
| US-10 — Login & scanner | Apenas login mock, PR #13; sem scanner, geolocalização, sessão ou configuração completa de localização Material pt-BR | S2 com **Art**; refinar aproveitamento nas US-27/29 |

A sprint curta terminou com a US-08 sem início e a US-10 parcial. Aplicou-se o corte de segurança já previsto na [Sprint 1](../scrum/sprints/sprint-1.md), sem contabilizar histórias incompletas como concluídas.

## 7. Dívida técnica e prioridades da S2

Foram mapeados 11 cards na lista **“🧱 Dívida Técnica”** do Trello. Sprint alvo, responsáveis e compromisso serão definidos na Planning 2.

| Prioridade de tratamento | Cards |
|---|---|
| Antes da demo QR com atuação | **DT-01:** bloquear decisor fail-open; **DT-02:** comandos/ACK entre API e worker; **DT-03:** terminal→local; **DT-04:** evento sem local no contrato; **DT-06:** TLS no firmware |
| Confiabilidade antes de atuação real | **DT-05:** idempotência e frescor, incluindo retentativa após falha do decisor |
| Antes do deploy do fluxo real | **DT-07:** proteger seed/dados demo; **DT-09:** migrations no CD |
| Antes da entrega Android | **DT-10:** build Android no CI |
| Conforme superfície e planejamento | **DT-08:** CORS com allowlist, necessário para web entre origens; **DT-11:** pinagem de actions por SHA |

Esses cards não representam correções já entregues.

## 8. Riscos

| Risco | Tratamento previsto |
|---|---|
| Confundir transporte demonstrado com acesso autorizado | Manter explícitos os limites dos mocks e das duas demos MQTT |
| Wokwi depender de licença e ambiente local | Preservar [evidência registrada](evidencias/us-07-wokwi.md) e roteiro; a licença registrada vence em 20/11/2026 |
| APK ainda não validado | Preparar Android SDK e tratar DT-10; widgets verdes não comprovam empacotamento Android |
| Broker dev sem TLS e com acesso anônimo | Restringir à rede de desenvolvimento; não expor à internet |
| Escopo S2 exceder a capacidade | Estimar, fatiar e definir cortes antes do compromisso, incluindo os dois cards carregados e as dívidas |
| Deploy saudável mascarar integração incompleta | Não interpretar `/health` como prova de migrations, autorização ou fluxo QR operacional |

## 9. Próxima sprint

A **S2 ocorre de 22/10 a 11/11/2026**, com Review em 11/11, às 19h30. O foco previsto é o fluxo QR real, backend administrativo, app, terminal e worker MQTT no Render.

A [Sprint 2](../scrum/sprints/sprint-2.md) lista 13 histórias futuras, além dos dois cards carregados. O compromisso final depende da Planning 2.

**Dependência obrigatória de planejamento:** a decisão de acesso está na **US-20**, ainda prevista para S3 e com endpoint stub. Para prometer QR ponta-a-ponta na S2, é necessário antecipar uma fatia dela; caso contrário, reduzir explicitamente o objetivo. A fatia da US-21 e as dívidas técnicas também precisam de aceite e prioridade definidos.

## 10. Rastreabilidade

- [Product backlog e critérios de aceite](../scrum/product-backlog.md).
- [Fechamento da Sprint 1](../scrum/sprints/sprint-1.md) e [Definition of Done](../scrum/definition-of-done.md).
- [Roteiro da Review](../scrum/sprints/sprint-1-review.md) e [rascunho da retrospectiva](../scrum/sprints/sprint-1-retro.md); feedback da banca e ações finais devem ser registrados após a cerimônia.
- [Roteiro de apresentação](apresentacao-review-1.md) — falas, ordem das demos, comandos e perguntas prováveis.
- [Evidência Wokwi da US-07](evidencias/us-07-wokwi.md), produzida no commit `268637f`.
- Rastreio de implementação: card `US-XX` → branch → linha `Card: US-XX` do PR → checks e merge. [PRs do projeto](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/pulls?q=is%3Apr+is%3Amerged).
- O Trello acompanha o estado vivo; o repositório preserva contratos, código e registros da entrega.

> **Nota de conferência:** no commit `18d9fe7`, já estão mergeados os PRs de documentação #14 e #15. Portanto, o total é **14 PRs (#2 a #15)**; os **12 PRs (#2 a #13)** informados correspondem ao recorte anterior ao fechamento documental.
