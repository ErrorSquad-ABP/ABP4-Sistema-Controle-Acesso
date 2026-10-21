# Evidência — US-08 (herança do protótipo) · 21/10/2026

Branch `feat/us-08-heranca-prototipo`, PR #19, commit de merge `10e978d`.

## Build e testes

- `pio run`: SUCCESS — RAM 14,1%, Flash 61,9%.
- 7 testes host: `retry`, `door`, `command`, `feedback`, `display`, `mqtt`, `mqtt command`.
- `wokwi-cli lint`: sem issues.
- CI: `ci-firmware-build` verde.

## Demo no Wokwi

- Terminal `terminal-dev-01` conectado ao Mosquitto (`New client connected ... as terminal-dev-01`).
- Comando `open` (JSON v1, `expiresAt` futuro): ACK `executed`; servo/LED verde/buzzer/LCD acionados.
- Comando `deny`: ACK `executed`; LED vermelho/buzzer de negado.
- Serial:

```text
SERIAL CONECTADO
[mqtt] comando 9bbcac24-af75-469a-a9ec-1043f9318d11: executed
[mqtt] comando 556dc7f2-088c-473b-89fa-b481b0d8da40: executed
```

- ACK observado em `terminals/terminal-dev-01/acks`:

```json
{"v":1,"messageId":"b9bccb92-2000-413b-a178-cf56b03f1617","terminalId":"terminal-dev-01","timestamp":"2026-10-21T20:08:48.000Z","commandId":"9bbcac24-af75-469a-a9ec-1043f9318d11","status":"executed"}
```

## Limites

- Servo é de rotação contínua: o Wokwi mostra o movimento, não uma posição angular real.
- Sem TLS e sem atuação física de porta; o escopo é o protótipo simulado.
