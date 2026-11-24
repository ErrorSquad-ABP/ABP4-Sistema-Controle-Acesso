# Review 3 — Documento de entrega final · Sprint 3

## 1. Identificação, equipe e links

- **Curso:** Desenvolvimento de Software Multiplataforma (4DSM) — FATEC Jacareí.
- **Projeto:** ABP 2026-2 · Sistema Integrado de Controle de Acesso.
- **Equipe:** ErrorSquad — João Victor Lopes Rosa (SM), Felipe Pacheco (PO), Carlos Santo, Caio Araujo, Leo Silva e Arthur Facchinetti.
- **Sprint 3:** 12 a 25/11/2026 · **Review:** 25/11/2026, 19h30 · **fechamento do trabalho:** 24/11/2026.
- **Documento principal:** [`relatorio/relatorio-abnt.pdf`](relatorio/relatorio-abnt.pdf) · **mídias:** [`midias/`](midias/) · **apresentação:** [`apresentacao/roteiro-apresentacao.md`](apresentacao/roteiro-apresentacao.md).

| Referência | Link |
|---|---|
| Repositório | [ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso) |
| Board | [ErrorSquad ABP 4DSM](https://trello.com/b/AxZZyPyN/errorsquad-abp-4dsm) |
| Design | [Figma](https://www.figma.com/design/nddGhlwJIi5rMzhvsK5Rkl) |
| API publicada | [/health](https://abp-4-sistema-controle-acesso.vercel.app/health) · [/docs](https://abp-4-sistema-controle-acesso.vercel.app/docs) |
| Demo web | [abp4-demo-web.vercel.app](https://abp4-demo-web.vercel.app) |
| Worker MQTT | [healthz](https://abp4-mqtt-worker.onrender.com/healthz) |

## 2. Objetivo e resultado

**Objetivo:** fechar o controle de acesso físico na bancada — QR, tag NFC e celular — com decisão auditável, e entregar a documentação final em ABNT.

O resultado é um fluxo real de ponta a ponta em bancada: o aplicativo lê o QR, envia a posição e mostra a decisão; o terminal lê tag e celular, executa o comando e confirma; a API decide, audita e publica; o worker mantém a mensageria. A demo web foi publicada e o relatório consolidou os requisitos com evidência ou lacuna declarada.

| Indicador | Resultado em 24/11/2026 |
|---|---|
| Testes do aplicativo | **664 aprovados**; análise sem problemas |
| Testes do backend | **450 aprovados** no merge do fluxo HCE |
| Firmware | Suite host (MQTT, TLS, NFC/HCE, display, servo, timing) e builds PlatformIO |
| CI | 6 checks obrigatórios, CodeQL e Dependabot |
| API | `/health` com `database: ok` |
| Worker | `/healthz` com `status: ok` |
| Demo web | Publicada e verificada no navegador |
| Hardware | QR, tag e HCE com `GRANTED` e ACK `executed` |
| Relatório | PDF de 35 páginas, sumário com páginas conferidas |

## 3. O que está no ar

- **API na Vercel:** contrato REST, autenticação JWT/RBAC, autorizações, locais, eventos, credenciais QR e NFC, com CORS por allowlist exata. A origem da demo web está liberada.
- **Worker MQTT no Render:** outbox, relay, deduplicação, presença por status/access-events e ACK; `/healthz` ok.
- **Banco no Neon:** migrations aplicadas; eventos e comandos persistidos.
- **Broker EMQX Cloud:** MQTT sobre TLS; o firmware valida o certificado.
- **Aplicativo Android:** login, autorizações, histórico, perfil, locais, administração, scanner QR e acesso por NFC/HCE.
- **Terminal ESP32:** OLED com QR, LCD de status, RC522 para tag e celular, servo posicional, LEDs e buzzer; heartbeat/LWT no firmware da `main`.
- **Demo web:** projeto Vercel separado, ícones da marca, aviso de limitações do navegador e CORS exato.

## 4. Entregas por card na Sprint 3

| Card | Entrega efetiva | Evidência |
|---|---|---|
| US-22 | QR de 41 dígitos inteiro no OLED, com margem e escala | PR #73 |
| US-23 | Tag NFC no RC522, MQTT, decisão e feedback | PR #67, `us-23-nfc-rc522.md` |
| US-24 | Heartbeat retained e LWT; GPS fora do escopo | PR #82, `us-24.md` |
| US-25 | Bloqueada por decisão do time; escopo preservado | card no Trello |
| US-33 | Revisão de segurança; PR em revisão por pares | PR #76, `us-33.md` |
| US-34 | QR, tag, HCE e servo em bancada | eventos/ACKs no banco |
| US-35 | Diagramas finais em Mermaid | PR #74 |
| US-36 | Relatório ABNT, mídias e roteiro | `relatorio/`, `midias/` |
| US-38 | Demo web e identidade publicadas | PR #75, `us-38.md` |

## 5. Qualidade e reprodução

### Preparação

Seguir os guias em `docs/guides/` e os READMEs de backend, mobile e firmware. Para o fluxo real, é preciso uma conta com autorização vigente, um terminal configurado e o broker acessível.

### Roteiro de demonstração

1. **API:** abrir `/health` e `/docs`; mostrar o contrato e a versão em operação.
2. **Aplicativo:** autenticar, mostrar autorizações e perfil.
3. **QR:** ler o QR do OLED, mostrar a decisão e o evento; repetir fora do raio para `OUT_OF_RANGE`.
4. **Tag:** encostar a tag, mostrar `GRANTED` e o ACK; mostrar o feedback no terminal.
5. **HCE:** abrir a tela de NFC, encostar o celular, mostrar o `GRANTED`; apresentar de novo para mostrar `INVALID_CREDENTIAL`.
6. **Operação:** mostrar o worker, o banco, o CI e a demo web com CORS.
7. **Limitações:** declarar GPS ausente, US-25 bloqueada, energia não medida e abertura física não demonstrada.

**São provas complementares:** o banco prova decisão e auditoria; o terminal prova leitura e atuação; o app prova o pedido e a interface; o CI prova build e testes. Nenhuma delas, isolada, prova uma cancela real.

## 6. O que não entrou e por quê

- **US-25 (resiliência offline):** bloqueada por decisão do time; mexe no caminho de reconexão e no NVS e não bloqueia a banca.
- **GPS do terminal:** módulo NEO-6M indisponível; o terminal não publica coordenada.
- **Abertura física de cancela:** o servo é acionado, mas o mecanismo real não foi acoplado.
- **Consumo elétrico:** DT-22 encerrada por escopo; nenhum valor medido.
- **US-33:** revisão registrada, PR em revisão por pares; aceites formais pendentes.
- **APK de release em loja:** a execução usou APK debug.

## 7. Dívida e prioridades

| Situação | Itens |
|---|---|
| Concluídas | DT-01 a DT-11, DT-13 a DT-21, DT-23, DT-24, DT-22 |
| Em revisão | US-24 (hardware), US-33 (PR) |
| Bloqueada | US-25 |
| Próximos passos | confirmar heartbeat, retomar US-25, aceites de segurança, cancela real e medição de energia |

## 8. Riscos residuais

| Risco | Tratamento |
|---|---|
| Reutilização de credencial | QR de 25 s; HCE de uso único e 60 s; hash no banco |
| Terminal comprometido | não decide acesso; só executa comando dentro do prazo e com hora confiável |
| Queda de rede | sem hora confiável não abre; fila offline postergada |
| Worker reiniciar | heartbeat/LWT implementado; confirmação no ESP32 pendente |
| Consumo desconhecido | orçamento e procedimento documentados |

## 9. Rastreabilidade

- [Relatório ABNT](relatorio/relatorio-abnt.pdf) · [fonte Markdown](relatorio/relatorio-abnt.md)
- [Matriz de requisitos](matriz-requisitos.md) · [índice de evidências](README.md)
- [Fechamento da Sprint 3](../scrum/sprints/sprint-3.md) · [review](../scrum/sprints/sprint-3-review.md) · [retro](../scrum/sprints/sprint-3-retro.md)
- [Diagramas](../architecture/visao-geral.md#diagramas-de-arquitetura)
