# US-23 · NFC RC522 + feedback de decisão

Épico E3 · sprint alvo S3. Implementação, resultados automatizados e evidências
da validação inicial em hardware. Referência: `docs/scrum/product-backlog.md`
e arquivo de conexões da montagem em 07/11/2026.

**Como reproduzir:** [guia de teste local da US-23](../../guides/testar-us-23-nfc.md).
O fechamento do card depende de revisão/aceite do time; os limites e casos
manuais ainda não registrados estão explicitados abaixo.

## Escopo implementado

- Leitura RC522 SPI com GPIOs 18/19/23/32/33 e UID hexadecimal maiúsculo.
- Uma tentativa por apresentação; ausência de 500 ms rearma a mesma tag.
- MQTT v1 com UUID/UTC, QoS 1/PUBACK e sem retain; backend decide com o fluxo
  existente (`DatabaseAccessDecider` → `DecideAccessUseCase`), grava o evento e
  devolve `open`/`deny`. Não há lista local de tags autorizadas.
- Comando válido gera feedback RGB de ânodo comum e, quando habilitado, piezo;
  comandos duplicados/vencidos continuam protegidos pelo handler existente.
- Perfil físico com OLED/status e LCD opcional; perfil TFT legado separado.
- Servo e buzzer desabilitados no exemplo físico até confirmar os componentes.
  Nesse modo, `open` confirma somente feedback, nunca movimento físico.

## Validação reproduzível

### Resultados automatizados registrados

- Backend: `npm run lint`, `npm run typecheck` e `npm run build` aprovados.
- `npm test`: **357 aprovados**, 31 pulados por dependerem de banco configurado.
- `npm run test:e2e`: **31 aprovados**, com PostgreSQL/broker temporários,
  incluindo tag NFC desconhecida e revogada, decisão `deny`, ACK e ausência de
  consumo de autorização. O cenário NFC autorizado existente também passou.
- Firmware host: lógica pura, módulo RC522 com leitor simulado (incluindo
  leitor ausente), feedback nos dois perfis, MQTT/NFC e renderização QR com as
  bibliotecas reais ArduinoJson 7.4.3 e QRCode 0.0.1 aprovados.
- Builds PlatformIO dos perfis `esp32dev` (NFC físico) e `esp32dev-wokwi`
  (TFT legado) aprovados, com geração de `firmware.elf` e `firmware.bin`, usando
  cópia temporária da configuração de exemplo, sem sobrescrever o `config.h` local.
- Compilação adicional do perfil físico com LCD, buzzer e servo habilitados
  também aprovada em configuração temporária; não houve gravação nem atuação
  em hardware, e o exemplo versionado mantém esses recursos desabilitados.

No Windows, a toolchain temporária precisou de caminhos mais curtos para
evitar erro `CreateProcess` do GCC e dos módulos Python do esptool 4.5.1 para
gerar o bootloader. São ajustes do ambiente de build, não da pinagem/firmware.

O E2E usa terminal simulado, não o ESP32 físico. O observador filtra QRs pelo
terminal principal para não misturar tokens dos terminais isolados dos testes.
O `initdb --no-sync` é exclusivo do cluster descartável de teste; não modifica
a durabilidade do banco da aplicação.

### Evidência física registrada nesta sessão

- ESP32-D0WD-V3, firmware `esp32dev`, gravado por USB na COM3, com verificação
  do hash da gravação. A COM é específica da máquina de teste.
- Serial confirmou `[nfc] RC522 pronto` e
  `[mqtt] conectado e inscrito nos comandos` na placa real.
- A montagem foi informada como validada pelo responsável; utilizou-se a
  pinagem documentada, com buzzer/LCD habilitados e **servo desabilitado**.
- No primeiro boot foi identificado `noTone()` antes da inicialização do
  LEDC. O firmware passou a manter o piezo em LOW antes do primeiro `tone()`.
  Testes de GPIO nos dois perfis passaram e a nova gravação iniciou sem aqueles
  avisos LEDC.
- O responsável relatou vermelho/apito para a tag ainda desconhecida e depois
  acesso autorizado após associá-la à credencial demo. O banco e os ACKs foram
  consultados para correlacionar as decisões:

