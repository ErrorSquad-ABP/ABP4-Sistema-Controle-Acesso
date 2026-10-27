# firmware

Terminal de Acesso ESP32 — PlatformIO + Arduino/C++. A **US-08** porta a atuação
do protótipo `teste-servo.ino` (servo de rotação contínua, LED vermelho/verde,
buzzer e display) para módulos do projeto novo, atrás de uma máquina de
estados sem `delay()` longo. A **US-22** troca o LCD 16x2 por um **TFT ILI9341**
que desenha o QR rotativo recebido do backend e o status do terminal.

O backend decide; o firmware só executa o comando v1 (`open`/`deny`) com prazo
válido, sem repetir um `commandId` já atendido, e responde o ACK em
`terminals/{id}/acks`. Contrato em
[`docs/architecture/contratos-mqtt.md`](../docs/architecture/contratos-mqtt.md).

## Estrutura

```text
platformio.ini              ESP32 DevKit / Arduino; versões fixadas
include/config.example.h    WiFi, broker, tópicos, pinos e tempos (modelo)
include/config.h            cópia local, ignorada no Git
include/terminal_settings.h configuração compartilhada pelos módulos
include/retry_interval.h    intervalo de retentativas, sem dependência de Arduino
include/clock_time.h        relógio UTC via SNTP
include/door_machine.h      máquina de estados do servo com tempo injetado
include/command.h           validação do comando v1, dedup e ACK
include/iso8601.h           conversão ISO 8601 <-> epoch UTC
include/feedback_pattern.h  passos de LED/buzzer para liberado/negado
include/display_text.h      textos de status por estado
include/qr_token.h          validade do QR rotativo (tempo injetado)
src/main.cpp                inicializa, liga as dependências e atualiza os módulos
src/modules/                mqtt, clock_time, display, nfc, gps, feedback, door
tests/                      testes host em C++ e doubles de Arduino
wokwi/                      diagram.json + wokwi.toml
```

Cada módulo expõe `begin()`/`update()`. O `mqtt` não conhece servo, LED nem
relógio: o `main.cpp` injeta a atuação (`setActuator`) e a fonte de hora
(`setClock`), o que mantém o parser e as regras de comando testáveis no host.

## Pinos e tempos

Valores em `include/config.example.h` (nada secreto ali; segredos ficam no
`config.h` local).

| Função | Pino/valor | Comportamento |
|---|---|---|
| Servo (rotação contínua) | 14 | 180 abre, 90 para, 0 fecha; 1800 ms de movimento e 3000 ms aberto |
| LED vermelho | 5 | ânodo comum: LOW acende |
| LED verde | 18 | ânodo comum: LOW acende |
| Buzzer | 19 | 440/659 Hz no liberado; 220 Hz no negado |
| TFT CS / DC / RST | 27 / 26 / 25 | ILI9341 240x320 por SPI por software |
| TFT MOSI / SCK | 32 / 33 | dados e clock do SPI por software |

## Fluxo do comando

1. Chega JSON v1 em `terminals/{id}/commands`.
2. Recusa com ACK `rejected` quando: JSON inválido, `v` diferente de 1,
   `terminalId` diferente do tópico, `action` fora de `open|deny`, `expiresAt`
   ilegível, ou relógio UTC ainda não sincronizado (`clock_unsynced`).
3. `expiresAt` no passado → ACK `expired`, servo não se move.
4. `commandId` repetido → responde o ACK anterior com `reason: duplicate` e não
   aciona a cancela de novo.
5. `open` abre, segura e fecha a cancela com LED verde e dois bipes; `deny` faz
   LED vermelho e bipe grave. O LCD acompanha cada etapa.
6. Publica o ACK com o mesmo `commandId`.

O ciclo do servo é a máquina `idle → opening → open → closing → idle`, avançada
por `millis()`: nenhum `delay()` bloqueia o `client.loop()` do MQTT. O display
acompanha cada etapa e, em paralelo, mostra o QR recebido do backend.

## Preparação e build

Pré-requisitos: Python 3.13, PlatformIO Core **6.1.18**, VS Code com a extensão
**Wokwi** para simulação. A extensão PlatformIO é opcional para quem usa o CLI.
Execute os comandos a partir de `firmware/`.

