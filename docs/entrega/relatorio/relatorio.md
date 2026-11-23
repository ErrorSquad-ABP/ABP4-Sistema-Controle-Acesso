---
instituicao: Centro Estadual de Educação Tecnológica Paula Souza
faculdade: Faculdade de Tecnologia de Jacareí
curso: Curso Superior de Tecnologia em Desenvolvimento de Software Multiplataforma
autores: Arthur Facchinetti; Caio Araujo; Carlos Santo; Felipe Pacheco; João Victor Lopes Rosa; Leo Silva [PENDENTE: conferir os nomes completos de todos os autores]
titulo: Sistema integrado de controle de acesso
subtitulo: terminal IoT com QR Code rotativo e NFC, aplicativo móvel e backend em nuvem
natureza: Relatório técnico apresentado à Faculdade de Tecnologia de Jacareí como entrega final da Aprendizagem Baseada em Projetos (ABP) do 4º semestre do Curso Superior de Tecnologia em Desenvolvimento de Software Multiplataforma.
orientador: Avaliador: Prof. Leandro Toss Hoffmann. [PENDENTE: confirmar se a folha de rosto usa "Orientador" ou "Avaliador" e a titulação do professor]
local: Jacareí
ano: 2026
---

# RESUMO

Este relatório descreve o desenvolvimento de um sistema integrado de controle de acesso de baixo custo para edifícios, construído pela equipe ErrorSquad na Aprendizagem Baseada em Projetos do 4º semestre do curso de Desenvolvimento de Software Multiplataforma da Fatec Jacareí. O sistema combina três componentes: um terminal baseado no microcontrolador ESP32, que exibe um QR Code renovado a cada 25 segundos e lê etiquetas NFC; um aplicativo móvel em Flutter, que autentica o usuário, lê o QR Code e envia a posição do aparelho; e um backend em Node.js, Express e TypeScript, que concentra todas as decisões de acesso, registra as tentativas em PostgreSQL e conversa com o terminal por MQTT. O terminal nunca decide sozinho: a liberação só ocorre depois de um comando válido do servidor, e o acesso por QR Code exige que o usuário esteja a no máximo 100 metros do local. O trabalho foi conduzido em três sprints com Scrum, integração e entrega contínuas e testes automatizados no pipeline. A rastreabilidade entre os {{total}} requisitos do edital e as evidências versionadas no repositório é apresentada no Apêndice A, que distingue o que foi comprovado em software, em simulação e em hardware real. Os resultados incluem o fluxo de acesso por QR Code e por NFC implementados de ponta a ponta no servidor, a API publicada em nuvem e o aplicativo executado em aparelho físico; as principais lacunas são a abertura física da cancela, o GPS e o heartbeat do terminal e a medição de consumo de energia.

**Palavras-chave:** controle de acesso; Internet das Coisas; MQTT; QR Code; NFC.

# ABSTRACT

This report describes the development of a low-cost integrated access control system for buildings, built by the ErrorSquad team as the 4th-semester Project-Based Learning assignment of the Multiplatform Software Development program at Fatec Jacareí. The system combines three components: an ESP32-based terminal that displays a QR Code renewed every 25 seconds and reads NFC tags; a Flutter mobile application that authenticates the user, scans the QR Code and sends the device position; and a Node.js, Express and TypeScript backend that makes every access decision, records each attempt in PostgreSQL and talks to the terminal over MQTT. The terminal never decides on its own: access is granted only after a valid server command, and QR Code access requires the user to be within 100 meters of the location. The work was carried out in three Scrum sprints, with continuous integration and delivery and automated tests in the pipeline. Traceability between the {{total}} requirements of the assignment and the evidence stored in the repository is presented in Appendix A, which separates what was proven in software, in simulation and on real hardware. The results include QR Code and NFC access flows implemented end to end on the server, the API deployed in the cloud and the application running on a physical device; the main gaps are the physical gate opening, the terminal GPS and heartbeat and the energy consumption measurement.

**Keywords:** access control; Internet of Things; MQTT; QR Code; NFC.

# LISTA DE ABREVIATURAS E SIGLAS

