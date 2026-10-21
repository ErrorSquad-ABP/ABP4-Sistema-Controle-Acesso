# Evidência — US-07 (esqueleto do firmware) · 21/10/2026

Validação executada localmente no fechamento da Sprint 1, na branch `feat/us-07-esqueleto-firmware` (commit `268637f`).

## Build (PlatformIO)

- PlatformIO Core 6.2.0 · Python 3.14 · ESP32 DevKit C v4
- `pio run`: **SUCCESS em 154,87 s**
- RAM: 44.808 / 327.680 bytes (13,7%) · Flash: 746.645 / 1.310.720 bytes (57,0%)
- `firmware.bin`: 753.216 bytes · `firmware.elf`: 11.253.600 bytes

## Testes host

Compilados com `zig c++` (g++/cl ausentes na máquina; o CI usa g++):

- `test_retry`: `retry: inicio, espera, limite e rollover OK`
- `test_mqtt`: `mqtt: offline, retentativas, inscricao e reconexao OK`

## Wokwi → Mosquitto (demo real)

- Wokwi for VS Code 4.0.1, licença válida até 20/11/2026
- Broker: `docker compose -f infra/docker-compose.dev.yml up -d` (Mosquitto 2.1.2 em `localhost:1884`, Postgres 17 healthy)
- Serial do terminal:

```text
[terminal] iniciando esqueleto US-07
[display] esqueleto; renderizacao QR pendente
[nfc] esqueleto; leitura desabilitada
[gps] esqueleto; sem posicao disponivel
[feedback] esqueleto; LED e buzzer desabilitados
[door] esqueleto; atuacao desabilitada

[wifi] conectando
[mqtt] conectado e inscrito nos comandos
[mqtt] mensagem recebida em terminals/terminal-dev-01/commands (10 bytes); ignorada no esqueleto
```

- Log do broker: `New client connected from 172.27.0.1:43316 as terminal-dev-01 (p4, c1, k15).`

## Reconexão e reinscrição

- `docker compose restart mosquitto`
- Serial:

```text
[mqtt] conexao falhou (estado=-4); nova tentativa depois
[mqtt] conectado e inscrito nos comandos
[mqtt] mensagem recebida em terminals/terminal-dev-01/commands (20 bytes); ignorada no esqueleto
```

- Broker: nova conexão `as terminal-dev-01` após o restart; segunda mensagem (`smoke-us07-reconexao`) recebida na serial.

## Lint do diagrama

`wokwi-cli 0.29.0 lint`: exit 0, com 1 info (`unsupported-part` para `board-esp32-devkit-c-v4`, tipo ainda não documentado). A emulação roda com esse diagrama.

## Limites

- Periféricos (servo/LED/buzzer/LCD) não fazem parte da US-07; entram na US-08.
- A mensagem é logada e descartada no esqueleto — sem parser, atuação ou ACK, como previsto no escopo.
