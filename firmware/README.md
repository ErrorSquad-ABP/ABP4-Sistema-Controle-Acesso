# firmware

Esqueleto do Terminal de Acesso ESP32 — **US-07**, PlatformIO + Arduino/C++.
O backend decide o acesso; este esqueleto **não abre portas**, lê NFC/GPS nem
renderiza QR. O porte de servo/LED/buzzer/LCD entra na US-08; NFC e GPS ficam
preparados para suas próximas histórias. Contrato, heartbeat,
LWT, validação/deduplicação de comandos e ACK dependem da US-04.

## Estrutura

```text
platformio.ini              ESP32 DevKit / Arduino; versões fixadas
include/config.example.h    WiFi, broker, terminal e tópicos de desenvolvimento
include/config.h            cópia local, ignorada no Git
include/terminal_settings.h configuração compartilhada pelos módulos
include/retry_interval.h    intervalo de retentativas, sem dependência de Arduino
src/main.cpp                inicializa e atualiza os módulos
src/modules/                mqtt, display, nfc, gps, feedback, door (.h/.cpp)
tests/                      testes C++ host: intervalos e MQTT com rede simulada
wokwi/                      diagram.json + wokwi.toml
```

Cada módulo expõe `begin()` e `update()`. `terminal_mqtt::connected()` informa
se o cliente MQTT está conectado. Só o módulo MQTT integra rede nesta história;
os outros anunciam a inicialização na serial e não atuam nos pinos.

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

Edite somente `include/config.h` com a configuração local. Não sobrescreva uma
configuração existente ao repetir os passos. `pio run` gera
`.pio/build/esp32dev/firmware.bin` e `firmware.elf`.
Para hardware real, ajuste WiFi/host do broker e use `pio run -t upload` seguido
de `pio device monitor` (115200 baud); `host.wokwi.internal` só existe no simulador.

## Simulação Wokwi com o broker dev

1. Na raiz do repositório, suba o broker existente:

   ```bash
   docker compose -f infra/docker-compose.dev.yml up -d mosquitto
   docker compose -f infra/docker-compose.dev.yml logs -f mosquitto
   ```

2. Compile o firmware com o exemplo: WiFi `Wokwi-GUEST`, senha vazia,
   broker **`host.wokwi.internal:1884`**, terminal `terminal-dev-01`.
   `1884` é a porta publicada no host; `1883` é interna ao container.
3. Abra a pasta `firmware/` no VS Code. Se necessário, instale a extensão com
   `code --install-extension Wokwi.wokwi-vscode`.
4. Ative sua licença pela ação **Wokwi: Request a new License** (requer conta e
   confirmação pessoal). Não versione a licença. Consulte as condições atuais
   do Wokwi; baixar a extensão não ativa uma licença automaticamente.
5. Execute **Wokwi: Select Config File**, selecione `wokwi/wokwi.toml` e então
   **Wokwi: Start Simulator**. O `diagram.json` fica ao lado do TOML; os caminhos
   do firmware são relativos a esse arquivo, não à raiz do monorepo.
6. O Wokwi para VS Code inclui o gateway privado. Verifique na serial
   `[mqtt] conectado e inscrito nos comandos` e, nos logs do Mosquitto, a conexão
   do cliente `terminal-dev-01`.
7. Em outro terminal na raiz, publique **somente uma mensagem sintética**:

   ```bash
   docker compose -f infra/docker-compose.dev.yml exec mosquitto mosquitto_pub -h localhost -p 1883 -t terminals/terminal-dev-01/commands -m smoke-us07 -q 1
   ```

   A serial deve informar o recebimento em `terminals/terminal-dev-01/commands`.
   A mensagem é descartada, **sem atuação ou ACK**: este não é um comando v1.
   Publicações para outro terminal não devem aparecer. Pare e reinicie o broker
   para conferir reconexão e reinscrição automáticas.

O gateway público do Wokwi no navegador **não alcança seu localhost**. Para
usar o navegador seria necessário o Private IoT Gateway, sujeito ao plano do
Wokwi. Não troque por broker público nem exponha o Mosquitto na internet.
O Mosquitto de desenvolvimento aceita conexões anônimas e não usa TLS;
restrinja a porta pelo firewall à máquina/rede de desenvolvimento.

### Diagnóstico

- Sem conexão WiFi: confira SSID/senha no `config.h`; no Wokwi use `Wokwi-GUEST`.
- MQTT falhando: confira Docker, porta `1884`, gateway e host. No hardware físico,
  use o IP local do computador, não `localhost` nem `host.wokwi.internal`.
- A tentativa de WiFi/MQTT é espaçada por 5 s. `connect()` é síncrono e possui
  timeout; não há laço de espera até a rede voltar. DNS/TCP ainda podem atrasar
  uma iteração, portanto isto não é uma implementação assíncrona de produção.
- Sem mensagem: confira tópico, terminalId, conexão e inscrição. Payloads não
  são impressos nem interpretados, evitando vazamento de credenciais pela serial.
- Sem binário: rode o build antes da simulação e confirme os caminhos do TOML.

## Testes

Os testes host exercitam o controle real de retentativas: primeira tentativa,
limite exato, espera entre falhas, boot tardio e rollover de `millis()`.
Também executam o módulo MQTT real com doubles de WiFi/PubSubClient: offline,
falha de conexão, inscrição no tópico do terminal e reinscrição após reconectar.
Usam somente a configuração sintética do exemplo, não as credenciais locais.
Não provam WiFi/MQTT reais ou periféricos. Linux/CI, a partir de `firmware/`:

```bash
g++ -std=c++11 -Wall -Wextra -Werror -I include tests/test_retry.cpp -o /tmp/abp4-test-retry
/tmp/abp4-test-retry
g++ -std=c++11 -Wall -Wextra -Werror -I tests/fakes -I include -I src tests/test_mqtt.cpp src/modules/mqtt.cpp -o /tmp/abp4-test-mqtt
/tmp/abp4-test-mqtt
pio run
```

No Windows pode ser usado um compilador C++ host instalado (g++/Clang) ou
[Zig](https://ziglang.org/download/) portátil:

```powershell
zig c++ -std=c++11 -fno-exceptions -fno-rtti -nostdlib++ -Wall -Wextra -Werror -I include tests/test_retry.cpp -o "$env:TEMP\abp4-test-retry.exe"
& "$env:TEMP\abp4-test-retry.exe"
zig c++ -std=c++11 -fno-exceptions -fno-rtti -nostdlib++ -Wall -Wextra -Werror -I tests/fakes -I include -I src tests/test_mqtt.cpp src/modules/mqtt.cpp -o "$env:TEMP\abp4-test-mqtt.exe"
& "$env:TEMP\abp4-test-mqtt.exe"
```

O CI compila sempre e copia o exemplo de configuração. A demonstração Wokwi
precisa ser executada separadamente com Docker e licença disponíveis; build e
testes host verdes **não comprovam** a conexão do simulador ao broker.

Referências: [rede ESP32](https://docs.wokwi.com/guides/esp32-wifi),
[configuração VS Code](https://docs.wokwi.com/vscode/project-config),
[arquitetura](../docs/architecture/visao-geral.md).
