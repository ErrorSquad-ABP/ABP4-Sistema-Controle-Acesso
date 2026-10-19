# Processo Scrum — ErrorSquad ABP 4DSM

## Como aplicamos o Scrum

Somos um time pequeno de 6 pessoas tocando o Sistema Integrado de Controle de Acesso em sprints curtas, alinhadas ao cronograma oficial da FATEC. O trabalho vive em cards no Trello, cada card vira uma branch e um PR, e o merge só acontece com 1 review e CI verde. Aplicamos o Scrum no mínimo que funciona para este time: Planning no início da sprint, Review nas datas oficiais, Retro logo depois e refinamento só quando aparece card novo para fatiar. Fica fora por YAGNI: DoR separado, atas longas, métricas elaboradas e qualquer documentação de daily.

## Papéis

- **SM**: João Victor Lopes Rosa.
- **PO**: Felipe Pacheco (@FelipePacheco30) — definido em 15/10 (stakeholder avaliador: Prof. Leandro Toss Hoffmann e banca).
- **Devs**: os 6 — todos executam, inclusive SM e PO.

## Ritos

| Rito | Quando | Duração |
|---|---|---|
| Planning | Início de cada sprint | 1h |
| Review | Datas oficiais do cronograma, 19h30 | — |
| Retro | Logo após cada review | 30 min |
| Refinamento | Quando houver card novo para fatiar | 30 min |

**Dailies**: acontecem informalmente no grupo do time, **sem documentação** (decisão do time).

## Ferramentas

- **Trello** (board `ERRORSQUAD ABP 4DSM`): a fonte viva — onde os cards se movem durante a sprint.
- **`docs/scrum/`**: a fonte oficial — o processo e o backlog como o time acordou.
- **GitHub**: o código, os PRs e o CI.

## Sprints

| Sprint | Janela | Review | Foco |
|---|---|---|---|
| Sprint 1 | 15/10 → 21/10 | 21/10 | Fundação + esqueleto ponta-a-ponta (simulado) |
| Sprint 2 | 22/10 → 11/11 | 11/11 | Fluxo QR real ponta-a-ponta + admin + deploy + design admin/terminal |
| Sprint 3 | 12/11 → 25/11 | 25/11 | NFC + geofence ≤100m + histórico + qualidade + polish |
| Entrega final | 26/11 → data oficial | — | Relatório ABNT, apresentação, hardening |

## Rastreio

Todo trabalho é rastreável de ponta a ponta: `US-XX` no card do Trello → título da branch → linha `Card: US-XX` do PR → execução. O workflow `trello-link.yml` amarra o PR ao card por essa linha.

## Índice

- [`README.md`](README.md) — este documento de processo.
- [`definition-of-done.md`](definition-of-done.md) — o que significa "pronto" para um card.
- `product-backlog.md`, `sprints/` e `templates/` completam a pasta (US-11).
