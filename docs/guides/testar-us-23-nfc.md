# Como testar a US-23 — NFC RC522 + feedback

Este roteiro usa **desenvolvimento com decisão real**, não liberação permissiva:
`NODE_ENV=development` e `ACCESS_MODE=real`. Não exige app mobile nem modo de
produção. A API é opcional para o NFC; serve para consultar saúde/histórico.

```text
tag → RC522/ESP32 → Mosquitto → consumidor/backend → PostgreSQL
                      ↑               ↓
             feedback + ACK ← comando open/deny
```

## 1. Pré-requisitos e diretório

- Node 24+, Docker Desktop/Compose e PlatformIO Core 6.1.18.
- ESP32 conectado por USB de dados; montagem conforme
  [conexões](conexoes-hardware.md), já validada pelo responsável.
- Computador e ESP32 com acesso ao mesmo broker pela LAN; internet para SNTP.
- O complemento Docker abaixo requer Compose 2.24.4+ (`!override`).

No PowerShell, entre na raiz do clone. Ajuste o caminho para sua máquina:

```powershell
cd C:\Users\arthu\Documents\ABP4\ABP4-Sistema-Controle-Acesso
```

Execute os comandos relativos desta página a partir dessa pasta. O script de
cadastro, especificamente, resolve seus caminhos e pode ser chamado de qualquer
pasta pelo caminho completo.

## 2. Infraestrutura

```powershell
docker compose -f infra/docker-compose.dev.yml -f infra/docker-compose.nfc.local.yml up -d --wait
docker compose -f infra/docker-compose.dev.yml -f infra/docker-compose.nfc.local.yml ps
```

O complemento local mantém o mesmo projeto/volume, mas publica o PostgreSQL em
**127.0.0.1:5437** para não disputar a porta 5436 com outra instalação.
Mosquitto permanece em **1884** no computador, **1883** dentro do container.
Postgres deve aparecer `healthy`. Não é necessário apagar volumes.

O broker de desenvolvimento aceita conexões anônimas e sem TLS: usar somente
em rede de teste confiável, nunca expor na internet. Se necessário, liberar TCP
1884 no firewall apenas para a sub-rede local/perfil privado. API opcional usa
3000. Não abrir a porta do banco para a LAN.

## 3. Backend e dados

Crie `backend/.env` a partir de `.env.example` somente se ele não existir.
Preserve valores locais existentes. Configure:

```dotenv
NODE_ENV=development
ACCESS_MODE=real
PORT=3000
DATABASE_URL="postgresql://abp4:abp4@127.0.0.1:5437/abp4?schema=public"
MQTT_URL=mqtt://127.0.0.1:1884
MQTT_USERNAME=
MQTT_PASSWORD=
RELAY_WINDOW_ENABLED=false
```

`JWT_SECRET` precisa de 32+ caracteres e `QR_TOKEN_SECRET` de 64+ caracteres
hexadecimais. Gere um valor diferente para cada segredo, executando duas vezes:

```powershell
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
```

Grave os valores apenas no `.env` ignorado pelo Git. A chave QR é exigida pelo
runtime mesmo quando o teste é NFC. Não usar `ACCESS_MODE=demo`: ele libera
qualquer UID e não comprova autorização.

Preparação inicial, **somente em banco local de teste**:

```powershell
cd backend
npm.cmd ci
npm.cmd run db:generate
npm.cmd run db:migrate:deploy
npm.cmd run db:seed
```

A seed cria `terminal-01`, usuário demo, autorização e tag fictícia `04A1B2C3`.
Ela reativa/restaura dados demo; não executar novamente depois de associar a tag
física. Não usar seed em produção/remoto nem resetar banco para este teste.

Inicie **um único** consumidor e mantenha o terminal aberto:

```powershell
npm.cmd run mqtt:consumer
```

Alternativa compilada: `npm.cmd run build` e
`node --env-file=.env dist/main/mqtt-consumer.js`. Não executar simultaneamente
outro consumidor ou worker sem necessidade. A API/app não são necessários aqui.

## 4. Firmware

Em `firmware/include/config.h`, usando o modelo atualizado, ajuste:

```cpp
#define TERMINAL_ID "terminal-01"
#define WIFI_SSID "SUA_REDE_2G4"
#define WIFI_PASSWORD "SUA_SENHA"
#define MQTT_HOST "IP_LAN_DO_COMPUTADOR"
#define MQTT_PORT 1884
#define MQTT_USERNAME ""
#define MQTT_PASSWORD ""
```

O IP é o IPv4 da interface ativa do computador (`ipconfig`), não o IP interno
do Docker nem `localhost`. Ajuste/regrave se o IP mudar. No perfil físico
(`TERMINAL_LEGACY_TFT=0`), use buzzer/LCD conforme a montagem validada:

```cpp
// FEEDBACK_BUZZER_ENABLED fica no trecho fisico, depois de #else.
#define FEEDBACK_BUZZER_ENABLED 1
#define LCD_ENABLED 1
#define DOOR_ENABLED 0
```

Preserve a pinagem do modelo. O exemplo inicia buzzer/LCD desligados para outras
montagens. Nesta bancada, `open` confirma feedback, não abertura física.
OLED/LCD mostram status NFC por padrão (`TERMINAL_DISPLAY_OLED=0`). A opção
`TERMINAL_DISPLAY_OLED=1` da US-29 seleciona QR no OLED em vez do status OLED/LCD.
As duas implementações são exclusivas; a integração não altera sua pinagem.