| Tentativa (`AccessEvent.id`) | Decisão | Motivo | Credencial reconhecida | Comando (`commandId`) | ACK |
|---|---|---|---|---|---|
| `85665498-091f-4f67-8e73-51eaa8d7cade` | `DENIED` | `INVALID_CREDENTIAL` | não | `dcae3fb6-d143-446c-97ca-63be8fcaae3c` | `executed` |
| `804cc581-1a13-4e41-9444-8616a0561759` | `GRANTED` | — | sim | `b5e13de2-eb2b-43dc-af10-ac0153425e47` | `executed` |
| `202a23e7-252e-484d-b0c5-ea773d27a18d` | `GRANTED` | — | sim | `390019c6-2b71-4aa9-84ac-1f337edba994` | `executed` |

Os IDs identificam registros do banco local de teste, não fixtures universais.
UID, hash da credencial, senha Wi-Fi, `.env` e `config.h` não são publicados.
ACK `executed` confirma feedback nesta configuração de bancada, **não movimento
da cancela**. Cor/som são observações do responsável; não há vídeo anexado aqui.

**Ainda sem registro físico específico:** tag revogada, permanência de 10 s no
leitor sem repetição, duplicata/expiração de comandos e falhas de rede/relógio.
Esses comportamentos têm cobertura automática, mas não devem ser apresentados
como se todos tivessem sido demonstrados na montagem real.

### Roteiro em hardware

1. Confira a montagem e os alertas de alimentação no
   [guia de conexões](../../guides/conexoes-hardware.md). Não ligue o LCD com
   pull-ups de 5 V diretamente ao ESP32. Não alimente RC522 com 5 V.
2. Migre o `config.h` local para o novo exemplo sem expor senhas. Configure
   WiFi, IP/porta do broker e um `TERMINAL_ID` cadastrado no backend. Use broker
   dev na LAN; este firmware não implementa transporte TLS para produção.
3. Suba Postgres/Mosquitto, aplique migrations e seed de desenvolvimento conforme
   `backend/README.md`; inicie o worker com **`ACCESS_MODE=real`**. Não use o
   decisor demo permissivo para comprovar validação de credenciais.
4. Compile/grave `pio run -e esp32dev -t upload` e abra o monitor a 115200.
   Confirme `[nfc] RC522 pronto`, conexão MQTT e hora SNTP confiável.
5. Cadastre uma credencial cujo `valueHash` seja SHA-256 do UID maiúsculo, com
   usuário ativo e autorização válida para o local do terminal. A seed usa
   `04A1B2C3`, que provavelmente não corresponde à tag física: não invente um
   UID no firmware para fazer a seed passar.
6. Aproxime a tag autorizada: conferir evento `GRANTED` no histórico, comando
   `open`, LED verde e ACK correlacionado. Som somente com piezo habilitado.
   Se o servo estiver desabilitado, esse teste **não prova abertura física**.
7. Aproxime tag desconhecida e depois uma revogada: conferir `DENIED`, comando
   `deny`, LED vermelho/bipe grave, sem movimento e sem consumo de autorização.
8. Mantenha a tag no leitor por 10 s: apenas uma tentativa. Retire por pelo
   menos 500 ms e reapresente: uma nova tentativa, com novo `messageId`.
9. Repita o mesmo `commandId`: ACK de duplicata sem repetir LED/buzzer/servo.
   Envie um comando vencido: ACK `expired`, sem atuação.
10. Teste sem WiFi/broker, antes de SNTP e com RC522 desconectado (desligue a
    alimentação antes de mover fios): nenhuma liberação. Recuperar a rede não
    deve reenviar a tag mantida no leitor; retirar/reapresentar para nova leitura.

Registrar separadamente data, placa, configuração não secreta, comandos/ACKs
e eventos observados. Não publicar senhas ou UIDs completos nos logs da evidência.
Build e testes automatizados não substituem esse roteiro físico. Retry offline
persistente é US-25; heartbeat/GPS é US-24. QR em tela pequena permanece uma
limitação explícita do perfil físico, sem regressão do perfil TFT da US-22.
