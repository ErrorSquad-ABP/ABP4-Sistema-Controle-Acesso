# Sprint 3 — NFC, geofence e qualidade (12/11 → 25/11)

- **Planning 3**: início da sprint · **Review 3**: 25/11 19h30 · **Retro**: logo após a review (30 min)
- **Foco macro**: NFC + geofence ≤100m + histórico + qualidade + polish

## Escopo previsto

Stories do backlog com **Sprint alvo S3** e com **S2/S3** no [`product-backlog.md`](../product-backlog.md). O refinamento fatiar e detalha cada uma antes de entrar na sprint; o escopo final é fechado na Planning 3.

| US | Título | Épico | Sprint alvo |
|---|---|---|---|
| US-20 | Validação de acesso QR com geofence 100m | E2 | S3 |
| US-21 | Eventos de acesso + histórico com filtros | E2 | S2/S3 |
| US-23 | NFC RC522 + feedback de decisão | E3 | S3 |
| US-24 | GPS + heartbeat | E3 | S3 |
| US-25 | Resiliência: retry/reconexão/persistência local | E3 | S3 |
| US-30 | Admin: autorizações criar/consultar/cancelar | E4 | S3 |
| US-31 | Admin: usuários e histórico + acessibilidade idoso | E4 | S3 |
| US-32 | E2E simulado no CI | E5 | S3 |
| US-33 | Revisão de segurança | E5 | S3 |
| US-34 | Teste em hardware real | E5 | S3 |
| US-35 | Diagramas e docs de arquitetura finais | E6 | S3 |
| US-38 | Demo web + identidade de distribuição na Vercel | E6 | S3 |

**US-21 (S2/S3)**: o que não fechou na Sprint 2 é retomado aqui.

**US-20 (antecipada)**: fechada na Sprint 2 pelo PR #42; a linha da US-20 na tabela fica só como registro do plano original, não como escopo novo.

**Atualização em 10/11/2026 (fechamento da S2):** esta tabela preserva o plano original. **US-20** e **US-32** foram antecipadas e concluídas na S2; **US-28 e US-29** entram na S3 como carry-over explícito (US-29 está no PR #55, aberto em review, sem câmera/GPS reais). US-24, US-28, US-30, US-31, US-33, US-34, US-35, US-36, US-38 e US-39 estão na lista Sprint 3; US-23/25 seguem em andamento; **DT-12 e DT-22** estão bloqueadas por bancada. O teto de 100 m (DT-23) e a pinagem/Dependabot (DT-24) foram concluídos em 10/11. Escopo final continua sujeito à Planning 3.

**US-38**: além do build web, troca os ícones padrão do Flutter (web e Android) por uma identidade única, com o nome público "Controle de Acesso".

Resumo por épico: **E2** acrescenta a validação por geofence e o histórico completo · **E3** entrega NFC, GPS/heartbeat e a resiliência do terminal · **E4** fecha o admin no app com acessibilidade para o público idoso (RNF04) · **E5** escreve a qualidade (E2E no CI, revisão de segurança, hardware real) · **E6** consolida arquitetura e diagramas.

A **US-36** (relatório ABNT e apresentação final) é da janela de entrega final, após a Review 3 — o projeto tem três sprints, não uma quarta. A Review 3 fecha a Sprint 3 conforme o cronograma oficial.

## Sprint Goal

A definir na Planning 3. O goal nasce do foco macro acima (NFC e geofence fechando o controle de acesso, com qualidade e polish).

## Backlog detalhado da sprint

Preenchido na Planning 3: cards puxados, donos, pontos, critérios de aceite refinados e cortes de segurança, no mesmo formato da [`sprint-1.md`](sprint-1.md).

| US | Título | Dono | Pontos | Status |
|---|---|---|---|---|
| — | — | — | — | — |

## Burndown simples

Total definido na Planning 3; pontos restantes preenchidos durante a sprint.

| Dia | Pontos restantes |
|---|---|
| 12/11 → 25/11 | — (preencher por dia na sprint) |