No terminal PlatformIO:

```powershell
cd firmware
pio device list
pio run -e esp32dev
pio run -e esp32dev -t upload --upload-port COM3
pio device monitor --port COM3 --baud 115200
```

COM3 foi a porta da sessão registrada; escolha a que `device list` apresentar
na sua máquina. Feche monitores antes de gravar. `esp32dev-wokwi` é outro perfil,
com TFT/pinos antigos e NFC desabilitado. Configuração Wi-Fi fica fora do Git.
Confirmar na inicialização: RC522 pronto e MQTT conectado/inscrito. Aguarde a
rede/hora antes de apresentar a tag; se ela estava presente durante o boot,
retire e reapresente depois.

## 5. Negação, cadastro e liberação

1. Com consumidor e placa conectados, aproxime uma tag não cadastrada.
2. Conferir vermelho/som de negação e `deny`/ACK no backend.
3. Retire a tag. Na raiz do repositório execute:

```powershell
& .\infra\scripts\register-nfc-demo.ps1
```

4. Quando o script avisar que aguarda leitura, aproxime a tag que será cadastrada.
   Essa leitura ainda pode ser negada antes do cadastro: é esperado.
5. O script valida o payload/UID, calcula SHA-256 e atualiza somente a credencial
   NFC do usuário demo. Não concede novas autorizações e não imprime o UID.
6. Após `Tag associada ao usuario de demonstracao`, retire por 1 s e reapresente.
7. Conferir verde/som de liberação, `open` e ACK `executed`. Verificar `GRANTED`
   no histórico/banco. A autorização da seed tem limite de usos.

Para consultar a correlação sem expor UID/hash, na raiz do repositório:

```powershell
@'
SELECT e.id, e.decision, e.reason, c."commandId", c."ackStatus"
FROM "AccessEvent" e
LEFT JOIN "TerminalCommand" c ON c."requestId" = e.id
WHERE e.method = 'NFC' AND e."terminalId" = 'terminal-01'
ORDER BY e."occurredAt" DESC
LIMIT 10;
'@ | docker compose -f infra/docker-compose.dev.yml -f infra/docker-compose.nfc.local.yml exec -T postgres psql -U abp4 -d abp4
```

Para acompanhar comandos e ACKs sem publicar UID no console, em outro terminal
na raiz:

```powershell
docker compose -f infra/docker-compose.dev.yml -f infra/docker-compose.nfc.local.yml exec mosquitto mosquitto_sub -h localhost -p 1883 -t terminals/terminal-01/commands -t terminals/terminal-01/acks -v
```

Cada apresentação deve gerar uma tentativa. Para contar leituras sem imprimir
seu payload/UID:

```powershell
docker compose -f infra/docker-compose.dev.yml -f infra/docker-compose.nfc.local.yml exec mosquitto mosquitto_sub -h localhost -p 1883 -t terminals/terminal-01/access-events -F '%t'
```

Mantenha a tag por 10 s: esperar uma linha, não várias. Retire por 1 s e
reapresente: esperar outra linha. Novo UID pode gerar outra tentativa.

## 6. Matriz de conferência do reviewer

| Caso | Esperado |
|---|---|
| Tag desconhecida | `DENIED/INVALID_CREDENTIAL`, `deny`, vermelho/grave, ACK |
| Tag cadastrada com autorização válida | `GRANTED`, `open`, verde/liberação, ACK |
| Tag mantida no leitor | Uma tentativa; reapresentação gera outra |
| Tag revogada | Negação, sem consumo da autorização |
| Comando duplicado | ACK de duplicata, sem repetir feedback/atuação |
| Comando vencido | ACK `expired`, sem feedback de liberação/atuação |
| Rede/hora indisponível antes da leitura | Nenhuma liberação local; recuperar serviço e reapresentar |

Não confundir proteção automática testada com todos os casos demonstrados no
hardware. Para revogação, altere apenas a credencial demo no banco local,
reapresente e depois restaure seu estado; não reexecute a seed para isso.

## 7. Testes automáticos e evidências

```powershell
cd backend
npm.cmd run lint
npm.cmd run typecheck
npm.cmd test -- --maxWorkers=2
npm.cmd run test:e2e
```

E2E cria seu próprio banco/broker temporários e não precisa de Docker. Em máquina
sobrecarregada houve timeout com alta concorrência; a suíte passou com 2 workers.
Testes host C++ e builds dos dois perfis estão em
`.github/workflows/ci-firmware.yml`; comandos adicionais no `firmware/README.md`.

Resultados observados e IDs correlacionados: [evidência US-23](../entrega/evidencias/us-23-nfc-rc522.md).
Para a review, anexar vídeo curto de negação/liberação e logs com `commandId`/ACK,
sem `.env`, `config.h`, senha Wi-Fi, UID completo ou hash da credencial.

TLS de produção foi integrado pela DT-06 e preservado junto do MQTT QoS 1:
`MQTT_USE_TLS=1` exige CA válido e hora sincronizada. Este roteiro usa Mosquitto
local sem TLS e não substitui a validação de certificados em produção.
Seguem fora do escopo: retry/persistência offline (US-25), GPS/heartbeat (US-24)
e comprovação de movimento físico do servo nesta bancada.
