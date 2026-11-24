# Sprint 3 — NFC, hardware e entrega final (12/11 → 25/11/2026)

- **Planning 3**: 12/11/2026 · **Review 3**: 25/11/2026, 19h30 · **Retro**: logo após a review (30 min)
- **Foco macro**: fechar o controle de acesso físico (QR, tag e celular), consolidar a qualidade e entregar documentação e demonstração final.
- **Sprint Goal**: *"Um acesso real de ponta a ponta na bancada — QR, tag e celular — com o sistema auditável, a demo web publicada e a entrega final documentada em ABNT."*

## Escopo e resultado

A Sprint 3 partiu do plano de NFC, geofence e polish e absorveu o fechamento do fluxo físico que dependia de bancada. O resultado foi além do previsto em três frentes: o QR compacto passou a caber no OLED, o NFC do celular (HCE) foi implementado e validado, e o terminal ganhou leitura de prova efêmera e heartbeat.

| US | Título | Resultado | Evidência |
|---|---|---|---|
| US-22 | QR compacto no OLED | Concluído: token de 41 dígitos renderizado por inteiro, com margem e escala | PR #73, `us-35.md` |
| US-23 | NFC RC522 e feedback | Concluído: tag física, MQTT, decisão e feedback | PR #67, `us-23-nfc-rc522.md` |
| US-24 | Heartbeat e presença | Código concluído e mergeado; confirmação no ESP32 pendente | PR #82, `us-24.md` |
| US-25 | Resiliência offline | **Bloqueada** por decisão do time | Card no Trello |
| US-28 | Minhas autorizações | Concluído na S2/S3 | PR #69 |
| US-29 | Scanner e pedido de acesso | Concluído, com execução em aparelho | PR #55, `us-29-aparelho.md` |
| US-30 | Admin de autorizações | Concluído | PR #69 |
| US-31 | Admin de usuários e histórico | Concluído | PR #69 |
| US-33 | Revisão de segurança | Revisão feita; PR em revisão por pares | PR #76, `us-33.md` |
| US-34 | Teste em hardware real | Executado em bancada: QR, tag, HCE e servo | eventos e ACKs no banco |
| US-35 | Diagramas finais | Concluído | PR #74 |
| US-36 | Relatório ABNT e apresentação | Entregue neste fechamento | `relatorio/`, `midias/` |
| US-38 | Demo web e identidade | Concluído e publicado | PR #75, `us-38.md` |
| US-39 | Locais no app | Concluído | PR #69 |

## Entregas que marcaram a sprint

1. **QR no OLED:** o token numérico de 41 dígitos passou a ser desenhado inteiro, com margem de silêncio, e o LCD mostra o status. A leitura pelo aplicativo foi validada em bancada.
2. **HCE do celular:** o aplicativo emite uma prova de 128 bits na API, apresenta por `HostApduService` e o firmware lê por ISO-DEP. A prova é de uso único; a segunda apresentação é negada.
3. **Ajuste de tempo do RC522:** o leitor espera 25 ms e o Android demorava mais para conectar o serviço na primeira apresentação. O serviço passou a ser preparado enquanto a tela de NFC está em primeiro plano, e a resposta foi reduzida para 16 bytes.
4. **Heartbeat:** o firmware publica status retained a cada 30 s e registra LWT offline. O worker deixa de depender de uma leitura NFC para marcar presença.
5. **Demo web:** projeto separado na Vercel, com CORS exato na API, tela de entrada e aviso de limitações do navegador.
6. **Documentação final:** diagramas conferidos contra o código, matriz atualizada, relatório ABNT, pasta de mídias e roteiro de apresentação.

## Qualidade observada

| Item | Resultado em 24/11/2026 |
|---|---|
| Testes do aplicativo | 664 aprovados; `flutter analyze` sem problemas |
| Testes do backend | 450 aprovados no merge do fluxo HCE |
| Firmware | Suite host com MQTT, TLS, NFC/HCE, display, servo e timing; builds PlatformIO |
| CI | Seis checks obrigatórios, CodeQL e Dependabot |
| API | `/health` com `database: ok` |
| Worker | `/healthz` com `status: ok` |
| Demo web | Publicada e verificada no navegador |
| Hardware | QR, tag e HCE com `GRANTED` e ACK `executed` |

Os números são das execuções registradas em 24/11/2026; não são uma medição contínua nem uma estimativa de velocidade por pontos.

## O que não fechou

- **US-25 (resiliência offline):** bloqueada por decisão do time. O escopo está preservado (backoff com jitter, fila persistida, TTL de 30 s, dedup por `messageId`), mas a mudança mexe no caminho de reconexão e no NVS do ESP32 e não bloqueia a banca.
- **GPS do terminal:** o módulo NEO-6M não estava disponível. O terminal não publica coordenada; a posição vem do aplicativo.
- **Abertura física de cancela:** o servo é acionado, mas o mecanismo de uma porta real não foi acoplado.
- **Consumo elétrico:** a DT-22 foi encerrada por escopo, com orçamento e procedimento; nenhum valor foi medido.
- **US-33:** a revisão está registrada, mas o PR segue em revisão por pares e os aceites formais de risco estão pendentes.

## Burndown

Não houve registro diário de pontos. O quadro abaixo mostra o que restava no fechamento, por estado, em vez de inventar uma curva.

| Estado no fechamento | Itens |
|---|---|
| Entregue | US-22, US-23, US-28, US-29, US-30, US-31, US-34, US-35, US-36, US-38, US-39 e DT-22 |
| Em revisão | US-24 (hardware) e US-33 (PR) |
| Bloqueado | US-25 |

## Rastreabilidade

- [Review 3](sprint-3-review.md) · [Retrospectiva 3](sprint-3-retro.md)
- [Documento de entrega final](../../entrega/review-3.md)
- [Relatório ABNT](../../entrega/relatorio/relatorio-abnt.pdf)
- [Matriz de requisitos](../../entrega/matriz-requisitos.md) · [Índice de evidências](../../entrega/README.md)
- [Product backlog](../product-backlog.md)
