# Apresentação — Review 1 · Sprint 1

- **Projeto:** ABP 2026-2 · Sistema Integrado de Controle de Acesso (QR + NFC + IoT)
- **Equipe:** ErrorSquad · 4DSM · FATEC Jacareí
- **Data:** 21/10/2026, 19h30 · **Duração alvo:** 10–12 min + perguntas
- **Documento de entrega:** [`review-1.md`](review-1.md)

> Regra de ouro: **mostrar o que roda, dizer o que é mock**. A banca perdoa esqueleto declarado; não perdoa promessa quebrada.

## 1. Abertura (1 min)

**Fala:** “Somos a ErrorSquad. Na Sprint 1 montamos a fundação do sistema de controle de acesso e três esqueletos que já conversam: API publicada, app Flutter e terminal ESP32 simulado. Fechamos 11 dos 13 cards; o que não fechou está declarado e já tem dono na Sprint 2.”

**Mostrar:** capa com equipe, goal da sprint e os três números: **11/13 cards · 122 testes de backend · 12 de mobile**.

## 2. Problema e escopo (1 min)

- Controle de acesso de baixo custo para edifícios.
- Terminal exibe QR rotativo (10 s) e lê NFC; app autentica, escaneia e envia localização; backend decide e registra; terminal abre via MQTT.
- **Nesta sprint:** fundação, contratos, deploy e esqueletos — **não** o fluxo real.

**Mostrar:** diagrama do README (app → API → banco; terminal ↔ broker MQTT).

## 3. Arquitetura entregue (2 min)

- Monorepo: `backend/`, `mobile/`, `firmware/`, `infra/`, `docs/`, `design/`.
- Backend Node/Express/TS em 4 camadas; Prisma/PostgreSQL (Neon); OpenAPI 3.1; MQTT v1.
- Mobile Flutter (Riverpod, go_router) com tema do design system.
- Firmware ESP32/PlatformIO modular, simulado no Wokwi.
- Vercel (API) + Neon (banco) + Docker local (Mosquitto/Postgres).

**Mostrar:** árvore do monorepo e o `docs/architecture/visao-geral.md`.

## 4. O que está no ar (1 min)

| Entrega | Evidência |
|---|---|
| API | `/health` → `database: ok` · `/docs` (Swagger) · `/openapi.json` |
| CI/CD | 4 checks obrigatórios + CodeQL; deploy Vercel |
| Repositório | 12 PRs de código mergeados; branch `main` protegida |
| Board | Trello com 11 concluídos, 2 na S2 e 11 dívidas técnicas |

**Mostrar:** `/health` e a aba Actions com um PR verde.

## 5. Demo (4–5 min)

### 5.1 MQTT v1 — contrato e simulador (1,5 min)

```bash
docker compose -f infra/docker-compose.dev.yml up -d mosquitto
# em backend/, dois terminais:
npm run mqtt:consumer
npm run sim:terminal
```

**Dizer:** “O simulador publica uma tentativa NFC **sintética**; o consumidor decide, publica o comando e recebe o ACK. O decisor é provisório e libera qualquer UID — isso é demonstração, não autorização real.”

### 5.2 Wokwi — transporte real do ESP32 (2 min)

1. Abrir `firmware/` no VS Code, selecionar `wokwi/wokwi.toml` e iniciar o simulador.
2. Na raiz, publicar:

```bash
docker compose -f infra/docker-compose.dev.yml exec mosquitto mosquitto_pub -h localhost -p 1883 -t terminals/terminal-dev-01/commands -m smoke-us07 -q 1
```

3. Mostrar na serial: `[mqtt] conectado e inscrito nos comandos` e `mensagem recebida ... (10 bytes)`.
4. Reiniciar o broker e mostrar a reconexão:

```bash
docker compose -f infra/docker-compose.dev.yml restart mosquitto
```

**Dizer:** “O firmware **recebe e descarta** a mensagem no esqueleto — sem parser, atuação ou ACK. O que está provado é o transporte e a reconexão.”

**Fallback:** [`evidencias/us-07-wokwi.md`](evidencias/us-07-wokwi.md).

### 5.3 Mobile — login mock (1 min)

```bash
cd mobile
flutter run -d chrome
```

**Mostrar:** validação por campo, loading e o aviso de indisponibilidade.
**Dizer:** “É mock: não autentica nem cria sessão. O contrato para a API da US-06 já está no código.”

### 5.4 Figma — design system e fluxo (1 min)