Windows / PowerShell:

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install platformio==6.1.18
Copy-Item include/config.example.h include/config.h
.\.venv\Scripts\pio.exe run
```

Linux/macOS:

```bash
python3.13 -m venv .venv
.venv/bin/python -m pip install platformio==6.1.18
cp include/config.example.h include/config.h
.venv/bin/pio run
```

`pio run` baixa as bibliotecas (`PubSubClient`, `ESP32Servo`,
`Adafruit ILI9341`, `Adafruit GFX`, `QRCode`, `ArduinoJson`) e gera
`.pio/build/esp32dev/firmware.bin` e `firmware.elf`. Edite somente `include/config.h` com a configuração local e não
sobrescreva uma configuração existente ao repetir os passos.

Para hardware real, ajuste WiFi/host do broker, use `pio run -t upload` e
`pio device monitor` (115200 baud); `host.wokwi.internal` só existe no simulador.

## Simulação Wokwi com o broker dev

1. Na raiz do repositório, suba o broker existente:

   ```bash
   docker compose -f infra/docker-compose.dev.yml up -d mosquitto
   docker compose -f infra/docker-compose.dev.yml logs -f mosquitto
   ```

2. Compile o firmware com o exemplo: WiFi `Wokwi-GUEST`, senha vazia, broker
   **`host.wokwi.internal:1884`**, terminal `terminal-dev-01`.
3. Abra a pasta `firmware/` no VS Code e instale a extensão Wokwi se necessário:
   `code --install-extension Wokwi.wokwi-vscode`.
4. Ative sua licença pela ação **Wokwi: Request a new License** (requer conta e
   confirmação pessoal). Não versione a licença.
5. Execute **Wokwi: Select Config File**, selecione `wokwi/wokwi.toml` e então
   **Wokwi: Start Simulator**. O `diagram.json` traz ESP32, servo no pino 14,
   LEDs vermelho (5) e verde (18), buzzer (19) e TFT ILI9341 (CS 27, DC 26,
   RST 25, MOSI 32, SCK 33).
6. Confira na serial `[mqtt] conectado e inscrito nos comandos` e, nos logs do
   Mosquitto, a conexão do cliente `terminal-dev-01`.
7. Publique um comando sintético com prazo futuro (o firmware confere
   `expiresAt` com a hora do SNTP):

   ```bash
   expires=$(date -u -d '+60 seconds' +%Y-%m-%dT%H:%M:%S.000Z)
   now=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
   docker compose -f infra/docker-compose.dev.yml exec mosquitto mosquitto_pub -h localhost -p 1883 \
     -t terminals/terminal-dev-01/commands -q 1 \
     -m "{\"v\":1,\"messageId\":\"$(uuidgen)\",\"terminalId\":\"terminal-dev-01\",\"timestamp\":\"$now\",\"commandId\":\"$(uuidgen)\",\"expiresAt\":\"$expires\",\"action\":\"open\",\"reason\":\"demo\"}"
   ```

   A serial informa `[mqtt] comando <commandId>: executed`; o display passa por
   `ACESSO LIBERADO`, `ABRINDO CANCELA`, `CANCELA ABERTA` e `FECHANDO CANCELA`
   enquanto o servo gira no sentido de abertura por 1,8 s, espera 3 s e fecha; o
   LED verde acende com dois bipes. O ACK sai em `terminals/terminal-dev-01/acks`
   (`status: executed`).

8. Para o feedback de negado, repita com `"action":"deny"`: LED vermelho, bipe
   de 220 Hz, display com `ACESSO NEGADO`, servo parado, ACK `executed`.

9. Para conferir dedup e prazo, republicar o **mesmo** `commandId` deve produzir
   `duplicate` sem novo movimento, e um `expiresAt` no passado deve produzir ACK
   `expired`. Publicações para outro terminal são ignoradas.

O gateway público do Wokwi no navegador **não alcança seu localhost**. Para usar
o navegador seria necessário o Private IoT Gateway, sujeito ao plano do Wokwi.
Não troque por broker público nem exponha o Mosquitto na internet. O Mosquitto
de desenvolvimento aceita conexões anônimas e não usa TLS; restrinja a porta pelo
firewall à máquina/rede de desenvolvimento.

### Diagnóstico

- Sem conexão WiFi: confira SSID/senha no `config.h`; no Wokwi use `Wokwi-GUEST`.
- MQTT falhando: confira Docker, porta `1884`, gateway e host. No hardware
  físico, use o IP local do computador, não `localhost` nem `host.wokwi.internal`.
- ACK `rejected` com `clock_unsynced`: o SNTP não respondeu. O firmware **não
  abre** sem hora confiável; verifique a saída para a internet do simulador ou o
  servidor configurado em `NTP_SERVER_PRIMARY`.
- ACK `expired`: `expiresAt` já passou — gere o comando com prazo futuro.
- ACK `rejected` com `door_busy`: já existe um ciclo de abertura em andamento.
- Sem mensagem: confira tópico, terminalId, conexão e inscrição. Payloads não
  são impressos, evitando vazamento de credenciais pela serial.
- Sem binário: rode o build antes da simulação e confirme os caminhos do TOML.

## Testes

Os testes host rodam sem Arduino, com tempo e periféricos simulados:

| Teste | Cobre |
|---|---|
| `test_retry` | primeira tentativa, limite exato, espera e rollover de `millis()` |
| `test_door_machine` | ciclo idle/opening/open/closing, comando recusado durante o ciclo, rollover |
| `test_command` | ISO 8601 ↔ epoch, validação do comando, dedup por `commandId`, ACK de cada recusa |
| `test_feedback_pattern` | passos de LED/buzzer de liberado e negado, interrupção e fim do padrão |
| `test_display_text` | textos de 16 colunas e exclusividade por status |
| `test_display_layout` | margem de silêncio de 4 módulos do QR e encaixe do status na tela |
| `test_qr_token` | validade do QR (limite de expiração, relógio ausente e token vazio) |
| `test_clock_policy` | janela de hora confiável (epoch zero, antes e depois de 2025-01-01) |
| `test_mqtt` | módulo MQTT real com doubles: offline, retentativas, inscrição, reconexão |
| `test_mqtt_command` | JSON v1 de ponta a ponta: ACK publicado, dedup, prazo, `deny`, recusas e QR |

Linux/CI, a partir de `firmware/`:

```bash
pio pkg install -e esp32dev   # traz o ArduinoJson usado pelo teste do MQTT
g++ -std=c++11 -Wall -Wextra -Werror -I include tests/test_retry.cpp -o /tmp/t-retry && /tmp/t-retry
g++ -std=c++11 -Wall -Wextra -Werror -I include tests/test_door_machine.cpp -o /tmp/t-door && /tmp/t-door
g++ -std=c++11 -Wall -Wextra -Werror -I include tests/test_command.cpp -o /tmp/t-command && /tmp/t-command
g++ -std=c++11 -Wall -Wextra -Werror -I include tests/test_feedback_pattern.cpp -o /tmp/t-feedback && /tmp/t-feedback
g++ -std=c++11 -Wall -Wextra -Werror -I include tests/test_display_text.cpp -o /tmp/t-display && /tmp/t-display
g++ -std=c++11 -Wall -Wextra -Werror -I include tests/test_display_layout.cpp -o /tmp/t-layout && /tmp/t-layout
g++ -std=c++11 -Wall -Wextra -Werror -I include tests/test_qr_token.cpp -o /tmp/t-qr && /tmp/t-qr
g++ -std=c++11 -Wall -Wextra -Werror -I include tests/test_clock_policy.cpp -o /tmp/t-clock && /tmp/t-clock
JSON_SRC=.pio/libdeps/esp32dev/ArduinoJson/src
g++ -std=c++11 -Wall -Wextra -Werror -I tests/fakes -I include -I src -isystem "$JSON_SRC" tests/test_mqtt.cpp src/modules/mqtt.cpp -o /tmp/t-mqtt && /tmp/t-mqtt
g++ -std=c++11 -Wall -Wextra -Werror -I tests/fakes -I include -I src -isystem "$JSON_SRC" tests/test_mqtt_command.cpp src/modules/mqtt.cpp -o /tmp/t-mqtt-command && /tmp/t-mqtt-command
```

No Windows, um compilador C++ host instalado (g++/Clang) ou
[Zig](https://ziglang.org/download/) portátil executam os mesmos comandos:

```powershell
zig c++ -std=c++11 -fno-exceptions -fno-rtti -nostdlib++ -Wall -Wextra -Werror -I include tests/test_command.cpp -o "$env:TEMP\t-command.exe"
& "$env:TEMP\t-command.exe"
```

Troque o arquivo de teste e, para os testes de MQTT, acrescente
`-I tests/fakes -I src -isystem .pio/libdeps/esp32dev/ArduinoJson/src` e
`src/modules/mqtt.cpp`.

O CI compila sempre, roda os testes host e copia o exemplo de configuração. A
demonstração Wokwi (servo, TFT, LED, buzzer) precisa ser executada manualmente
com Docker e licença disponíveis; build e testes host verdes **não comprovam** a
conexão do simulador ao broker nem o movimento real do servo.

## Limites desta história

- Heartbeat/LWT (`terminals/{id}/status`) e eventos de acesso continuam
  pendentes (US-04 e seguintes); NFC e GPS seguem como stubs.
- O QR exibido é o token cru recebido do backend; assinatura e validação de
  credencial entram na US-19/US-20.
- O prazo do comando depende de SNTP: sem hora confiável o terminal recusa em vez
  de abrir a porta e não desenha o QR.
- A comparação de prazo é feita em segundos inteiros (tolerância < 1 s).
- O servo é de rotação contínua e não informa posição: "aberto/fechado" é
  resultado do tempo de acionamento, não de um sensor de fim de curso.
- O TFT usa SPI por software para preservar os pinos do protótipo; a taxa é
  suficiente para redesenhar o QR a cada 10 s, mas não para animações.

Referências: [rede ESP32](https://docs.wokwi.com/guides/esp32-wifi),
[configuração VS Code](https://docs.wokwi.com/vscode/project-config),
[arquitetura](../docs/architecture/visao-geral.md).
