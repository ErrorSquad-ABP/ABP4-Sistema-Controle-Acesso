# Entrega — índice das evidências

Um arquivo por card em [`evidencias/`](evidencias/): o que foi verificado, como reproduzir e os PRs/commits envolvidos. Nome no formato `dt-XX.md` ou `us-XX-slug.md`. O documento da Review 1 está em [`review-1.md`](review-1.md).

| Evidência | Card | Conteúdo | PR |
|---|---|---|---|
| [`dt-01-02-03.md`](evidencias/dt-01-02-03.md) | DT-01 · DT-02 · DT-03 | decisão real no worker, dedup persistente e mapeamento terminal→local, integrados sobre a `main` | #32 (origem no #31) |
| [`dt-10-build-android-ci.md`](evidencias/dt-10-build-android-ci.md) | DT-10 | APK Android gerado, conferido e instalado no CI mobile | #35 |
| [`dt-13.md`](evidencias/dt-13.md) | DT-13 | outbox de comando (`publishedAt`) com relay independente do terminal | #37 |
| [`dt-14.md`](evidencias/dt-14.md) | DT-14 | orçamento de conexões por pool e medição da rajada concorrente | #44 |
| [`dt-17.md`](evidencias/dt-17.md) | DT-17 | candidatas de autorização restritas na consulta e no lock | #41 |
| [`dt-18.md`](evidencias/dt-18.md) | DT-18 | retenção de `TerminalCommand` com expurgo em lotes | #40 |
| [`dt-19.md`](evidencias/dt-19.md) | DT-19 | limite do token QR no firmware alinhado ao backend | #39 |
| [`dt-20.md`](evidencias/dt-20.md) | DT-20 | `429` e `503` documentados nas operações QR | #38 |
| [`dt-21.md`](evidencias/dt-21.md) | DT-21 | janela de operação do relay (18:45–23:05, `America/Sao_Paulo`) e custo no Neon | #45 |
| [`us-07-wokwi.md`](evidencias/us-07-wokwi.md) | US-07 | esqueleto do firmware buildando e simulando no Wokwi | #12 |
| [`us-08-wokwi.md`](evidencias/us-08-wokwi.md) | US-08 | servo, LEDs, buzzer e LCD herdados do protótipo | #19 |
| [`us-10-scanner.md`](evidencias/us-10-scanner.md) | US-10 | scanner QR, geolocalização e textos em pt-BR | #20 |
| [`us-20.md`](evidencias/us-20.md) | US-20 | decisão de acesso QR e geofence de 100 m | #42 |
| [`us-26-mqtt-servo.md`](evidencias/us-26-mqtt-servo.md) | US-26 | comando de abertura do servo via MQTT (herdado da US-08) | #19 · #25 |
