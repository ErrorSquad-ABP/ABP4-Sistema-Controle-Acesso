# Conexões atuais do terminal ESP32

Referência da montagem discutida em 07/11/2026 para os testes individuais e
integrados da US-23. Este documento registra a pinagem combinada no chat; não
substitui a conferência da montagem física e das especificações dos módulos.

**Atualização US-23:** `firmware/include/config.example.h` já incorpora a pinagem
abaixo no perfil físico `esp32dev`. O TFT antigo permanece em um perfil separado,
`esp32dev-wokwi`, com NFC desabilitado por conflitos de GPIOs. A montagem foi
informada como testada e funcionando pelo responsável.

O script integrado original do chat era um teste separado, sem validação de
credenciais. O firmware da US-23 agora consulta o backend e só aplica o feedback
conforme `open`/`deny`. Preparação e cadastro: [testar US-23](testar-us-23-nfc.md).

## 1. Componentes

- ESP32 DevKit V1 clássico.
- Leitor RFID RC522 (MFRC522), SPI.
- OLED SSD1306 I²C 128×64.
- LCD 1602 com adaptador I²C.
- LED RGB de **ânodo comum**, confirmado no teste físico; azul não utilizado.
- Dois resistores de 220 Ω, um por cor utilizada.
- Buzzer: teste previsto para pequeno piezo passivo compatível com GPIO;
  confirmar o modelo físico antes de acioná-lo diretamente.
- Servo: modelo e tipo (posicional ou rotação contínua) ainda a confirmar.
- Protoboard e módulo de alimentação com saídas selecionadas em 5 V e 3,3 V.
- Fonte ajustável ligada à entrada do módulo de alimentação.

## 2. Mapa dos sinais

Os números abaixo são **GPIOs**, não posições físicas do conector.

| Componente | Terminal | ESP32 |
|---|---|---|
| RC522 | SCK | GPIO 18 |
| RC522 | MISO | GPIO 19 |
| RC522 | MOSI | GPIO 23 |
| RC522 | SDA / SS / CS | GPIO 32 |
| RC522 | RST | GPIO 33 |
| RC522 | IRQ | Não conectado |
| OLED | SDA | GPIO 21 |
| OLED | SCL | GPIO 22 |
| LCD I²C | SDA | GPIO 16 (RX2 na placa) |
| LCD I²C | SCL | GPIO 17 (TX2 na placa) |
| RGB | R, através de resistor de 220 Ω | GPIO 25 |
| RGB | G, através de resistor de 220 Ω | GPIO 27 |
| RGB | B | Não conectado |
| Buzzer | Positivo / sinal | GPIO 14, somente se compatível com acionamento direto |
| Servo | PWM / sinal | GPIO 26 |

O SDA do RC522 é **seleção do dispositivo SPI**, não uma conexão I²C.
Os fios de sinal podem ir diretamente ao ESP32; passar pela protoboard é
opcional. Não conectar duas funções diferentes ao mesmo GPIO.

## 3. Alimentação e GND

### Distribuição na protoboard

| Origem | Destino |
|---|---|
| Saída de 5 V do módulo | Trilho positivo superior (`tp` no diagrama Wokwi) |
| Saída de 3,3 V do módulo | Trilho positivo inferior (`bp` no diagrama Wokwi) |
| GND do módulo de alimentação | Trilhos negativos |
| Trilho negativo superior | Trilho negativo inferior |
| GND do ESP32 e dos componentes | Mesmo GND comum |

**Nunca interligar os trilhos positivos de 5 V e 3,3 V.** Confira se os trilhos
da protoboard têm interrupções no meio; não presuma continuidade elétrica.

A tensão ajustada na fonte é a **entrada do módulo**, não necessariamente 5 V.
Depende do modelo e do conector usado: confirmar sua especificação antes de
ligar. Não aplicar a tensão de entrada diretamente aos componentes.

### ESP32 durante testes por USB

- USB do computador alimenta o ESP32 e permite gravação e Monitor Serial.
- VIN não se conecta ao trilho externo de 5 V.
- 3V3 do ESP32 não se conecta ao trilho externo de 3,3 V.
- GND do ESP32 permanece unido ao GND da fonte e dos componentes.
- O RGB é alimentado pelo **3V3 do próprio ESP32**, conforme seção 6.

### ESP32 sem computador

- Pode ser alimentado por carregador USB adequado, mantendo VIN desconectado.
- Alternativamente, alimentar VIN/5V pelo trilho regulado de 5 V **somente
  após confirmar que a placa aceita essa entrada**.
- Não usar simultaneamente USB e 5 V externo no VIN sem verificar o circuito
  de proteção da placa. Desconectar a ligação externa ao VIN antes de usar USB.
- Mesmo nessa configuração, não unir a saída externa de 3,3 V ao 3V3 do ESP32.

## 4. RFID RC522

| Terminal | Conexão |
|---|---|
| 3.3V | Trilho externo de 3,3 V |
| GND | GND comum |
| SCK / MISO / MOSI | GPIO 18 / 19 / 23 |
| SDA / SS e RST | GPIO 32 e 33 |
| IRQ | Desconectado |

**Não alimentar o RC522 com 5 V.** Usar fios curtos, contatos firmes e conferir
se a barra de pinos está soldada. A comunicação usa
`SPI.begin(18, 19, 23, 32)` e `MFRC522 rfid(32, 33)`.

Para teste isolado, o 3.3V do leitor pode vir diretamente do 3V3 do ESP32 por
USB, mas antes é necessário desconectá-lo da alimentação externa. Não unir
as duas saídas de 3,3 V. A leitura de UID foi confirmada no teste do chat.

## 5. OLED SSD1306