| ABNT | Associação Brasileira de Normas Técnicas |
| ABP | Aprendizagem Baseada em Projetos |
| ACK | Confirmação de execução (*acknowledgement*) |
| API | Interface de programação de aplicações |
| CD | Entrega contínua (*continuous delivery*) |
| CI | Integração contínua (*continuous integration*) |
| DoD | Definição de pronto (*Definition of Done*) |
| DT | Dívida técnica (card do backlog) |
| E2E | Teste de ponta a ponta (*end to end*) |
| GPS | Sistema de posicionamento global |
| HMAC | Código de autenticação de mensagem baseado em *hash* |
| HTTPS | Protocolo de transferência de hipertexto seguro |
| IoT | Internet das Coisas |
| JWT | *JSON Web Token* |
| MQTT | *Message Queuing Telemetry Transport* |
| NFC | Comunicação por campo de proximidade |
| PR | *Pull request* |
| QoS | Qualidade de serviço |
| QR | *Quick Response* (código bidimensional) |
| RBAC | Controle de acesso baseado em perfis |
| REST | Transferência de estado representacional |
| RF | Requisito funcional |
| RNF | Requisito não funcional |
| RP | Restrição de projeto |
| TLS | Segurança da camada de transporte |
| UID | Identificador único da etiqueta NFC |
| US | História de usuário (*user story*) |
| UUID | Identificador universal único |

<!-- sumario -->

# 1 INTRODUÇÃO

O controle de acesso em edifícios residenciais e comerciais costuma depender de porteiros, chaves físicas ou cartões que podem ser copiados, emprestados ou perdidos. Soluções comerciais completas resolvem parte desses problemas, mas têm custo alto para condomínios pequenos e, em geral, não registram de forma auditável quem tentou entrar, quando e por qual meio.

O desafio proposto ao 4º semestre do curso de Desenvolvimento de Software Multiplataforma da Fatec Jacareí (Fatec Jacareí, 2026) pede um sistema integrado de controle de acesso de baixo custo, formado por um terminal de acesso com Internet das Coisas e por uma aplicação móvel, sustentados por um backend em nuvem. Este relatório apresenta a solução construída pela equipe ErrorSquad entre outubro e novembro de 2026.

## 1.1 Objetivos

O objetivo geral é desenvolver um sistema que libere ou negue o acesso de pessoas a um local a partir de duas credenciais, um QR Code rotativo lido pelo celular e uma etiqueta NFC aproximada do terminal, com toda decisão tomada e registrada pelo servidor.

Os objetivos específicos são:

- construir um terminal com ESP32 que exiba o QR Code, leia etiquetas NFC e sinalize o resultado com luz, som e acionamento da abertura;
- construir um aplicativo móvel para o usuário consultar suas autorizações e ler o QR Code, e para o administrador gerenciar usuários, locais e autorizações;
- construir um backend que valide credenciais, autorizações e distância ao local, registre todas as tentativas e envie comandos ao terminal;
- publicar o backend em nuvem com integração e entrega contínuas e testes automatizados no pipeline;
- manter a rastreabilidade entre cada requisito do edital e uma evidência verificável no repositório.

## 1.2 Organização do relatório

A seção 2 apresenta o problema e o escopo. A seção 3 resume os requisitos e o critério usado para declarar um requisito atendido. A seção 4 descreve a arquitetura, e a seção 5, o desenvolvimento por sprint. As seções 6 e 7 trazem os resultados e as dificuldades, e a seção 8 conclui o trabalho. O Apêndice A reproduz a matriz de rastreabilidade de requisitos e o Apêndice B, o índice de evidências por card. O documento segue as normas de apresentação de trabalhos acadêmicos, citações e referências da ABNT (Associação Brasileira de Normas Técnicas, 2011, 2018, 2023).

# 2 PROBLEMA E CONTEXTO

## 2.1 O desafio proposto

O edital descreve dois componentes visíveis ao usuário. O **terminal de acesso** fica junto à porta ou catraca, exibe um QR Code gerado pelo servidor e trocado periodicamente, lê etiquetas NFC e sinaliza a liberação ou a negação. A **aplicação móvel** é usada pelos moradores e visitantes para consultar as próprias autorizações e ler o QR Code, e também pelo administrador para gerenciar usuários e autorizações (Fatec Jacareí, 2026).

Uma autorização liga uma pessoa a um local por um período e um número máximo de usos. O acesso por QR Code só pode ser liberado se o celular estiver a até 100 metros do local, o que impede que um QR Code fotografado e repassado seja usado à distância. Toda tentativa, liberada ou negada, deve ficar registrada.

## 2.2 Escopo e premissas

A equipe adotou as seguintes premissas, registradas na matriz de requisitos (Apêndice A):

- o servidor é a única fonte de decisão; o terminal só exibe, lê e executa comandos válidos, e não guarda lista local de etiquetas autorizadas;
- a abertura pode ser física ou simulada, como permite o edital; neste projeto ela é representada por um servomotor;
- a administração é uma função do aplicativo móvel; o edital não pede painel web administrativo, e a demonstração web prevista na US-38 é uma entrega adicional da equipe;
- a autorização é um intervalo contínuo entre data e hora de início e de fim, e não uma janela diária repetida; essa leitura do requisito RF03 ficou registrada como ponto a confirmar com o professor.

