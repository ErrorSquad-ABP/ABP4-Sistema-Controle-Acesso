# Roteiro da apresentação final — US-36

Roteiro da apresentação da entrega final, depois da Review 3. Os slides ficam fora do repositório (decisão do time em 11/11) e entram aqui só como link. O conteúdo de cada bloco segue o [relatório](relatorio/README.md), e nada é mostrado como comprovado sem evidência na [matriz](matriz-requisitos.md).

| Item | Valor |
|---|---|
| Data, horário e local | _a confirmar no cronograma oficial_ |
| Duração | _a confirmar_; o roteiro abaixo tem **15 min** de fala e reserva o restante para perguntas |
| Slides | _link a preencher_ (não colocar o endereço do repositório nos slides, como no slide final da S2) |
| Commit apresentado | _preencher com o commit da `main` usado na demo_ |
| Vídeo do plano B | _link a preencher_ |

## Mensagem central

O servidor decide e registra todo acesso, por QR Code rotativo com geolocalização de 100 m e por NFC, e o terminal só exibe, lê e executa comandos válidos. Cada requisito aponta para uma evidência, e o que não foi comprovado é dito como lacuna.

## Blocos, tempos e divisão de fala

A divisão abaixo é uma **proposta** baseada em quem conduziu cada frente no repositório; o time confirma ou troca no primeiro ensaio.

| # | Bloco | Quem fala | Tempo | Acumulado | Slides |
|---|---|---|---|---|---|
| 1 | Abertura, equipe e problema | Felipe Pacheco (PO) | 1:30 | 1:30 | capa; problema; objetivo |
| 2 | Requisitos e critério de evidência | Felipe Pacheco | 1:30 | 3:00 | RF/RNF/RP em números; o que conta como prova |
| 3 | Arquitetura e fluxos QR e NFC | Carlos Santo | 2:00 | 5:00 | diagrama da US-35; fluxo QR; fluxo NFC |
| 4 | Demo ao vivo | Leo Silva (app) e Arthur Facchinetti (terminal) | 5:00 | 10:00 | um slide de transição com o que será mostrado |
| 5 | Qualidade, segurança e operação | Caio Araujo | 2:00 | 12:00 | CI e testes; revisão de segurança (US-33); nuvem |
| 6 | Processo, sprints e dificuldades | João Victor Lopes Rosa (SM) | 2:00 | 14:00 | linha do tempo S1–S3; lições |
| 7 | Resultados, lacunas e encerramento | João Victor Lopes Rosa | 1:00 | 15:00 | matriz resumida; lacunas; obrigado |

Regra de tempo: quem passar 30 s do seu bloco corta o último ponto, não acelera a fala. O bloco 4 tem prioridade; se a demo atrasar, os blocos 5 e 6 perdem 30 s cada.

### O que cada bloco precisa dizer

1. **Problema:** controle de acesso de baixo custo em edifícios; chave e cartão podem ser copiados ou emprestados e não deixam registro auditável. O edital pede terminal IoT e app móvel com backend em nuvem.
2. **Requisitos:** quantos RF, RNF e RP estão atendidos, parciais e não atendidos, com os números da matriz na data da apresentação. Explicar que código integrado, simulação e hardware real são provas diferentes.
3. **Arquitetura:** app → API por HTTPS; terminal ↔ worker por MQTT com TLS; o servidor é a única fonte de decisão. QR assinado de 25 s, geofence pelo menor valor entre o raio do local e 100 m, decisão, consumo do uso e comando na mesma transação, `requestId` contra repetição. NFC pelo hash do UID, sem lista local no terminal.
4. **Demo:** roteiro abaixo. Antes de cada passo, dizer se é real, simulado ou gravado.
5. **Qualidade:** CI das três frentes com os números do commit apresentado; E2E com broker e banco temporários; Dependabot, actions por SHA e CodeQL; achados e riscos aceitos da US-33. Operação: API na Vercel com Neon e worker no Render, sem afirmar disponibilidade contínua.
6. **Processo:** três sprints, card → branch → PR → evidência; o que deu errado (escopo declarado sem prova, bancada no fim da sprint, troca de broker) e o que o time mudou.
7. **Resultado:** o que ficou pronto e as lacunas declaradas (por exemplo abertura física, GPS e heartbeat do terminal, medição de energia, conforme o estado final da US-34).

## Demo

### Preparação (até 60 min antes)

- [ ] **Local da demo cadastrado com as coordenadas da sala** e raio de até 100 m, com uma autorização vigente para a conta de demonstração e usos disponíveis. Sem isso, o QR é negado por `OUT_OF_RANGE`.
- [ ] Terminal no mesmo local da demo (vínculo terminal → local) e credencial NFC cadastrada para a tag usada.
- [ ] Bateria cheia no celular, APK instalado, localização e câmera permitidas, sessão já feita uma vez.
- [ ] ESP32 alimentado, conectado ao Wi-Fi da sala e ao broker; hora SNTP sincronizada (o terminal não libera sem hora confiável).
- [ ] Servo: confirmar o estado final da US-34. Se o perfil físico ainda estiver com o servo desabilitado, a demo mostra **feedback**, não abertura, e isso é dito em voz alta.
- [ ] Rede da sala testada com o celular e com o ESP32; ter um roteador ou hotspot de reserva.
- [ ] Vídeo do plano B baixado no notebook (não depender da rede para tocar).

