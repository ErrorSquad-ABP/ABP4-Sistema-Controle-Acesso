# Sprint 3 — Review (25/11/2026, 19h30)

- **Participantes:** ErrorSquad (6) · banca/professores
- **Goal da sprint:** fechar o acesso físico na bancada — QR, tag e celular — com auditoria, demo web e entrega documentada.
- **Referência:** `main` com o fluxo HCE (#77), o QR compacto (#73), o firmware (#79), o app (#78), a demo web (#75) e esta documentação.
- **Fechamento do trabalho:** 24/11/2026.

> Roteiro preparado para a Review 3. O feedback da banca deve ser preenchido durante a cerimônia; o documento não registra fala que não aconteceu.

## Demos previstas

| Card | O que mostrar | Evidência |
|---|---|---|
| US-22 | OLED exibindo o QR de 41 dígitos e o LCD com o status | firmware + captura |
| US-23 | Tag física encostada no RC522, decisão e feedback | `us-23-nfc-rc522.md` |
| US-24 | Celular encostado, prova HCE lida e ACK | eventos e ACK no banco; `us-24.md` |
| US-29 | App lendo o QR do terminal e mostrando liberado/negado | `us-29-aparelho.md` |
| US-33 | Revisão de segurança e riscos residuais | PR #76, `us-33.md` |
| US-34 | Conjunto em bancada: QR, tag, HCE e servo | eventos e ACKs |
| US-35 | Diagramas de casos de uso, componentes, implantação e sequências | PR #74 |
| US-36 | Relatório ABNT, mídias e roteiro da apresentação | `relatorio/` e `midias/` |
| US-38 | Demo web publicada e CORS exato | `https://abp4-demo-web.vercel.app` |

## Sequência sugerida (20 minutos)

1. **Problema e escopo (2 min):** por que um controle de acesso auditável; o que o desafio pedia.
2. **Arquitetura (3 min):** app, API, worker e terminal; decisão separada da atuação.
3. **QR (3 min):** rotação de 25 s, leitura pelo app e decisão com geofence; mostrar evento e ACK.
4. **NFC (4 min):** tag física e HCE; mostrar a prova de uso único e a negativa da segunda apresentação.
5. **Operação (2 min):** API, worker, banco e demo web; CI e testes.
6. **Limitações e conclusão (3 min):** GPS ausente, US-25 bloqueada, energia não medida, abertura física não demonstrada.
7. **Perguntas (3 min).**

## O que não entra na demo

- Abertura de uma cancela real: o servo é acionado, mas o mecanismo não está acoplado.
- GPS do terminal: módulo indisponível; a posição vem do app.
- Fila offline do firmware (US-25): bloqueada.
- Medição de consumo elétrico: não realizada.
- NFC no navegador: a demo web declara a limitação e não oferece a ação.

## Plano B da demonstração

Se a rede ou o terminal falhar, usar as evidências já registradas: eventos e ACKs no banco, capturas da demo web, diagramas e o PDF do relatório. O roteiro evita prometer o que depende de um único aparelho no palco.

## Feedback do stakeholder

- _Preencher durante a review._

## Ações propostas

- Confirmar o heartbeat no ESP32 com o firmware da `main` (US-24).
- Retomar a US-25 após a entrega, com backoff e fila persistida.
- Concluir os aceites formais da revisão de segurança (US-33).
- Acoplar o servo a uma cancela real e medir o consumo (US-34/DT-22).
- Evoluir a demo web para cobrir login e leitura de QR com conta de demonstração.

## Links

- Repositório: https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso
- Board: https://trello.com/b/AxZZyPyN/errorsquad-abp-4dsm
- Documento de entrega: [`../../entrega/review-3.md`](../../entrega/review-3.md)
- Relatório: [`../../entrega/relatorio/relatorio-abnt.pdf`](../../entrega/relatorio/relatorio-abnt.pdf)