| Terminal | Conexão |
|---|---|
| VCC | Trilho de 3,3 V; no teste isolado, 3V3 do ESP32 |
| GND | GND comum |
| SDA | GPIO 21 |
| SCL | GPIO 22 |

Endereço esperado: `0x3C`; alguns módulos usam `0x3D`.
No script integrado do chat, usa o segundo controlador, `TwoWire(1)`,
inicializado com `begin(21, 22)`, separado do LCD.

## 6. LED RGB de ânodo comum

```text
3V3 do próprio ESP32 ───────────────── COM
GPIO 25 ── resistor de 220 Ω ───────── R
GPIO 27 ── resistor de 220 Ω ───────── G
B ─────────────────────────────────── desconectado
```

- LOW acende a cor; HIGH apaga.
- Cada cor utiliza seu próprio resistor em série.
- COM não vai ao GND nessa montagem.
- Identificar os terminais pelo modelo/teste; a ordem das pernas não é universal.

**Não alimentar o COM pelo trilho externo enquanto o ESP32 estiver desligado.**
Foi observado que o RGB acendia nessa condição e apagava ao retirar os fios
dos GPIOs, comportamento compatível com corrente entrando pela placa
desligada. Manter COM no 3V3 do próprio ESP32 evita esse caminho externo no RGB.
Isso não elimina possíveis caminhos pelos sinais de outros módulos alimentados.

No firmware, a configuração correspondente é `FEEDBACK_LED_ACTIVE_LOW 1`,
com vermelho no 25 e verde no 27, já incorporada ao perfil físico do arquivo-modelo.

## 7. Buzzer

| Terminal | Conexão |
|---|---|
| Positivo / 1 | GPIO 14 |
| Negativo / 2 | GND comum |

A ligação direta é apenas para piezo passivo compatível com a corrente e
tensão do GPIO. Buzzer magnético, de 5 V ou de corrente desconhecida pode
precisar de transistor/driver e proteção conforme seu modelo. Um módulo de
três pinos tem alimentação e sinal separados: não tratar como buzzer de dois pinos.

O teste usa `tone()` e `noTone()`. O GPIO 12 foi evitado por interferir na
seleção de tensão da flash durante o boot do ESP32 clássico. No teste
integrado, som breve em espera e agudo ao ler uma tag. Frequência não é
controle de volume.

## 8. LCD 1602 I²C — atenção à tensão

| Terminal | Conexão de teste sem conversor |
|---|---|
| VCC | **3,3 V**, sem garantia de funcionamento para todo modelo |
| GND | GND comum |
| SDA | GPIO 16 / RX2 |
| SCL | GPIO 17 / TX2 |

Endereço esperado: `0x27`; confirmar por varredura I²C se não responder.
No script integrado, o LCD usa `Wire.begin(16, 17)` e a biblioteca
LiquidCrystal I2C de Frank de Brabander, que usa o barramento global `Wire`.
Ajustar o potenciômetro traseiro para contraste.

**A ligação inicial do LCD ao trilho de 5 V não é a configuração segura
aprovada para testes com sinais diretos.** Não foi informado que um conversor
de nível tenha sido adquirido. O teste proposto posteriormente foi em 3,3 V;
o funcionamento nessa tensão depende do conjunto LCD/adaptador.

Se for necessário alimentar o LCD em 5 V, verificar os pull-ups de SDA/SCL e
usar conversor bidirecional I²C quando eles puxarem os sinais para 5 V:

```text
GPIO 16 ── LV1 [conversor] HV1 ── SDA do LCD
GPIO 17 ── LV2 [conversor] HV2 ── SCL do LCD
3,3 V ─── LV
5 V ───── HV e VCC do LCD
GND ───── GND do conversor, LCD e ESP32
```

Usar GPIOs separados não resolve incompatibilidade de tensão. O ESP32 não
tolera 5 V nos GPIOs. Sem compatibilidade comprovada ou conversor, manter o
LCD desconectado se ele não funcionar em 3,3 V.

## 9. Servo

| Terminal | Conexão |
|---|---|
| V+ | Alimentação regulada de 5 V com corrente adequada ao modelo |
| GND | GND comum da alimentação e do ESP32 |
| Sinal / PWM | GPIO 26 |

Não alimentar pelo 3V3 nem diretamente pela tensão de entrada do módulo.
O módulo de protoboard pode não suportar os picos de corrente do servo: usar
fonte/regulador adequado e distribuir a alimentação sem sobrecarregar o módulo.

O modelo físico ainda não foi confirmado. Em servo posicional, `write(90)`
seleciona posição; em rotação contínua, costuma ficar próximo da parada, mas
pode exigir calibração. No script integrado, `TESTAR_SERVO` fica `false` por
padrão até confirmar o tipo e a alimentação. Testar com eixo livre.

## 10. Conferência antes de ligar

1. Desligar USB e fonte antes de mover fios.
2. Conferir polaridade, jumpers e continuidade dos trilhos.
3. Confirmar saídas próximas de 5 V e 3,3 V com multímetro em tensão contínua,
   se disponível; nunca colocar a escala de corrente diretamente entre trilhos.
4. Conferir todos os GNDs, sem unir as saídas positivas.
5. Conferir os dois resistores do RGB e COM no 3V3 do ESP32.
6. Confirmar que o LCD não leva 5 V aos GPIOs.
7. Evitar módulos externos alimentados enviando sinais a um ESP32 desligado.
8. Acrescentar componentes gradualmente, deixando o servo por último.
9. Se o LED do módulo apagar sob carga, houver aquecimento forte ou cheiro,
   desligar e investigar curto, polaridade ou sobrecarga antes de continuar.

**Estado observado:** o módulo de alimentação permaneceu ligado sem cargas;
isso não comprova que suporte todos os componentes, especialmente o servo.