# 3 REQUISITOS

Os requisitos foram extraídos do edital e organizados em {{RF.total}} requisitos funcionais (RF), {{RNF.total}} não funcionais (RNF) e {{RP.total}} restrições de projeto (RP). A matriz completa, com o status e a evidência de cada item, está no Apêndice A e é mantida no repositório em `docs/entrega/matriz-requisitos.md`; os números desta seção são calculados a partir dela na geração deste documento.

## 3.1 Critério de evidência

Um requisito só é declarado **Atendido** quando a matriz aponta para uma evidência verificável: arquivo do repositório, PR integrado, teste automatizado ou registro de execução. Os demais status são **Parcial** (parte comprovada e lacuna declarada), **Não atendido** e **Não comprovado** (sem evidência no repositório). A equipe trata como provas diferentes o código integrado, a simulação (Wokwi e terminal simulado no teste E2E) e a execução em hardware ou aparelho real, e o texto deste relatório não usa uma como substituta da outra.

## 3.2 Requisitos funcionais

Os requisitos funcionais cobrem o cadastro de usuários com três perfis (administrador, condômino e visitante) e de locais de acesso; a criação, a consulta com filtros e o cancelamento de autorizações; a autenticação no aplicativo; a leitura do QR Code pelo aplicativo e do NFC pelo terminal; a validação de cada credencial pelo servidor, incluindo a geolocalização de até 100 metros para o QR Code; a liberação ou negação com sinalização; e o registro de toda tentativa.

Na revisão mais recente da matriz, {{RF.atendido}} dos {{RF.total}} requisitos funcionais estão atendidos e {{RF.parcial}} parciais ({{RF.lista.parcial}}); não atendidos: {{RF.lista.nao_atendido}}.

## 3.3 Requisitos não funcionais e restrições de projeto

Os requisitos não funcionais tratam da arquitetura com dispositivo IoT, backend em Node.js com TypeScript, API REST e aplicativo móvel; de segurança das comunicações e dos dados; de resiliência a falhas de conexão; de acessibilidade para o público idoso; de modularidade; de banco de dados em nuvem; de eficiência energética do dispositivo; e de integração e entrega contínuas com testes e feedback no pipeline. As restrições de projeto fixam Node.js, Express e TypeScript no backend, MQTT ou HTTP como protocolo IoT, aplicativo móvel, arquitetura cliente-servidor, desenvolvimento incremental por sprint, documentação de arquitetura, deploy automatizado em nuvem e uso de contêineres.

Dos {{RNF.total}} requisitos não funcionais, {{RNF.atendido}} estão atendidos e {{RNF.parcial}} parciais ({{RNF.lista.parcial}}). Das {{RP.total}} restrições de projeto, {{RP.atendido}} estão atendidas e {{RP.parcial}} parciais ({{RP.lista.parcial}}).

# 4 ARQUITETURA

## 4.1 Visão geral

O sistema é dividido em quatro processos que conversam por rede, conforme o Quadro 1. O aplicativo fala com a API por HTTPS; o terminal fala com o backend por MQTT, nos dois sentidos, por meio de um *broker*. A API roda em ambiente *serverless* e não mantém conexões longas, por isso um processo separado (o *worker* MQTT) assina os tópicos dos terminais e publica o QR Code rotativo.

Quadro: Componentes do sistema {larguras=3.2,6.4,6.4}
| Componente | Tecnologia | Responsabilidade |
|---|---|---|
| Terminal de acesso | ESP32, Arduino/PlatformIO, leitor RC522, OLED/LCD, LED RGB, *buzzer* e servomotor | Exibir o QR Code, ler o UID da etiqueta NFC, executar comandos válidos e confirmar a execução (ACK) |
| Aplicativo móvel | Flutter (Android), Riverpod, go_router, `mobile_scanner`, `geolocator`, armazenamento seguro | Login, minhas autorizações, leitura do QR Code com posição, resultado e telas de administração |
| API REST | Node.js 24, Express 5, TypeScript, Zod, Prisma 7, JWT | Autenticação, cadastros, autorizações, decisão do acesso por QR Code e histórico |
| *Worker* MQTT | Mesmo código do backend, `mqtt.js` 5 | QR Code rotativo, decisão NFC, *outbox* de comandos, deduplicação e correlação de ACK |
| Banco de dados | PostgreSQL | Usuários, locais, terminais, credenciais, autorizações, eventos de acesso e comandos |
| *Broker* MQTT | Mosquitto (desenvolvimento) e EMQX Cloud com TLS (produção) | Entrega das mensagens entre terminal e backend |
Fonte: Elaborado pelos autores a partir de `docs/architecture/visao-geral.md`, `backend/package.json`, `mobile/pubspec.yaml` e `firmware/platformio.ini`.

