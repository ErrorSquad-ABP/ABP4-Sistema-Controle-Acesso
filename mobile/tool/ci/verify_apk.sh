#!/usr/bin/env bash
# Confere que o APK gerado e um pacote Android valido para o aparelho de referencia
# (arm64, Android 7+): assinatura, identidade, permissoes do scanner e ABI.
# Uso: verify_apk.sh <apk>   (exige ANDROID_HOME com build-tools instalado)
set -euo pipefail

apk="${1:?uso: verify_apk.sh <apk>}"
expected_package="br.fatec.errorsquad.controle_acesso"

[ -s "$apk" ] || { echo "APK ausente ou vazio: $apk" >&2; exit 1; }

sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
[ -n "$sdk" ] || { echo "ANDROID_HOME nao definido" >&2; exit 1; }
tools="$(find "$sdk/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
[ -n "$tools" ] || { echo "build-tools nao encontrado em $sdk" >&2; exit 1; }

fail=0
require() {
  if ! grep -q -- "$2" <<<"$badging"; then
    echo "FALHA: $1 (esperado: $2)" >&2
    fail=1
  fi
}

"$tools/apksigner" verify --verbose "$apk"

badging="$("$tools/aapt" dump badging "$apk")"
require "pacote com identidade errada" "package: name='$expected_package'"
require "sem activity de entrada" "launchable-activity: name='$expected_package.MainActivity'"
require "sem permissao de camera" "uses-permission: name='android.permission.CAMERA'"
require "sem permissao de localizacao" "uses-permission: name='android.permission.ACCESS_FINE_LOCATION'"
require "sem permissao de internet" "uses-permission: name='android.permission.INTERNET'"
require "sem binarios arm64-v8a" "native-code:.*'arm64-v8a'"

grep -E "^(package|sdkVersion|targetSdkVersion|native-code|application-label):" <<<"$badging"
echo "tamanho: $(du -h "$apk" | cut -f1)"

exit "$fail"