### Aquecimento (15 min antes)

- [ ] Abrir o `/health` da API duas vezes: a primeira chamada pode voltar 503 enquanto o Neon sai da suspensão.
- [ ] Abrir o `/healthz` do worker no Render, que dorme após 15 min sem tráfego HTTP.
- [ ] Conferir no EMQX o worker e o terminal conectados.
- [ ] Fazer uma leitura de teste por QR e uma por NFC e conferir os dois eventos no histórico.
- [ ] Se a apresentação for fora das 18h45–23h05, lembrar que o relay de recuperação da outbox está parado (DT-21); a publicação imediata de comandos não depende dele.

### Passo a passo (5 min)

| Tempo | Quem | Ação | O que deve aparecer | Se falhar |
|---|---|---|---|---|
| 0:00 | Leo | Abrir o app já logado e mostrar "Minhas autorizações" e o detalhe | autorização vigente com usos restantes | capturas do aparelho |
| 0:40 | Arthur | Mostrar o terminal exibindo o QR, que muda a cada 25 s | QR novo no display | vídeo do plano B |
| 1:10 | Leo | Ler o QR com o app dentro da sala | **Acesso liberado** no app; comando `open`, LED verde e ACK no terminal | repetir uma vez; depois vídeo |
| 2:00 | Leo | Mostrar a negativa: QR vencido (esperar 25 s com o app aberto) ou conta sem autorização | **Acesso negado** com o motivo em linguagem simples | captura da tela de negado |
| 2:50 | Arthur | Aproximar a tag NFC autorizada | LED verde e bipe agudo após o comando do servidor | vídeo do plano B |
| 3:30 | Arthur | Aproximar uma tag desconhecida | LED vermelho e bipe grave, sem atuação | vídeo do plano B |
| 4:10 | Leo | Abrir o histórico de acessos (admin) | as tentativas QR e NFC da demo, liberadas e negadas | consulta pronta no banco ou captura |
| 4:40 | Leo | Fechar: tudo que apareceu foi decidido e registrado pelo servidor | — | — |

Se a demo web da US-38 estiver publicada, ela entra só como link no slide final, sem tempo de fala.

### Plano B

Usar o vídeo quando a mesma etapa falhar duas vezes ou quando passar de 1 min parada. Quem estiver falando diz "vamos ver a gravação desta etapa, feita em _data_", sem improvisar o motivo. O vídeo precisa ter sido gravado com o mesmo commit e mostrar as mesmas etapas.

## Perguntas prováveis da banca

| Pergunta | Quem responde | Base da resposta |
|---|---|---|
| E se alguém fotografar o QR e mandar para outra pessoa? | Carlos | token de 25 s e geofence de 100 m; o QR sozinho não basta, precisa do login e da posição |
| O terminal funciona sem internet? | Arthur | não libera: sem rede, broker ou hora confiável, nega; resiliência offline é a US-25 |
| Por que MQTT e não HTTP no terminal? | Carlos | conexão bidirecional e persistente, QoS 1 para comandos, LWT para status; ADR 001 |
| Como garantem que um comando não abre duas vezes? | Arthur | `commandId` deduplicado, prazo de validade e comandos nunca retidos no broker |
| O que foi testado em hardware de verdade? | Arthur | evidências DT-06, US-23 e US-34; dizer o que não foi |
| Como o app atende o público idoso? | Leo | fonte do sistema em 2x sem estouro, contraste AA, textos simples (RNF04 e o que ficou parcial) |
| Quais riscos de segurança ficaram? | Caio | riscos residuais e aceites da US-33 |
| Como dividiram o trabalho? | João | Scrum, card → PR com revisão de outra pessoa, DoD |

## Ensaios cronometrados

Fazer pelo menos dois ensaios completos com cronômetro, o segundo com a demo real na rede que será usada. Registrar o tempo de cada bloco.

| Ensaio | Data | Presentes | B1 | B2 | B3 | B4 (demo) | B5 | B6 | B7 | Total | Ajustes combinados |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | | | | | | | | | | | |
| 2 | | | | | | | | | | | |

## Checklist final

- [ ] Divisão de fala confirmada no primeiro ensaio.
- [ ] Números dos slides iguais aos do relatório final e da matriz no commit apresentado.
- [ ] Dois ensaios registrados acima, o último dentro do tempo.
- [ ] Demo feita do começo ao fim pelo menos uma vez no local ou na rede da apresentação.
- [ ] Vídeo do plano B gravado e baixado.
- [ ] Nenhuma senha, token, UID completo ou URL com credencial nos slides, no vídeo ou na tela compartilhada.
