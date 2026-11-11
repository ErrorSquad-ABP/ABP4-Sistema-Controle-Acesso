# firmware

## US-23 · NFC RC522 + feedback de decisão (S3)

O perfil padrão `esp32dev` segue a montagem de 07/11/2026: RC522 SPI
**SCK 18, MISO 19, MOSI 23, SS 32, RST 33**, RGB de ânodo comum
**R 25 / G 27** (LOW acende), piezo no **14**, servo no **26**.
Alimente o RC522 somente em **3,3 V**, use GND comum e resistor de 220 Ω por
cor. O COM do RGB vai ao 3V3 do próprio ESP32. Não una fontes de 3,3 V.

- `nfc.cpp` consulta o leitor a cada 100 ms, usa WUPA para detectar tags em
  HALT, formata UIDs de 4/7/10 bytes em hexadecimal maiúsculo e encerra a sessão.
  Uma apresentação gera uma tentativa; a mesma tag só rearma depois de
  **500 ms de ausência**. Uma tag diferente pode gerar outra tentativa.
- `publishNfc` envia envelope MQTT v1 com UUID v4 e UTC em
  `terminals/{id}/access-events`, **QoS 1, sem retain**, esperando PUBACK.
  A biblioteca passa a ser `256dpi/MQTT`: PubSubClient não publica QoS 1.
  ACKs também usam QoS 1; comandos são enfileirados no callback e executados
  fora dele para evitar publicação síncrona reentrante.
  A fila volátil comporta 8 comandos; saturação é logada e descarta sem atuar.
  PUBACK confirma transporte, não decisão de acesso nem abertura física.
- A leitura **não** libera acesso. Só o comando validado do backend produz
  verde/bipes agudos (`open`) ou vermelho/bipe grave (`deny`). Prazo, relógio
  e deduplicação por `commandId` continuam sendo verificados antes da atuação.
- Sem leitor, rede, PUBACK ou UTC confiável, não há liberação local nem fila
  offline. Retire e reapresente a tag após recuperar o serviço. Retry com
  persistência é escopo da US-25. Nunca se imprime o UID na serial.

### Segurança e perfis de display

Crie `include/config.h` a partir do exemplo **somente se ainda não existir**.
Uma configuração antiga deve ser migrada manualmente: ela tem GPIOs em conflito
com o RC522. Ajuste WiFi e o IP LAN do broker antes de gravar no ESP32.

No perfil físico, **`DOOR_ENABLED=0`** mantém o GPIO do servo sem acionamento:
`open` executa apenas o feedback de decisão (ACK `executed` confirma esse
feedback, não abertura física). Só habilite depois de confirmar que o servo
é de rotação contínua, sua alimentação e a calibração dos valores 0/90/180.
Para servo posicional é necessário adaptar o driver, não só habilitar o pino.
`FEEDBACK_BUZZER_ENABLED=0` evita acionar um buzzer de modelo desconhecido;
habilite somente após confirmar piezo passivo compatível ou driver apropriado.

OLED SSD1306 usa **TwoWire(1), SDA 21 / SCL 22**, endereço `0x3C`.
LCD 1602 opcional usa **Wire, SDA 16 / SCL 17**, endereço `0x27`;
`LCD_ENABLED=0` por segurança. Habilite apenas com módulo compatível em 3,3 V
ou conversor bidirecional se os pull-ups forem para 5 V. No perfil físico padrão
(`TERMINAL_DISPLAY_OLED=0`), esses displays mostram **status NFC**.
A variante `TERMINAL_DISPLAY_OLED=1` da US-29 mostra QR compacto no OLED,
com seleção da menor versão, margem completa por padrão e ajustes pela serial.
Nesse modo, o OLED usa `Wire` e o LCD de status não é inicializado. LEDs/buzzer
e NFC continuam ativos. O TFT só é inicializado no perfil legado com
`TERMINAL_DISPLAY_OLED=0`: nunca há dois drivers disputando `terminal_display`.

```powershell
# Montagem física NFC (padrão)
pio run -e esp32dev
# TFT/servo/LEDs do diagrama Wokwi legado; NFC desabilitado por conflito de GPIOs
pio run -e esp32dev-wokwi
```

`wokwi/wokwi.toml` aponta para `esp32dev-wokwi`. O diagrama legado permanece
exclusivo desse perfil e **não simula o RC522 nem representa a montagem física**.
Os testes `test_nfc_scan`, `test_nfc` (leitor simulado) e `test_mqtt_nfc`
cobrem formatação, apresentação repetida, remoção, leitor ausente e envelope
QoS 1/offline/UTC/PUBACK. `test_feedback_io` verifica polaridade dos GPIOs e
bipes nos dois perfis, inclusive buzzer desabilitado. O CI compila os dois perfis.

Roteiro de aceite e limites: [US-23](../docs/entrega/evidencias/us-23-nfc-rc522.md).
Passo a passo de preparação, cadastro de tag e teste físico:
[testar US-23](../docs/guides/testar-us-23-nfc.md).

---

## Referência histórica · perfil TFT US-08/US-22

