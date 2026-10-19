# Sprint 1 — Fundação (15/10 → 21/10)

- **Planning 1**: 15/10 · **Review**: 21/10 19h30 · **Retro**: logo após a review (30 min)
- **Goal**: "Fundação no ar + esqueleto conversando ponta-a-ponta, simulado"
- **Duração**: 7 dias (sprint curta, alinhada à Review 1 do cronograma oficial)

## Divisão dos cards

Divisão acordada na spec: o **SM** com 3 cards de alicerce (executados em parceria com o OpenCode) e **2 cards para cada um dos 5 devs**. A distribuição real ficou: Felipe (US-02/03, concluídas), Carlos (US-06 + US-09 concluída), Caio (US-05/08), Leo (US-04/13) e Art (US-07/10 — convite do board pendente). **Atualização (18/10)**: os 3 cards do SM e US-02/US-03/US-09 estão concluídos.

| US | Título | Dono | Pontos | Status |
|---|---|---|---|---|
| US-01 | Repo vivo | SM | — (Planning 1) | **Concluído (15/10)** |
| US-02 | CI trio + vínculo Trello↔PR | Felipe | — (Planning 1) | **Concluído (18/10)** |
| US-03 | Esqueleto backend | Felipe | — (Planning 1) | **Concluído (18/10)** |
| US-04 | MQTT v1 + simulador | Leo | — (Planning 1) | Backlog |
| US-05 | Modelo de dados v1 | Caio | — (Planning 1) | Backlog |
| US-06 | OpenAPI v1 | Carlos | — (Planning 1) | Backlog |
| US-07 | Esqueleto firmware | Art* | — (Planning 1) | Backlog |
| US-08 | Herança do protótipo | Caio | — (Planning 1) | Backlog |
| US-09 | Esqueleto Flutter | Carlos | — (Planning 1) | **Concluído (18/10)** |
| US-10 | Login & scanner (esqueleto) | Art* | — (Planning 1) | Backlog |
| US-11 | Documentos Scrum | SM | — (Planning 1) | **Concluído (15/10)** |
| US-12 | Design no Figma (fase 1) | SM | — (Planning 1) | **Concluído (15/10)** |
| US-13 | CD + deploy inicial | Leo | — (Planning 1) | Backlog |

**Status**: `Backlog` (na lista `🎯 Sprint Atual`) → `Em andamento` → `Em review` → `Concluído`. A S1 **não tem estimativa registrada**; o acompanhamento é por aceite e demonstração. Nenhuma pontuação retroativa: a estimativa colaborativa volta na Planning 2.

**Retrato de 18/10**: US-02, US-03 e US-09 também foram concluídas (Trello + `main`). A tabela acima é um retrato desta data; o board do Trello é a fonte viva. `*` Art ainda não está no board; responsável registrado, convite pendente.

Narrativa e critérios de aceite de cada card: [`product-backlog.md`](../product-backlog.md).

## Cortes de segurança

Se a sprint apertar (7 dias até a Review 1), **US-08** (herança do protótipo) e **US-10** (login & scanner) podem escorregar para a Sprint 2 **sem quebrar a review**. Todo o resto da fundação permanece na Sprint 1.

**Corte fechado (18/10)**: em **20/10 às 19h30**, US-08 e US-10 sem PR demonstrável e checks verdes saem do compromisso da S1 e vão para a S2, mantendo o responsável. Não entram parcialmente em Concluído.

## Burndown

A S1 não tem burndown por pontos (sem estimativa registrada). O acompanhamento é pelo status dos cards e pelas demos da Review.

## Rastreio

`US-XX` no card do Trello → título da branch → linha `Card: US-XX` do PR → execução. As cerimônias seguem os templates de [`../templates/review.md`](../templates/review.md) e [`../templates/retro.md`](../templates/retro.md).
