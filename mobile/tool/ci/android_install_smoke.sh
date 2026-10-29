#!/usr/bin/env bash
# Instala o APK no aparelho/emulador conectado (adb), abre o app e falha se ele
# nao instalar, nao subir, nao ficar em primeiro plano ou cair na abertura.
# Nao exige backend.
# Uso: android_install_smoke.sh <apk>
# Ajustes do teste host: SMOKE_FOCUS_TIMEOUT e SMOKE_OBSERVE_SECONDS (segundos).
set -euo pipefail

apk="${1:?uso: android_install_smoke.sh <apk>}"
package="br.fatec.errorsquad.controle_acesso"
activity="$package.MainActivity"
focus_timeout="${SMOKE_FOCUS_TIMEOUT:-20}"
observe_seconds="${SMOKE_OBSERVE_SECONDS:-15}"

adb wait-for-device
adb shell 'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 1; done'

# A chave debug pode mudar entre execucoes; sobre uma build de assinatura diferente
# o install falha com INSTALL_FAILED_UPDATE_INCOMPATIBLE. Desinstale antes:
# adb uninstall "$package"
adb install -r "$apk"
grep -qxF "package:$package" <<<"$(adb shell pm list packages | tr -d '\r')" \
  || { echo "FALHA: $package nao aparece em pm list packages" >&2; exit 1; }

adb logcat -c
adb shell monkey -p "$package" -c android.intent.category.LAUNCHER 1

# O motor Flutter leva alguns segundos para subir em emulador sem aceleracao de GPU.
pid=""
for _ in $(seq 1 30); do
  pid="$(adb shell pidof "$package" | tr -d '\r' || true)"
  if [ -n "$pid" ]; then break; fi
  sleep 1
done
[ -n "$pid" ] || { echo "FALHA: o app nao iniciou" >&2; adb logcat -d | tail -n 80; exit 1; }

# PID vivo nao prova abertura: app travado no splash tambem mantem o processo.
# O sinal de "abriu" e a activity principal em primeiro plano. O campo componente
# e comparado inteiro: mCurrentFocus traz "pkg/pkg.MainActivity", mas o mFocusedApp
# do Android 14 abrevia para "pkg/.MainActivity" — as duas formas valem.
focus_dump() {
  adb shell dumpsys window 2>/dev/null | tr -d '\r' || true
}
focused() {
  awk -v full="$package/$activity" -v abbrev="$package/.${activity##*.}" '
    /^mCurrentFocus=|^mFocusedApp=/ {
      for (i = 1; i <= NF; i++) {
        c = $i
        sub(/[},]+$/, "", c)
        if (c == full || c == abbrev) found = 1
      }
    }
    END { exit found ? 0 : 1 }
  ' <<<"$1"
}

opened=0
for _ in $(seq 1 "$focus_timeout"); do
  if focused "$(focus_dump)"; then opened=1; break; fi
  sleep 1
done
if [ "$opened" -ne 1 ]; then
  echo "FALHA: o app nao ficou em primeiro plano ($package/$activity)" >&2
  adb shell dumpsys activity activities 2>/dev/null | tail -n 40 >&2 || true
  exit 1
fi

# Janela de observacao: o app precisa continuar vivo e em primeiro plano.
sleep "$observe_seconds"
pid="$(adb shell pidof "$package" | tr -d '\r' || true)"
crash_log="$(adb logcat -d -b crash || true)"
if [ -z "$pid" ] || grep -qF "$package" <<<"$crash_log"; then
  echo "FALHA: o app caiu depois de abrir" >&2
  printf '%s\n' "$crash_log" >&2
  exit 1
fi
if ! focused "$(focus_dump)"; then
  echo "FALHA: o app saiu de primeiro plano depois de abrir" >&2
  exit 1
fi

echo "OK: $package instalado, em primeiro plano e em execucao (pid $pid)"
