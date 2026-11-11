# US-29 · validação no aparelho físico

Referência: [`us-29.md`](us-29.md), card US-29 e DT-12. Execução em **11/11/2026,
16:08–16:13 (America/Sao_Paulo)**, com um Motorola g86 5G (Android 15) conectado
por ADB. Esta é a primeira execução do fluxo **app → API → banco → comando** com
câmera e GPS do próprio aparelho.

## Ambiente

| Peça | Configuração |
|---|---|
| App | APK de debug (`br.fatec.errorsquad.controle_acesso`), `API_BASE_URL=http://localhost:3000` |
| Rede | `adb reverse tcp:3000 tcp:3000` — o aparelho alcança a API pela própria porta local |
| API | `node dist/main/server.js`, `ACCESS_MODE=real` |
| Worker | `node dist/main/mqtt-consumer.js` no mesmo host |
| Banco | PostgreSQL 17 em Docker (`127.0.0.1:5448`), migrations + seed |
| MQTT | Mosquitto em Docker (`127.0.0.1:1888`) |
| Terminal | simulado: publica `status online` (contrato v1) e recebe `terminals/terminal-01/qr` |
| QR exibido | página local em `127.0.0.1:8099`, tela cheia no monitor |

Nada foi alterado no código do app, da API ou do firmware para esta execução.

## Sequência observada

1. **Login** com a conta da seed (`usuario@abp4.local`) pela tela do aparelho —
   credenciais digitadas no celular, requisição para a API local.
2. **Sessão persistida**: app encerrado com `am force-stop` e reaberto; a Home
   voltou autenticada, sem pedir senha de novo.
3. **Leitura do QR**: a câmera do aparelho leu o QR exibido no monitor
   (`v1.terminal-01.<iat>.25.<hmac>`), o app mostrou “Lendo posição…” e enviou o
   pedido com a posição do GPS do aparelho.
4. **GRANTED** com **6,8 m** de distância do local.
5. **DENIED / OUT_OF_RANGE** com **1.207,9 m**: o local foi movido 1,2 km no banco
   e o mesmo QR foi lido outra vez.

Consulta ao banco depois das duas leituras:

```text
+----------+--------+---------+--------------+-------------+-----+
|  evento  | metodo | decisao |    motivo    | distancia_m | ack |
+----------+--------+---------+--------------+-------------+-----+
| b9c7bdbf | QR     | DENIED  | OUT_OF_RANGE | 1207.9      | -   |
| 345ff5c7 | QR     | GRANTED | -            | 6.8         | -   |
+----------+--------+---------+--------------+-------------+-----+
```

O traço em `ack` é esperado nestes dois eventos: o terminal que exibiu o QR é o
observador desta execução e não publica ACK; o comando foi gravado no outbox e
o caminho de ACK já é coberto pelo E2E e pela bancada NFC.

## Capturas

`capturas/app-android-login.png`, `app-android-home.png`,
`app-android-scanner.jpg`, `app-android-liberado.png` e
`app-android-negado.png` — capturadas com `adb exec-out screencap`, sem edição
além de redução de tamanho.

## O que passou a estar comprovado

- câmera real do aparelho lendo o QR do terminal;
- GPS real do aparelho no pedido, com distância calculada no backend;
- decisão `GRANTED` e `DENIED` refletidas na UI, com o motivo vindo da API;
- sessão persistida entre aberturas do app no Android;
- fluxo completo contra API, worker, banco e broker reais (locais).

## O que continua fora

- APK **release** e distribuição em loja; o build usado é o de debug.
- O `ack` do comando publicado para este terminal (o observador não responde).
- Celular e ESP32 físicos na mesma sessão: aqui o terminal é o simulador.
- Precisão de GPS em ambiente aberto e tempo de leitura em luz solar.
- US-24 (heartbeat) e US-25 (offline): o `status online` foi publicado pelo
  simulador, não pelo firmware.