Figura: Arquitetura do sistema [PENDENTE: inserir abaixo desta legenda o diagrama final de arquitetura da US-35 (imagem em figuras/) e a linha Fonte]

## 4.2 Contratos de comunicação

O contrato REST é descrito em OpenAPI 3.1 e servido pela própria API em `/docs`. O contrato MQTT v1 (`docs/architecture/contratos-mqtt.md`) define cinco tópicos por terminal, resumidos no Quadro 2, sobre o protocolo MQTT 3.1.1 (OASIS, 2014). Toda mensagem carrega versão, `messageId` (UUID), identificador do terminal e instante em UTC; o consumidor descarta mensagens fora do contrato e deduplica pelo `messageId` (Davis; Peabody; Leach, 2024).

Quadro: Tópicos MQTT por terminal {larguras=5.4,3.0,2.4,5.2}
| Tópico | Sentido | QoS | Conteúdo |
|---|---|---|---|
| `terminals/{id}/qr` | backend → terminal | 0 | QR Code rotativo; perder um token é irrelevante porque outro chega em seguida |
| `terminals/{id}/access-events` | terminal → backend | 1 | Tentativa de acesso por NFC (UID lido) |
| `terminals/{id}/status` | terminal → backend | 1, retido | *Heartbeat* e mensagem de última vontade (LWT) |
| `terminals/{id}/commands` | backend → terminal | 1, nunca retido | Comando `open` ou `deny`, com `commandId` e prazo de validade |
| `terminals/{id}/acks` | terminal → backend | 1 | Confirmação de execução correlacionada ao `commandId` |
Fonte: Elaborado pelos autores a partir de `docs/architecture/contratos-mqtt.md`.

Comandos nunca são retidos no *broker*, porque um comando antigo entregue a um terminal que reconecta poderia abrir a porta fora de hora. O terminal recusa comandos vencidos ou repetidos e responde com o ACK correspondente, sem repetir a atuação.

## 4.3 Fluxo de acesso por QR Code

O *worker* gera, para cada terminal, um token no formato `v1.<terminal>.<iat>.<ttl>.<assinatura>`, válido por 25 segundos e assinado com HMAC-SHA-256 (Krawczyk; Bellare; Canetti, 1997) sobre os quatro primeiros campos, com a assinatura truncada em 96 bits. Para o display OLED de 128 por 64 pixels, um formato compacto opcional, ligado por configuração, codifica num número de 41 dígitos o código curto do terminal, o instante de emissão e a mesma assinatura de 96 bits; o identificador completo do terminal continua dentro do cálculo do HMAC, e os dígitos cabem num QR Code de versão 1 no modo numérico. O terminal apenas exibe o token. O fluxo segue os passos abaixo.

1. O usuário lê o QR Code com o aplicativo, que obtém a posição atual do aparelho.
2. O aplicativo envia à API o token, o identificador do terminal, a posição e um `requestId` gerado por tentativa, autenticado pelo JWT do login (Jones; Bradley; Sakimura, 2015).
3. A API valida a assinatura, o terminal e a validade do token; resolve o local do terminal; busca uma autorização vigente, não cancelada e com usos disponíveis; e calcula a distância entre o aparelho e o local pela fórmula de *haversine* (Sinnott, 1984).
4. A distância máxima é o menor valor entre o raio cadastrado do local e 100 metros; o banco de dados também restringe o raio a valores de 1 a 100 metros.
5. A decisão, o evento de acesso, o consumo de um uso da autorização e a intenção de comando são gravados na mesma transação. Repetir o mesmo `requestId` devolve o mesmo evento e não consome outro uso.
6. O comando é publicado no tópico do terminal, que aciona a abertura e a sinalização e devolve o ACK.

Uma negativa é uma resposta válida da API (`decision: DENIED`, com o motivo), e não um erro HTTP, para que o aplicativo mostre ao usuário a orientação adequada, como "fora do alcance" ou "QR expirado".

## 4.4 Fluxo de acesso por NFC

O terminal lê o UID da etiqueta pelo leitor RC522, gera uma única tentativa por aproximação e publica a tentativa no tópico de eventos com QoS 1. O *worker* resolve o terminal e o local, procura a credencial pelo *hash* do UID, valida a autorização com as mesmas regras de vigência e usos, grava o evento e publica o comando `open` ou `deny`. O NFC não exige GPS do celular; a geolocalização é aplicada ao QR Code. Sem rede, sem hora confiável ou sem leitor, o terminal não libera o acesso.

## 4.5 Organização do backend

