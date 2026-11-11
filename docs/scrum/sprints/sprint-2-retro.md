# Sprint 2 — Retrospectiva (10/11)

> Rascunho com os fatos do fechamento antecipado. Fechar as ações após a review, com dono e data de verificação.

## O que funcionou bem

- **Fluxo QR real no backend**: credencial de 10 s, decisão com consumo condicional, evento auditado e comando MQTT, coberto por testes unitários, integração e E2E.
- **Antecipação com critério**: a folga do fim da sprint foi usada em US-20, US-32, DT-23 e DT-24, e em 22 das 24 dívidas técnicas, sem abrir frente nova de produto.
- **Deploy seguro**: migrations no CD, seed demo protegida, smoke test do `/health` e pré-check do banco antes da migration da DT-23.
- **Endurecimento de supply chain**: Actions por SHA, Dependabot semanal e CI com 6 checks obrigatórios + CodeQL.
- **Fechamento com evidência**: 458 testes de backend, 93 de mobile, 12 executáveis host e 6 cenários de timing no firmware, além de E2E 29/29.
- **Rastreabilidade**: card → branch → PR → execução funcionou nos 28 PRs da sprint; o `trello-link` anexou e comentou sozinho.

## O que atrapalhou

- **Duas histórias de app não fecharam**: US-28 não começou e US-29 parou na validação física de câmera/GPS. O backend pronto criou a impressão de fluxo completo.
- **Dependência de bancada**: NFC, GPS, servo, ACK, câmera e energia concentraram o bloqueio; a DT-22 não saiu de "estimativa".
- **Deploy do Render sem prova**: US-37 foi declarada concluída no board apenas pela implementação, sem serviço observado.
- **Auditoria pegou divergências de aceite**: teto de 100 m ausente (DT-23) e pinagem parcial (DT-24) só apareceram na conferência de 02/11, não na entrega original.
- **Merge administrativo**: a proteção exige review de outra conta e o autor não pode aprovar o próprio PR; a DT-23/DT-24 e a sincronização de docs exigiram `--admin` com autorização explícita, registrada nas evidências.

## Impedimentos recorrentes

- **Hardware e instrumentos**: sem ESP32 montado e medidor de corrente, DT-12/DT-22 não avançam; o Wokwi não modela consumo.
- **Sem ambiente de homologação**: CORS e migrations só podem ser provados em produção, depois do merge.
- **Câmera/GPS reais** dependem de aparelho físico e permissões; o CI cobre apenas doubles.

## Ações combinadas (dono + card no Trello)

| # | Ação | Dono | Verificação |
|---|---|---|---|
| 1 | Fechar US-29 com câmera e GPS em aparelho real | Leo | S3, antes da Review 3 |
| 2 | Implementar US-28 e o shell de autorizações | A definir na Planning 3 | S3 |
| 3 | Montar a bancada e fechar DT-12, DT-22, US-23 e US-24 na US-34 | Arthur + João | S3 |
| 4 | ~~Comprovar worker no Render e log de conexão MQTT (US-37)~~ — concluído em 11/11: serviço `live`, `mqtt conectado` e `/healthz` ok ([evidência](../../entrega/evidencias/us-37.md)) | João | S3 |
| 5 | Registrar demonstração visual do QR (US-22) | João | S3 |
| 6 | Manter checklist do Trello sincronizado com o merge, sem fechar por implementação | SM | contínuo |

## O que revisar na próxima retro

- As ações 1–5 foram concluídas com evidência (não com "está no código")?
- O fluxo QR foi demonstrado ponta-a-ponta com app e terminal reais?
- A medição de energia e a validação de câmera saíram do bloqueio?
- O fechamento antecipado da S3 repetiu o padrão de declarar carry-over explicitamente?
