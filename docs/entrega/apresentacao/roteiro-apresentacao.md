# Roteiro da apresentação final — Sprint 3

**Duração alvo:** 20 minutos de apresentação + 10 minutos de perguntas.  
**Formato:** 6 falas curtas, demo ao vivo e uma lâmina de limitações.  
**Mídia de apoio:** `docs/entrega/midias/` e `docs/entrega/relatorio/relatorio-abnt.pdf`.

## Divisão de fala e tempo

| Bloco | Tempo | Quem | Conteúdo |
|---|---|---|---|
| 1. Problema e proposta | 2 min | Felipe (PO) | Chave/cartão não auditam; autorização temporária e registro de cada tentativa |
| 2. Arquitetura | 3 min | João (SM) | App, API, worker, terminal; decisão separada da atuação; MQTT e nuvem |
| 3. QR | 3 min | Carlos | QR de 25 s, leitura pelo app, geofence, decisão, evento e ACK |
| 4. NFC e HCE | 4 min | Caio | Tag física, prova efêmera no celular, uso único, leitura ISO-DEP e ajuste de 25 ms |
| 5. Operação e qualidade | 3 min | Leo | Deploy, CI, testes, worker, banco e demo web |
| 6. Resultados e limitações | 3 min | Arthur | O que foi comprovado, o que não foi, e o que fica como trabalho futuro |
| 7. Perguntas | 10 min | Todos | Respostas curtas, com evidência |

## Fala 1 — Problema (Felipe, 2 min)

- Controle por chave ou cartão fixo não permite revogar em tempo real nem auditar quem tentou.
- O desafio pede um terminal de acesso e um aplicativo que consulta autorizações e administra o sistema.
- Nossa proposta separa **decisão** (backend) de **atuação** (terminal). O terminal nunca decide sozinho.
- Critério de sucesso: um acesso real, registrado, com QR e NFC, e uma demo que qualquer pessoa consiga repetir.

## Fala 2 — Arquitetura (João, 3 min)

- Mostrar a Figura 1 (componentes) e a Figura 2 (implantação).
- App Flutter fala HTTPS com a API; API e worker compartilham domínio e banco; terminal fala MQTT.
- Banco no Neon; API na Vercel; worker no Render; broker EMQX com TLS.
- Destacar: a API grava evento, consome autorização e cria comando na mesma transação; o terminal só executa o comando decidido e devolve ACK.

## Fala 3 — QR (Carlos, 3 min)

- O QR é assinado, vale 25 s e é publicado a cada 20 s.
- O app lê, pega a posição e envia com `requestId` idempotente.
- Mostrar a Figura 6 (sequência) e um evento real: `GRANTED` com ACK `executed`.
- Mostrar o caso de falha: fora do raio, `DENIED` com `OUT_OF_RANGE`, sem comando.
- Se o QR estiver vencido, a decisão é negada; o token não é reaproveitável fora da janela.

## Fala 4 — NFC e HCE (Caio, 4 min)

- Tag física: UID normalizado, decisão no backend, feedback no terminal.
- Celular: o app pede uma prova de 128 bits na API; o banco guarda o hash; a prova vale 60 s e é consumida no primeiro acesso aceito.
- O firmware envia `SELECT AID`, recebe 16 bytes + `9000` e publica `nfc_hce_read`.
- Mostrar a Figura 7 (sequência) e o evento `GRANTED`.
- Demonstrar a segunda apresentação: `INVALID_CREDENTIAL`, sem gastar novo uso.
- Explicar o ajuste: o RC522 espera 25 ms; o Android levava mais na primeira conexão; a solução foi preparar o serviço HCE em primeiro plano e encurtar a resposta.

## Fala 5 — Operação e qualidade (Leo, 3 min)

- CI com seis checks obrigatórios, CodeQL e Dependabot.
- 664 testes do app; 450 do backend no merge do HCE; suite host do firmware.
- API `/health` com `database: ok`; worker `/healthz` ok; demo web publicada.
- Mostrar a demo web e o CORS exato; explicar que o navegador não tem NFC Android.

## Fala 6 — Resultados e limitações (Arthur, 3 min)

- O que foi comprovado: QR, tag, HCE, servo, evento e ACK; demo web; documentação e diagramas.
- O que não foi: GPS do terminal (módulo indisponível), fila offline (US-25 bloqueada), abertura de cancela real, consumo elétrico não medido.
- Por que declarar: evita prometer o que não foi testado; a matriz aponta evidência ou lacuna.
- Trabalho futuro: US-25, GPS, cancela real, aceites de segurança e medição de energia.

## Checklist da demo (antes de entrar)

- [ ] Terminal energizado, Wi-Fi/hotspot ligado e MQTT conectado.
- [ ] QR aparecendo no OLED e status no LCD.
- [ ] Celular desbloqueado, NFC ligado e app logado.
- [ ] Conta com autorização vigente no local da demo.
- [ ] API e worker respondendo (`/health` e `/healthz`).
- [ ] Tag física separada e visível.
- [ ] PDF do relatório e pasta de mídias abertos no notebook.
- [ ] Plano B: capturas da demo web, diagramas e eventos no banco.

## Perguntas prováveis

- **Por que não usar o UID do celular?** Porque o Android randomiza o UID e ele não é uma identidade autenticada. A prova HCE é emitida pela API, tem hash no banco e uso único.
- **O que acontece sem internet?** O terminal não executa comando sem hora confiável; a fila offline do firmware está planejada (US-25). O backend tem outbox e relay.
- **O servo abre uma porta?** O servo posicional é acionado e o feedback funciona; o mecanismo de uma cancela real não foi acoplado.
- **Por que o GPS do terminal não existe?** O módulo NEO-6M não estava disponível. A posição usada na decisão vem do app; não simulamos coordenada para não produzir evidência falsa.
- **O consumo é eficiente?** Há decisão de projeto e orçamento estimado; a medição não foi realizada. O requisito permanece parcial.
- **O que falta para produção?** Fila offline, aceites de segurança, hardening de rate limit, medição de energia e integração com o mecanismo físico.
