# Sprint 3 — Retrospectiva (25/11/2026)

- **Período:** 12 a 25 de novembro de 2026
- **Goal:** fechar o acesso físico na bancada e entregar a documentação final.
- **Participantes:** ErrorSquad (6)

A retrospectiva abaixo separa o que foi observado do que é hipótese. Não há medição de velocidade por pontos; os números citados são de execução de testes e de estado do board.

## O que funcionou

- **Integração app–terminal:** o fluxo QR, tag e HCE foi exercitado com hardware real; os eventos e ACKs ficaram registrados no banco.
- **Diagnóstico por evidência:** o timeout do RC522 foi localizado comparando logs do firmware e do Android, não por tentativa às cegas. A correção (serviço HCE preparado em primeiro plano e resposta de 16 bytes) foi validada em bancada.
- **Entrega contínua:** os checks obrigatórios e o CodeQL bloquearam regressões; o deploy da demo web foi refeito com token próprio e smoke test.
- **Documentação rastreável:** cada requisito crítico tem evidência ou lacuna declarada. O relatório ABNT usa a matriz como fonte de verdade.

## O que não funcionou

- **Dependência de um único módulo físico:** o GPS do terminal não existia e o escopo precisou ser reduzido no fim. A lição é confirmar a disponibilidade de hardware no início da sprint.
- **Tempo do HCE só apareceu no hardware:** os testes host não capturavam a latência de conexão do serviço Android. Testes de integração com o aparelho deveriam entrar mais cedo.
- **Fila offline planejada para a véspera:** a US-25 foi corretamente bloqueada, mas o risco deveria ter sido levantado na Planning, não no fechamento.
- **Deploy da demo web dependia de permissão do token:** o token da API não enxergava o projeto novo. O diagnóstico consumiu tempo que poderia ter sido evitado com um token por projeto desde o início.

## Experimentos para o próximo ciclo

| Experimento | Dono | Primeira ação | Verificação | Revisão |
|---|---|---|---|---|
| Confirmar hardware disponível antes de fechar escopo | PO/SM | Checklist de bancada na Planning | Itens de hardware listados com responsável | Próxima Planning |
| Teste de integração com aparelho desde a primeira semana | Dev mobile | Rodar o fluxo HCE em aparelho na semana 1 | Latência e sucesso registrados | Fim do próximo ciclo |
| Token e projeto de deploy separados por aplicação | Dev/DevOps | Criar token por projeto e documentar | Deploy da demo sem bloqueio | Próximo deploy |
| Fila offline e backoff como item de início de sprint | Dev firmware | Refinar US-25 antes de codar | Testes host de queda e reenvio | Próxima sprint |

## Métricas observadas

| Indicador | Valor | Fonte |
|---|---|---|
| Testes do app | 664 aprovados | execução local em 24/11/2026 |
| Testes do backend | 450 aprovados no merge do HCE | PR #77 |
| Checks obrigatórios | 6 verdes | GitHub Actions |
| Cards em review/bloqueados | US-24 (hardware) e US-33 (PR); US-25 bloqueada | Trello |

Não houve registro diário de pontos ou de lead time; a sprint não deve ser comparada por velocidade.

## Ações que viram card

- Confirmar heartbeat no ESP32 (US-24).
- Retomar US-25 com o escopo preservado.
- Concluir aceites da revisão de segurança (US-33).
- Acoplar servo a uma cancela real e medir consumo (US-34/DT-22).
- Evoluir a demo web com login e leitura de QR.
