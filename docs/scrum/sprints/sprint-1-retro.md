# Sprint 1 — Retrospectiva (21/10)

> Rascunho com os fatos do fechamento. Fechar as ações após a review, com dono e data de verificação.

## O que funcionou bem

- **Fundação pronta antes do código**: repo, CI trio, deploy, contratos (OpenAPI e MQTT) e board no ar desde os primeiros dias.
- **Demo Wokwi fechada no dia da review**: esqueleto do firmware conectou no Mosquitto, recebeu comando e reconectou após restart do broker (US-07).
- **Carry-over zerado no mesmo dia**: US-08 (servo/LED/buzzer/LCD) e US-10 (scanner/GPS/pt-BR) foram implementadas em 21/10; a validação física de câmera/APK ficou na DT-12.
- **CI e CD confiáveis**: os quatro checks obrigatórios + CodeQL rodaram em todos os PRs; o backend está no ar na Vercel com Neon e `/health` respondendo (`database: ok`).
- **Rastreabilidade**: card → branch → PR → execução funcionou; o `trello-link` anexa e comenta sozinho.
- **Entrega técnica**: 13 cards concluídos, 122 testes de backend e 33 de mobile verdes, 23 assets de design exportados.

## O que atrapalhou

- **PRs dos cards finais chegaram no último dia** (US-07 e US-10 em 20/10; US-08/US-10 em 21/10), sem tempo para review e correção antes do fechamento.
- **Escopo parcial apresentado como completo**: o PR #13 anunciava scanner, GPS e 42 testes, mas entregou o login e 12 testes.
- **Checklists do Trello não acompanharam os merges**: US-05 estava em Concluído com 0/4; US-07/US-10 com 0/6.
- **Sem estimativa na S1**: a sprint foi acompanhada por aceite, o que dificultou perceber o tamanho real do trabalho restante.

## Impedimentos recorrentes

- **Validação de hardware/Wokwi** depende de licença e ambiente local — a licença da extensão expirou em 15/10 e foi renovada em 21/10; não roda no CI.
- **Android SDK ausente** no ambiente de um dev: build APK não foi validado.

## Ações combinadas (dono + card no Trello)

| # | Ação | Dono | Verificação |
|---|---|---|---|
| 1 | Planning 2 com estimativa e escopo fatiado antes do compromisso | Felipe (PO) + SM | 22/10 |
| 2 | Validar Wokwi→broker e fechar a US-07 | Art + SM | **Concluída em 21/10** |
| 3 | Fatiar US-10: login vira base da US-27; scanner/GPS entram na US-29 | Art + SM | **Concluída em 21/10** (scanner/GPS entregues) |
| 4 | Atualizar checklist do Trello no mesmo dia do merge (gate de review) | SM | contínuo |
| 5 | Documentar instalação do Android SDK e build APK | Carlos | S2 |
| 6 | Validar câmera real e APK em dispositivo (DT-12/DT-10) | Art + Carlos | S2 |

## O que revisar na próxima retro

- As ações 1, 3, 4 e 5 foram cumpridas? (levar evidência, não impressão)
- O corte de escopo da S2 foi respeitado ou entrou trabalho novo no meio?
- A validação Wokwi/hardware deixou de ser bloqueio?
