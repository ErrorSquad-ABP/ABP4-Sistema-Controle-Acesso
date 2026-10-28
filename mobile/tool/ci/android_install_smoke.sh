#!/usr/bin/env bash
# Instala o APK no aparelho/emulador conectado (adb), abre o app e falha se ele
# nao instalar, nao subir ou cair na abertura. Nao exige backend.
# Uso: android_install_smoke.sh <apk>
set -euo pipefail

apk="${1:?uso: android_install_smoke.sh <apk>}"
package="br.fatec.errorsquad.controle_acesso"

adb wait-for-device
adb shell 'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 1; done'

adb install -r "$apk"
adb shell pm list packages | grep -q "^package:$package\$"

adb logcat -c
adb shell monkey -p "$package" -c android.intent.category.LAUNCHER 1

# O motor Flutter leva alguns segundos para subir em emulador sem aceleracao de GPU.
pid=""
for _ in $(seq 1 30); do
  pid="$(adb shell pidof "$package" | tr -d '\r' || true)"
  [ -n "$pid" ] && break
  sleep 1
done
[ -n "$pid" ] || { echo "FALHA: o app nao iniciou" >&2; adb logcat -d | tail -n 80; exit 1; }

# Janela de observacao: o app precisa continuar vivo depois da abertura.
sleep 15
pid="$(adb shell pidof "$package" | tr -d '\r' || true)"
if [ -z "$pid" ] || adb logcat -d -b crash | grep -q "$package"; then
  echo "FALHA: o app caiu depois de abrir" >&2
  adb logcat -d -b crash
  exit 1
fi

echo "OK: $package instalado e em execucao (pid $pid)"
