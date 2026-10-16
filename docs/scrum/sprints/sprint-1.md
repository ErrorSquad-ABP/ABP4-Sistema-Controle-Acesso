# Sprint 1 — Fundação (15/10 → 21/10)

- **Planning 1**: 15/10 · **Review**: 21/10 19h30 · **Retro**: logo após a review (30 min)
- **Goal**: "Fundação no ar + esqueleto conversando ponta-a-ponta, simulado"
- **Duração**: 7 dias (sprint curta, alinhada à Review 1 do cronograma oficial)

## Divisão dos cards

Divisão acordada na spec: o **SM** com 3 cards de alicerce (executados em parceria com o OpenCode) e **2 cards para cada um dos 5 devs**. Os cards nascem sem assignee; cada um puxa o seu na Planning 1. **Atualização (15/10)**: os 3 cards do SM (US-01, US-11, US-12) foram entregues na fundação e já constam como Concluído — é o ponto de partida que o time encontra na Planning.

| US | Título | Dono | Pontos | Status |
|---|---|---|---|---|
| US-01 | Repo vivo | SM | — (Planning 1) | **Concluído (15/10)** |
| US-02 | CI trio + vínculo Trello↔PR | Dev A | — (Planning 1) | Backlog |
| US-03 | Esqueleto backend | Dev B | — (Planning 1) | Backlog |
| US-04 | MQTT v1 + simulador | Dev B | — (Planning 1) | Backlog |
| US-05 | Modelo de dados v1 | Dev C | — (Planning 1) | Backlog |
| US-06 | OpenAPI v1 | Dev C | — (Planning 1) | Backlog |
| US-07 | Esqueleto firmware | Dev D | — (Planning 1) | Backlog |
| US-08 | Herança do protótipo | Dev D | — (Planning 1) | Backlog |
| US-09 | Esqueleto Flutter | Dev E | — (Planning 1) | Backlog |
| US-10 | Login & scanner (esqueleto) | Dev E | — (Planning 1) | Backlog |
| US-11 | Documentos Scrum | SM | — (Planning 1) | **Concluído (15/10)** |
| US-12 | Design no Figma (fase 1) | SM | — (Planning 1) | **Concluído (15/10)** |
| US-13 | CD + deploy inicial | Dev A | — (Planning 1) | Backlog |

**Status**: `Backlog` (na lista `🎯 Sprint Atual`) → `Em andamento` → `Em review` → `Concluído`. Os pontos de todo card ficam `— (Planning 1)` até a estimativa acontecer na Planning 1; nada é chutado aqui.

Narrativa e critérios de aceite de cada card: [`product-backlog.md`](../product-backlog.md).

## Cortes de segurança

Se a sprint apertar (7 dias até a Review 1), **US-08** (herança do protótipo) e **US-10** (login & scanner) podem escorregar para a Sprint 2 **sem quebrar a review**. Todo o resto da fundação permanece na Sprint 1.

## Burndown simples

Total de pontos definido na Planning 1; os pontos restantes são preenchidos ao fim de cada dia. Burndown proposital simples (YAGNI: sem gráfico, sem ferramenta).

| Dia | Pontos restantes |
|---|---|
| 15/10 | — |
| 16/10 | — |
| 17/10 | — |
| 18/10 | — |
| 19/10 | — |
| 20/10 | — |
| 21/10 | — |

## Rastreio

`US-XX` no card do Trello → título da branch → título/corpo do PR → execução. As cerimônias seguem os templates de [`../templates/review.md`](../templates/review.md) e [`../templates/retro.md`](../templates/retro.md).