O backend segue uma arquitetura em camadas inspirada na arquitetura limpa (Martin, 2018): `domain` contém regras e portas (interfaces) puras; `application` contém os casos de uso; `infrastructure` implementa as portas com Prisma, MQTT e relógio; e `main` monta tudo e expõe as rotas Express. A regra de dependência entre camadas é verificada pelo *linter* no CI, de modo que um *import* na direção errada quebra o *build*. O mesmo caso de uso de decisão atende ao QR Code (pela API) e ao NFC (pelo *worker*).

## 4.6 Infraestrutura e implantação

A decisão de provisionamento está registrada no ADR 001 (`docs/architecture/adr/001-provisionamento-vercel-neon.md`). A API é publicada na Vercel e o banco PostgreSQL fica no Neon, ambos em planos gratuitos. O *worker* MQTT foi preparado para o Render. O *broker* de produção passou do HiveMQ Cloud para o EMQX Cloud em 05/11/2026, depois do encerramento do plano gratuito do primeiro, e exige TLS na porta 8883; o firmware embute o certificado da autoridade raiz e valida o nome do servidor (DT-06). Para economizar a cota do banco, o *polling* de recuperação da *outbox* roda apenas entre 18h45 e 23h05 no horário de Brasília (DT-21), sem bloquear a publicação imediata de comandos.

No desenvolvimento, o Docker Compose sobe o Mosquitto e o PostgreSQL, e o backend tem `Dockerfile` próprio. O terminal pode ser executado no simulador Wokwi ou em uma placa ESP32 real, com perfis de compilação separados.

# 5 DESENVOLVIMENTO POR SPRINT

## 5.1 Processo

A equipe de seis pessoas aplicou o Scrum (Schwaber; Sutherland, 2020) de forma enxuta: *planning* no início de cada sprint, *review* nas datas oficiais e retrospectiva logo depois. João Victor Lopes Rosa atuou como *Scrum Master* e Felipe Pacheco como *Product Owner*; todos os integrantes desenvolveram. O backlog oficial está em `docs/scrum/product-backlog.md`, com 39 histórias em seis épicos (fundação, backend, terminal, aplicativo, integração e confiabilidade, documentação e entrega), e o Trello foi usado como quadro vivo.

Cada card virou uma *branch* e um PR com a linha `Card: US-XX`, que uma automação usa para vincular o PR ao card. O *merge* na `main` exige revisão de outra pessoa e CI verde. A definição de pronto (`docs/scrum/definition-of-done.md`) pede critérios de aceite atendidos, revisão, CI verde, testes do escopo, documentação atualizada, demonstração na *review* e nenhum segredo versionado.

