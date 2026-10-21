# Sprint 1 — Fundação (15/10 → 21/10)

- **Planning 1**: 15/10 · **Review**: 21/10 19h30 · **Retro**: logo após a review (30 min)
- **Goal**: "Fundação no ar + esqueleto conversando ponta-a-ponta, simulado"
- **Duração**: 7 dias (sprint curta, alinhada à Review 1 do cronograma oficial)

## Divisão dos cards

Divisão acordada na spec: o **SM** com 3 cards de alicerce (executados em parceria com o OpenCode) e **2 cards para cada um dos 5 devs**. A distribuição real ficou: Felipe (US-02/03), Carlos (US-06 + US-09), Caio (US-05/08), Leo (US-04/13) e Art (US-07/10).

| US | Título | Dono | Status |
|---|---|---|---|
| US-01 | Repo vivo | SM | **Concluído (15/10)** |
| US-02 | CI trio + vínculo Trello↔PR | Felipe | **Concluído (18/10)** |
| US-03 | Esqueleto backend | Felipe | **Concluído (18/10)** |
| US-04 | MQTT v1 + simulador | Leo | **Concluído (19/10)** |
| US-05 | Modelo de dados v1 | Caio | **Concluído (19/10)** |
| US-06 | OpenAPI v1 | Carlos | **Concluído (19/10)** |
| US-07 | Esqueleto firmware | Art | **Concluído (21/10)** — demo Wokwi→broker validada |
| US-08 | Herança do protótipo | Caio | **Não iniciada** — corte aplicado; segue para a S2 |
| US-09 | Esqueleto Flutter | Carlos | **Concluído (18/10)** |
| US-10 | Login & scanner (esqueleto) | Art | **Parcial (PR #13)** — só login; segue para a S2 |
| US-11 | Documentos Scrum | SM | **Concluído (15/10)** |
| US-12 | Design no Figma (fase 1) | SM | **Concluído (15/10)** |
| US-13 | CD + deploy inicial | Leo | **Concluído (19/10)** |

**Fechamento (21/10)**: **11 de 13 cards concluídos**. US-08 e US-10 não entram em Concluído — nenhum atende ao aceite completo — e seguem para a Sprint 2 com os mesmos donos. O board do Trello (listas `🎯 Sprint 1` e `🎯 Sprint 2`) é a fonte viva; o resultado está em [`sprint-1-review.md`](sprint-1-review.md), a retro em [`sprint-1-retro.md`](sprint-1-retro.md) e o documento da Review 1 em [`../../entrega/review-1.md`](../../entrega/review-1.md).

**Status**: `Backlog` (na lista `🎯 Sprint 1`) → `Em andamento` → `Em review` → `Concluído`. A S1 **não tem estimativa registrada**; o acompanhamento é por aceite e demonstração. Nenhuma pontuação retroativa: a estimativa colaborativa volta na Planning 2.

Narrativa e critérios de aceite de cada card: [`product-backlog.md`](../product-backlog.md).

## Cortes de segurança

Se a sprint apertar (7 dias até a Review 1), **US-08** (herança do protótipo) e **US-10** (login & scanner) podem escorregar para a Sprint 2 **sem quebrar a review**. Todo o resto da fundação permanece na Sprint 1.

**Corte aplicado (21/10)**: US-08 (não iniciada) e US-10 (apenas o login entregue) saem do compromisso da S1 e vão para a S2, mantendo os responsáveis. A US-07 chegou a ficar em review por falta da demo Wokwi, mas foi fechada no mesmo dia após a validação Wokwi→broker. Nenhuma história incompleta entra em Concluído.

## Burndown

A S1 não tem burndown por pontos (sem estimativa registrada). O acompanhamento é pelo status dos cards e pelas demos da Review.

## Rastreio

`US-XX` no card do Trello → título da branch → linha `Card: US-XX` do PR → execução. As cerimônias seguem os templates de [`../templates/review.md`](../templates/review.md) e [`../templates/retro.md`](../templates/retro.md).
