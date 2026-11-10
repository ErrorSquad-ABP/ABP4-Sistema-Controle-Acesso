set -e
ID=$(cat /proc/sys/kernel/random/uuid)
TS=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
mosquitto_pub -h "$MQTT_HOST" -p 8883 --cafile /ca.crt -u terminal-dev-01 -P "$TERMINAL_PASSWORD" \
  -t terminals/terminal-dev-01/status -r -q 1 \
  -m "{\"v\":1,\"messageId\":\"$ID\",\"terminalId\":\"terminal-dev-01\",\"timestamp\":\"$TS\",\"state\":\"online\"}"
echo "status online publicado (retido) para terminal-dev-01"