- Abrir as 4 páginas: Design System, Telas Claro, Telas Escuro, Handoff & Regras.
- Mostrar tokens, temas, as 9 telas do fluxo e a página de handoff (QR 10 s, geofence 100 m, perfis, NFC).
- **Dizer:** “O tema do Flutter espelha esses tokens e empacota a Figtree; os 23 PNGs estão em `design/figma/`.”

## 6. Qualidade (1 min)

- 122 testes de backend; 12 de mobile; build web; firmware com build + testes host.
- 4 checks obrigatórios + CodeQL; review obrigatória; sem segredos no repo.
- Deploy com healthcheck e banco em nuvem.
- **Dizer:** “CI verde não é prova de integração; por isso a demo Wokwi é separada.”

## 7. O que não entrou (1 min)

| Card | Estado | Destino |
|---|---|---|
| US-08 — herança do protótipo (servo/LED/buzzer/LCD) | **0/4**, sem branch | S2, Caio |
| US-10 — login & scanner | **2/6**: só login mock; faltam scanner, GPS, feedback AA e pt-BR | S2, Art |

**Dizer:** “Nenhuma história incompleta foi marcada como concluída.”

## 8. Dívida técnica e S2 (1 min)

- 11 cards `DT-01..DT-11` na lista **🧱 Dívida Técnica**.
- Bloqueiam QR com atuação: DT-01 fail-open, DT-02 comandos/ACK, DT-03 terminal→local, DT-04 evento sem local, DT-06 TLS.
- Antes do deploy real: DT-07 seed, DT-09 migrations. Android: DT-10.
- **Dependência da S2:** o fluxo QR ponta-a-ponta exige a **US-20** (decisão de acesso, hoje 501). A Planning 2 decide antecipar a fatia ou reduzir a promessa.

## 9. Próximos passos (30 s)

- Planning 2 em 22/10: estimativa, cortes e prioridade das DTs.
- S2: fluxo QR real + admin + worker MQTT no Render + design admin/terminal.
- Review 2: 11/11/2026.

## 10. Perguntas prováveis

| Pergunta | Resposta curta |
|---|---|
| “Isso já controla acesso?” | Não. É a fundação + esqueletos; o fluxo real começa na S2. |
| “Por que as rotas retornam 501?” | Contrato primeiro: o OpenAPI foi congelado e o mobile já integra contra ele; a implementação entra na S2. |
| “O login funciona?” | É mock, sem sessão. Validação e estados estão prontos; autenticação real é US-27. |
| “O Wokwi prova o quê?” | Transporte MQTT e reconexão do ESP32. Não prova parser, autorização nem abertura. |
| “Como garantem segurança?” | Branch protegida, review, CodeQL, segredos fora do repo; o fail-open do decisor é demo e está no DT-01. |
| “Por que não tem APK?” | Sem Android SDK no ambiente; build web validado; DT-10 cobre o build Android no CI. |
| “Qual o risco maior?” | Escopo da S2: 13 histórias + 2 carry-over + dívidas. A Planning 2 corta antes do compromisso. |
| “O que é real hoje?” | API no ar, CI/CD, contratos, banco, tema do app, login mock, transporte do firmware e design system. |

## 11. Checklist antes de começar

- [ ] Docker no ar: `docker compose -f infra/docker-compose.dev.yml up -d`
- [ ] Mosquitto em `localhost:1884` e Postgres healthy
- [ ] VS Code aberto em `firmware/` com `wokwi.toml` selecionado
- [ ] Licença Wokwi ativa (vence 20/11/2026)
- [ ] Abas abertas: `/health`, `/docs`, Actions, Figma, board
- [ ] Flutter disponível para `flutter run -d chrome`
- [ ] PNGS de `design/figma/` como fallback do Figma
- [ ] Documento de entrega aberto em `docs/entrega/review-1.md`

## 12. Links

- Repo: https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso
- API: https://abp-4-sistema-controle-acesso.vercel.app/health
- Swagger: https://abp-4-sistema-controle-acesso.vercel.app/docs
- Board: https://trello.com/b/AxZZyPyN/errorsquad-abp-4dsm
- Figma: https://www.figma.com/design/nddGhlwJIi5rMzhvsK5Rkl
- Documento de entrega: [`review-1.md`](review-1.md)
- Evidência Wokwi: [`evidencias/us-07-wokwi.md`](evidencias/us-07-wokwi.md)