Quadro: Calendário das sprints {larguras=2.6,3.8,4.8,4.8}
| Sprint | Janela | Foco | Fechamento |
|---|---|---|---|
| Sprint 1 | 15/10 a 21/10/2026 | Fundação e esqueleto ponta a ponta simulado | 13 de 13 histórias, sem *carry-over* |
| Sprint 2 | 22/10 a 11/11/2026 | Fluxo QR real, administração na API e deploy | 11 de 13 histórias em 10/11; US-28 e US-29 concluídas em 11/11 (PRs #55 e #69) |
| Sprint 3 | 12/11 a 25/11/2026 | NFC, geolocalização, histórico, qualidade e acabamento | [PENDENTE: preencher após a Review 3 de 25/11] |
| Entrega final | 26/11/2026 até a data oficial | Relatório, apresentação e ajustes finais | — |
Fonte: `docs/scrum/README.md`, `docs/entrega/review-1.md` e `docs/entrega/review-2.md`.

## 5.2 Sprint 1: fundação

O objetivo foi colocar a fundação no ar e fazer os três esqueletos conversarem de forma simulada. A sprint entregou o monorepo, CI para as três frentes, contratos REST (OpenAPI) e MQTT v1, modelo de dados com *migration* e dados de demonstração, API publicada na Vercel com o banco no Neon, o esqueleto do firmware conectando ao Mosquitto no Wokwi com comando e ACK, e o esqueleto do aplicativo com *login* simulado, leitura de QR Code e permissão de localização. No fechamento havia 122 testes de backend e 33 de mobile, e 19 PRs integrados. O resultado era uma fundação demonstrável, sem autenticação real nem decisão de acesso (`docs/entrega/review-1.md`).

## 5.3 Sprint 2: fluxo QR real e administração

O objetivo foi o fluxo QR real ponta a ponta, a administração na API e um deploy seguro. A sprint entregou autenticação JWT com perfis, cadastro de usuários e autorizações, a credencial QR assinada, a decisão de acesso com geolocalização de 100 metros e consumo da autorização na mesma transação, o histórico de eventos, o *worker* com *outbox*, deduplicação e correlação de ACK, o *login* real no aplicativo e o TLS no firmware validado numa placa ESP32 contra o EMQX. Também foram fechadas 22 das 24 dívidas técnicas abertas na auditoria de 02/11/2026. O fechamento de 10/11 registrou 11 de 13 histórias, 28 PRs na sprint, 458 testes de backend, 93 de mobile e 29 cenários E2E (`docs/entrega/review-2.md`).

Ainda dentro da janela da sprint, entre 10/11 e 11/11/2026, foram integrados o envio da leitura do QR Code pelo aplicativo com a tela de resultado (US-29, PR #55), o QR Code compacto no display OLED do terminal (PRs #63 e #64), a leitura NFC com o RC522 e o *feedback* da decisão (US-23, PR #67) e as telas do aplicativo fiéis ao protótipo do Figma, com minhas autorizações, perfil, cadastro de locais e administração de autorizações e de usuários (PR #69). Com isso, US-28 e US-29 foram concluídas em 11/11, e o aplicativo foi executado num aparelho Android no mesmo dia (`docs/entrega/evidencias/us-29-aparelho.md`).

## 5.4 Sprint 3: NFC, qualidade e acabamento

A Sprint 3 começou em 12/11/2026 com as histórias US-24 (GPS e *heartbeat*), US-25 (resiliência do terminal), US-33 (revisão de segurança), US-34 (teste em hardware real), US-35 (diagramas finais) e US-38 (demonstração web), além da validação das histórias integradas no fim da Sprint 2. Em 23/11/2026 foi integrado o PR #73, com o QR Code numérico compacto para o OLED e a atualização da matriz de requisitos e das evidências de 11/11 (aplicativo em aparelho e *worker* no Render). A revisão de segurança (US-33) estava em andamento numa *branch* própria.

[PENDENTE: descrever o resultado da Sprint 3 depois da Review 3 de 25/11 — histórias concluídas, PRs, números de teste e o que ficou de fora, com base em docs/scrum/sprints/sprint-3.md e no documento de review da S3]

## 5.5 Dívida técnica

As auditorias de estado (`docs/entrega/auditoria-estado-atual.md`) transformaram divergências entre o que estava declarado e o que estava comprovado em cards de dívida técnica (DT-01 a DT-24). Entre elas estão a decisão real no *worker* com deduplicação persistente (DT-01 a DT-03), o TLS com validação de certificado no firmware (DT-06), o CORS por lista exata de origens (DT-08), as *migrations* aplicadas pelo CD (DT-09), o APK gerado no CI (DT-10), a *outbox* de comandos (DT-13), o orçamento de conexões do banco (DT-14), a retenção e os prazos da deduplicação (DT-15 e DT-16), o teto de 100 metros no banco (DT-23) e as *actions* do GitHub fixadas por SHA com Dependabot (DT-24). Permaneceram abertas a validação da câmera e do APK em aparelho (DT-12) e a medição de energia (DT-22), ambas dependentes da bancada de hardware.

# 6 RESULTADOS

## 6.1 Atendimento dos requisitos

Pela matriz de rastreabilidade (Apêndice A), dos {{total}} requisitos e restrições, {{total.atendido}} estão atendidos, {{total.parcial}} parciais, {{total.nao_atendido}} não atendidos e {{total.nao_comprovado}} não comprovados. Cada linha da matriz aponta para a evidência que sustenta o status ou declara a lacuna; o gerador deste documento recusa a versão final se alguma linha estiver sem evidência ou se um requisito atendido não citar arquivo, PR ou card verificável.

[PENDENTE: regenerar este documento depois de integrar a US-33, que muda o RNF02, e as demais histórias da Sprint 3]

## 6.2 Qualidade e testes

Todo PR passa pelos *workflows* de CI das três frentes, que executam *lint*, verificação de tipos, testes e *build*. O Quadro 4 resume a última execução do CI na `main` de referência deste documento.

Quadro: Testes automatizados no CI da `main` (commit `0fb1292`, execução de 23/11/2026) {larguras=3.0,7.0,6.0}
| Frente | O que roda | Resultado |
|---|---|---|
| Backend | Vitest: unitários e integração com PostgreSQL | 485 testes em 56 arquivos, todos aprovados |
| Backend (E2E) | API, *worker*, PostgreSQL e *broker* temporários, terminal simulado | 31 cenários aprovados |
| Mobile | `dart format`, `flutter analyze`, `flutter test` e geração do APK | 651 testes aprovados |
| Firmware | 18 programas de teste no *host* com `-Werror` e *builds* PlatformIO dos perfis físico e Wokwi | Todos aprovados (execução do PR #73, com firmware idêntico ao da `main`) |
Fonte: GitHub Actions, execuções 45235904078, 45235903946 e 45231886579.

Além dos testes, o repositório usa CodeQL, Dependabot semanal para *actions*, npm e pub, e *actions* fixadas por SHA. [PENDENTE: atualizar o Quadro 4 com a execução do CI no commit final da entrega]

## 6.3 Operação em nuvem

A API está publicada na Vercel com o banco no Neon, e o CD aplica as *migrations* antes de cada implantação e verifica o `/health`. Em 23/11/2026, o `/health` de produção respondeu 503 com `database: unavailable` na primeira chamada, compatível com a suspensão automática do Neon, e `status: ok` com `database: ok` nas chamadas seguintes. Nessas chamadas, a resposta ainda informava `version: dev`, e não um commit. No mesmo dia, o CD do commit `0fb1292` falhou na primeira tentativa ao aplicar a *migration* do QR Code compacto, porque a coluna já existia no banco de produção; depois da correção, a execução 45235904111 foi repetida com sucesso, e o `/health` passou a responder `version: 0fb1292` com `database: ok`. O episódio mostra o risco de alterar o esquema de produção por fora do pipeline, já apontado na falta de um ambiente de homologação (seção 7).

O *worker* MQTT no Render foi observado no ar em 11/11/2026, conectado ao EMQX por TLS e com o `/healthz` respondendo (`docs/entrega/evidencias/us-37.md`). Nenhuma das observações mede disponibilidade contínua.

## 6.4 Validação em hardware e em aparelho

As evidências físicas registradas até 23/11/2026 são:

- TLS do firmware numa placa ESP32 contra o EMQX, incluindo a recusa de certificado errado e de conexão por IP (`docs/entrega/evidencias/dt-06.md`);
- leitura NFC com o RC522 numa placa ESP32, com uma tentativa negada para etiqueta desconhecida e duas liberadas após o cadastro da credencial, cada uma correlacionada a evento, comando e ACK no banco; nessa montagem o servomotor estava desabilitado, então o ACK confirma o *feedback*, e não a abertura (`docs/entrega/evidencias/us-23-nfc-rc522.md`);
- aplicativo executado manualmente num aparelho Android 15, em 11/11/2026, com *login*, autorizações, leitura de um QR Code exibido num monitor, perfil, cadastro de local conferido no banco e telas de administração (`docs/entrega/evidencias/us-29-aparelho.md`).

Não há, até esta data, demonstração registrada do fluxo completo com o aplicativo lendo o QR Code no display do terminal real e o servomotor abrindo, nem medição de corrente ou de continuidade do terminal (RNF07). Essas validações pertencem à US-34. [PENDENTE: incluir os resultados da US-34 (hardware real), com data, montagem e evidência, ou declarar que não foram realizados]

# 7 DIFICULDADES E LIÇÕES APRENDIDAS

As retrospectivas das sprints 1 e 2 (`docs/scrum/sprints/`) registraram as dificuldades abaixo e o que a equipe mudou por causa delas.

- **Escopo parcial apresentado como completo.** Na Sprint 1, um PR anunciou mais do que entregava, e cards chegaram a "Concluído" com o *checklist* vazio. A equipe passou a separar código integrado, simulação e prova física em toda evidência e a manter o *checklist* do Trello junto com o *merge*.
- **Dependência de bancada.** NFC, GPS, servomotor, câmera e medição de energia dependiam do hardware montado e de instrumentos, o que concentrou os bloqueios no fim de cada sprint. A resposta foi isolar o hardware atrás de interfaces testáveis no *host* e no Wokwi e reunir as validações físicas numa história própria (US-34).
- **Backend pronto não é fluxo pronto.** Na Sprint 2, o fluxo QR completo no servidor criou a impressão de que o acesso funcionava, mas o aplicativo ainda não enviava a leitura. Os documentos de *review* passaram a declarar o *carry-over* de forma explícita.
- **Divergências encontradas só na auditoria.** O teto de 100 metros e a fixação das *actions* por SHA estavam declarados, mas incompletos, e só apareceram na conferência de 02/11/2026; viraram as dívidas DT-23 e DT-24.
- **Infraestrutura gratuita muda durante o projeto.** O encerramento do plano gratuito do HiveMQ obrigou a troca do *broker* de produção para o EMQX no meio da Sprint 2; os limites dos planos gratuitos também motivaram a janela do *relay* e o orçamento de conexões.
- **Sem ambiente de homologação.** CORS e *migrations* só puderam ser comprovados em produção, depois do *merge*, o que exigiu pré-verificações no banco antes de aplicar mudanças de esquema.

[PENDENTE: acrescentar as dificuldades e ações da retrospectiva da Sprint 3]

# 8 CONCLUSÃO

O projeto entregou um sistema de controle de acesso em que o servidor decide e registra todas as tentativas, por QR Code rotativo com geolocalização e por NFC, com o terminal limitado a exibir, ler e executar comandos válidos. A arquitetura em camadas, os contratos versionados e os testes no pipeline permitiram que seis pessoas trabalhassem em paralelo no firmware, no aplicativo e no backend sem perder a rastreabilidade entre requisito, card, PR e evidência.

O principal aprendizado da equipe foi tratar evidência como parte da entrega: o que foi comprovado em software, em simulação e em hardware real aparece separado, e as lacunas ficam declaradas em vez de escondidas. As lacunas mais relevantes no fechamento deste documento são a abertura física pela cancela, o GPS e o *heartbeat* do terminal, a resiliência offline do firmware e a medição de consumo de energia.

Como trabalhos futuros, a equipe aponta a conclusão dessas validações físicas, a janela diária de horário nas autorizações, a revogação de sessões JWT no servidor, um ambiente de homologação separado da produção e a publicação de uma versão assinada do aplicativo.

[PENDENTE: revisar a conclusão com o resultado final da Sprint 3 e da US-34]

# REFERÊNCIAS

ASSOCIAÇÃO BRASILEIRA DE NORMAS TÉCNICAS. **NBR 6023**: informação e documentação: referências: elaboração. 2. ed. Rio de Janeiro: ABNT, 2018.

ASSOCIAÇÃO BRASILEIRA DE NORMAS TÉCNICAS. **NBR 10520**: informação e documentação: citações em documentos: apresentação. Rio de Janeiro: ABNT, 2023.

ASSOCIAÇÃO BRASILEIRA DE NORMAS TÉCNICAS. **NBR 14724**: informação e documentação: trabalhos acadêmicos: apresentação. 3. ed. Rio de Janeiro: ABNT, 2011.

ERRORSQUAD. **ABP4-Sistema-Controle-Acesso**: repositório do sistema integrado de controle de acesso. [*S. l.*]: GitHub, 2026. Disponível em: https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso. Acesso em: 23 nov. 2026.

DAVIS, K.; PEABODY, B.; LEACH, P. **RFC 9562**: Universally Unique IDentifiers (UUIDs). [*S. l.*]: Internet Engineering Task Force, 2024. Disponível em: https://www.rfc-editor.org/rfc/rfc9562. Acesso em: 23 nov. 2026.

FATEC JACAREÍ. **Desafio 4DSM - 2026-2**. Jacareí: Faculdade de Tecnologia de Jacareí, 2026. Documento de orientação da Aprendizagem Baseada em Projetos, versão de 31 ago. 2026. [PENDENTE: conferir título e responsável exatos no PDF do edital]

JONES, M.; BRADLEY, J.; SAKIMURA, N. **RFC 7519**: JSON Web Token (JWT). [*S. l.*]: Internet Engineering Task Force, 2015. Disponível em: https://www.rfc-editor.org/rfc/rfc7519. Acesso em: 23 nov. 2026.

KRAWCZYK, H.; BELLARE, M.; CANETTI, R. **RFC 2104**: HMAC: keyed-hashing for message authentication. [*S. l.*]: Internet Engineering Task Force, 1997. Disponível em: https://www.rfc-editor.org/rfc/rfc2104. Acesso em: 23 nov. 2026.

MARTIN, R. C. **Clean architecture**: a craftsman's guide to software structure and design. Boston: Prentice Hall, 2018.

OASIS. **MQTT version 3.1.1**. Edição de Andrew Banks e Rahul Gupta. [*S. l.*]: OASIS, 2014. Disponível em: https://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html. Acesso em: 23 nov. 2026.

SCHWABER, K.; SUTHERLAND, J. **The Scrum Guide**: the definitive guide to Scrum: the rules of the game. [*S. l.*]: Scrum.org, 2020. Disponível em: https://scrumguides.org/scrum-guide.html. Acesso em: 23 nov. 2026.

SINNOTT, R. W. Virtues of the haversine. **Sky and Telescope**, Cambridge, v. 68, n. 2, p. 159, 1984.

# APÊNDICE A — MATRIZ DE RASTREABILIDADE DE REQUISITOS

A matriz abaixo é lida de `docs/entrega/matriz-requisitos.md` no momento em que este documento é gerado. Os caminhos de arquivo são relativos à raiz do repositório, exceto os arquivos de evidência, que ficam em `docs/entrega/evidencias/`, e os números precedidos de # são PRs do repositório do projeto (ErrorSquad, 2026).

<!-- matriz -->

# APÊNDICE B — ÍNDICE DE EVIDÊNCIAS POR CARD

Cada evidência registra o que foi verificado, como reproduzir, o que não foi verificado e os PRs envolvidos. Os arquivos ficam em `docs/entrega/evidencias/`.

<!-- evidencias -->
