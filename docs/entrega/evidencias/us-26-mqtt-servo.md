# US-26 — Comando de abertura do servo via MQTT

- **Data**: 26/10/2026 · **Branch**: `feat/sprint-2-us`
- **Origem**: comportamento entregue junto com a US-08 (PRs #19 e #25); este documento registra a verificação de aceite.

## Critérios e onde são cobertos

| Critério | Evidência |
|---|---|
| Abertura comandada por MQTT (`action: open`) | `firmware/tests/test_mqtt_command.cpp` entrega o JSON v1 no tópico `terminals/{id}/commands` e o atuador é chamado uma vez |
| Timeout de segurança (não abre duas vezes) | `command.h` deduplica por `commandId` (janela das últimas 8 respostas) e `door_machine.h` só aceita `requestOpen` em `idle` |
| Comando expirado não move o servo | caso `expiresAt` no passado → ACK `expired`, atuador não chamado |
| Sem relógio confiável não abre | caso `clock_unsynced` → ACK `rejected` |
| ACK correlacionado | `status: executed` publicado em `terminals/{id}/acks` com o mesmo `commandId` |
| `deny` não move a cancela | caso `action: deny` → LED/buzzer de negado e ACK `executed` |

## Comando executado

```bash
pio pkg install -e esp32dev
g++ -std=c++11 -Wall -Wextra -Werror -I tests/fakes -I include -I src \
  -isystem .pio/libdeps/esp32dev/ArduinoJson/src \
  tests/test_mqtt_command.cpp src/modules/mqtt.cpp -o /tmp/t-mqtt-command && /tmp/t-mqtt-command
```

Resultado: `mqtt: JSON v1, prazo, dedup, ACK e recusas OK`.

## O que o teste não prova

O movimento físico do servo e o feedback de LED/buzzer só são observáveis na simulação Wokwi (ou no hardware), que exige Docker, broker Mosquitto e licença do Wokwi. Build e testes host verdes não substituem essa demonstração.