As pinagens e o roteiro Wokwi abaixo valem para `esp32dev-wokwi`, não para a
montagem NFC física. Use `pio run -e esp32dev-wokwi` nos comandos desse roteiro.

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
include/mqtt_ca.h           CA raiz (público) usado no TLS com o broker de produção
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
| Servo (rotação contínua) | 14 | 180 abre, 90 para, 0 fecha; 1800 ms de movimento e 3000 ms aberto. Pulso em 1000–2000 µs (90 = 1500 µs, o neutro); parado, o pino fica sem pulso para o servo não arrastar |
| LED vermelho | 5 | ânodo comum: LOW acende |
| LED verde | 18 | ânodo comum: LOW acende |
| Buzzer | 19 | 440/659 Hz no liberado; 220 Hz no negado |
| TFT CS / DC / RST | 27 / 26 / 25 | ILI9341 240x320 por SPI por software |
| TFT MOSI / SCK | 32 / 33 | dados e clock do SPI por software |
| OLED SDA / SCL (opcional) | 21 / 22 | SSD1306 128x64 em `0x3C`, ligado com `TERMINAL_DISPLAY_OLED 1`; mostra só o QR, na maior escala inteira que cabe |

Com o OLED, a serial aceita teclas de bancada para achar a leitura mais fácil
no celular: `i` inverte as cores, `c` alterna o brilho e `s` alterna entre a
escala máxima e a escala 1 com margem completa de 4 módulos.

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
.\.venv\Scripts\pio.exe run -e esp32dev-wokwi
```

Linux/macOS:

```bash
python3.13 -m venv .venv
.venv/bin/python -m pip install platformio==6.1.18
cp include/config.example.h include/config.h
.venv/bin/pio run -e esp32dev-wokwi
```

`pio run` baixa as bibliotecas (`MQTT`, `MFRC522`, `ESP32Servo`,
`Adafruit ILI9341`, `Adafruit GFX`, `QRCode`, `ArduinoJson`) e gera
`.pio/build/esp32dev-wokwi/firmware.bin` e `firmware.elf` para o perfil legado. Edite somente `include/config.h` com a configuração local e não
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

## TLS com o broker de produção (DT-06)

O padrão do `config.example.h` é `MQTT_USE_TLS 0` (texto claro, Mosquitto dev e
Wokwi). Em produção o terminal fala TLS com o broker EMQX Cloud Serverless:

1. No `config.h` local, defina `MQTT_USE_TLS 1`, `MQTT_HOST` (host do deployment,
   página Overview), `MQTT_PORT 8883`, `MQTT_USERNAME` e `MQTT_PASSWORD` (usuário
   criado em *Access Control → Authentication*). Credenciais ficam só no
   `config.h`, ignorado pelo Git.
2. O CA vem de [`include/mqtt_ca.h`](include/mqtt_ca.h): **DigiCert Global Root G2**
   (raiz pública, válida até 2038-01-15, SHA-256 `CB:3C:CB:B7:…:B1:CB:5F` conferido no
   commit; é o `emqxsl-ca.crt` do link "CA Certificate" do Overview). É um certificado
   público, por isso versionado. Antes de usar outro broker, confira a cadeia dele:

   ```bash
   openssl s_client -showcerts -servername <host> -connect <host>:8883 </dev/null
   ```

   Se a raiz da cadeia não for a DigiCert Global Root G2, troque o PEM; o terminal
   falha fechado até lá.
3. O `WiFiClientSecure` valida cadeia, validade e hostname. `setInsecure()` não existe
   no firmware e o CI falha se aparecer.
4. A conexão só é tentada com **hora UTC confiável** (SNTP): sem ela todo certificado
   parece vencido. A serial mostra `[mqtt] tls aguardando hora (sntp)` uma vez.
5. Certificado recusado, hostname diferente ou handshake lento: a conexão falha, o
   transporte é liberado, a serial informa o motivo do TLS e a retentativa segue
   `MQTT_RETRY_MS`. Sem conexão não há inscrição: nenhum comando chega e a porta não abre.
6. O handshake **bloqueia o `loop()`** até `MQTT_HANDSHAKE_TIMEOUT_SECONDS`
   (5 s; no core 2.x o valor é em segundos), mas só inicia com a porta em `idle`.
   A porta é atualizada antes da rede; abertura, espera aberta e fechamento adiam
   a reconexão. Uma conexão viva continua atendida. Ao conectar, a serial mostra
   `[mqtt] tls ok em <N> ms, heap livre <M> B`.

A porta 8883 é convenção: a regra é "CA obrigatório". Com `MQTT_USE_TLS 1` e um
`mqtt_ca.h` sem PEM, a compilação falha (`static_assert`).

### Diagnóstico

- Sem conexão WiFi: confira SSID/senha no `config.h`; no Wokwi use `Wokwi-GUEST`.
- MQTT falhando: confira Docker, porta `1884`, gateway e host. No hardware
  físico, use o IP local do computador, não `localhost` nem `host.wokwi.internal`.
- TLS: `tls aguardando hora` = SNTP sem resposta; `estado=-2` com `tls=-9984 X509 -
  Certificate verification failed` (observado no ESP32 em 06/11/2026) = CA errado
  ou hostname diferente do certificado; `tls=-1`/timeout = rede ou handshake acima do teto.
- ACK `rejected` com `clock_unsynced`: o SNTP não respondeu. O firmware **não
  abre** sem hora confiável; verifique a saída para a internet do simulador ou o
  servidor configurado em `NTP_SERVER_PRIMARY`.
- ACK `expired`: `expiresAt` já passou — gere o comando com prazo futuro.
- ACK `rejected` com `door_busy`: já existe um ciclo de abertura em andamento.
- Sem mensagem: confira tópico, terminalId, conexão e inscrição. Payloads não
  são impressos, evitando vazamento de credenciais pela serial.
- Sem binário: rode o build antes da simulação e confirme os caminhos do TOML.
- Windows com `xtensa-esp32-elf-g++: CreateProcess: No such file or directory`:
  caminhos longos do Core/pacotes podem impedir o GCC de iniciar seu processo
  interno. Use uma instalação do PlatformIO em caminho curto; não altere os
  pinos para tentar corrigir esse erro. Para evitar problemas de módulos Python,
  prefira o ambiente Python completo gerenciado pelo PlatformIO/VS Code, não
  uma distribuição Python embutida sem os módulos do `esptool`.

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
| `test_qr_token` | validade do QR (limite de expiração, relógio ausente, token vazio e o maior token que o backend emite) |
| `test_display_qr` | token máximo de 133 bytes renderizado inteiro no QR v8/ECC_LOW pelo encoder real |
| `test_clock_policy` | janela de hora confiável (epoch zero, antes e depois de 2025-01-01) |
| `test_mqtt` | módulo MQTT real com doubles: offline, retentativas, inscrição, reconexão |
| `test_mqtt_command` | JSON v1 de ponta a ponta: ACK publicado, dedup, prazo, `deny`, recusas e QR |
| `test_mqtt_tls` | TLS (DT-06): CA configurado, sem `setInsecure`, sem conexão sem hora confiável, certificado recusado libera o transporte e não inscreve (compilar com `-DMQTT_USE_TLS=1`) |
| `test_mqtt_door_timing` | `main` + MQTT + porta reais; queda nas três fases não inicia reconexão antes da parada do servo (TLS desligado e ligado) |

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
# O encoder do QR nao compila com -Werror; so o teste nosso exige.
gcc -std=c99 -O2 -I .pio/libdeps/esp32dev/QRCode/src -c .pio/libdeps/esp32dev/QRCode/src/qrcode.c -o /tmp/qrcode.o
g++ -std=c++11 -Wall -Wextra -Werror -I include -I .pio/libdeps/esp32dev/QRCode/src tests/test_display_qr.cpp /tmp/qrcode.o -o /tmp/t-display-qr && /tmp/t-display-qr
g++ -std=c++11 -Wall -Wextra -Werror -I include tests/test_clock_policy.cpp -o /tmp/t-clock && /tmp/t-clock
JSON_SRC=.pio/libdeps/esp32dev/ArduinoJson/src
g++ -std=c++11 -Wall -Wextra -Werror -I tests/fakes -I include -I src -isystem "$JSON_SRC" tests/test_mqtt.cpp src/modules/mqtt.cpp -o /tmp/t-mqtt && /tmp/t-mqtt
g++ -std=c++11 -Wall -Wextra -Werror -I tests/fakes -I include -I src -isystem "$JSON_SRC" tests/test_mqtt_command.cpp src/modules/mqtt.cpp -o /tmp/t-mqtt-command && /tmp/t-mqtt-command
g++ -std=c++11 -Wall -Wextra -Werror -DMQTT_USE_TLS=1 -I tests/fakes -I include -I src -isystem "$JSON_SRC" tests/test_mqtt_tls.cpp src/modules/mqtt.cpp -o /tmp/t-mqtt-tls && /tmp/t-mqtt-tls
for tls in 0 1; do
  g++ -std=c++11 -Wall -Wextra -Werror -DMQTT_USE_TLS=$tls -I tests/fakes -I include -I src -isystem "$JSON_SRC" tests/test_mqtt_door_timing.cpp src/main.cpp src/modules/mqtt.cpp src/modules/door.cpp -o /tmp/t-mqtt-door
  for phase in opening open closing; do /tmp/t-mqtt-door "$phase"; done
done
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

- Heartbeat/LWT (`terminals/{id}/status`) e GPS continuam pendentes (US-24).
  NFC está implementado no perfil físico pela US-23; permanece desabilitado
  no perfil TFT legado, cujos pinos conflitam com o RC522.
- O TLS (DT-06) foi validado no ESP32 contra o EMQX em 06/11/2026 (conexão e
  negativos de CA/hostname). O servo não girou nessa bancada e o ACK não foi
  observado; a correção de timing da reconexão foi validada só em host/build
  ([`evidencias/dt-06.md`](../docs/entrega/evidencias/dt-06.md)). Sem mTLS nem
  rotação automática de CA.
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
