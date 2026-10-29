#!/usr/bin/env bash
# Teste host do verify_apk.sh: apksigner e aapt simulados num SDK temporario, sem
# Android SDK nem APK real. Cobre identidade do signatario e comparacao literal
# dos campos (evita falso positivo de regex com "." solto).
# Uso: bash mobile/tool/ci/test_verify_apk.sh
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
verify="$here/verify_apk.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

tools="$tmp/sdk/build-tools/35.0.0"
mkdir -p "$tools"
apk="$tmp/app-release.apk"
printf 'apk fake\n' >"$apk"

pkg="br.fatec.errorsquad.controle_acesso"
activity="$pkg.MainActivity"

cat >"$tools/aapt" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$FAKE_BADGING"
FAKE

cat >"$tools/apksigner" <<'FAKE'
#!/usr/bin/env bash
case " $* " in
  *" --print-certs "*) printf 'Signer #1 certificate DN: %s\n' "${FAKE_CERT_DN:-CN=Android Debug, O=Android, C=US}" ;;
esac
FAKE

chmod +x "$tools/aapt" "$tools/apksigner"

badging() {
  cat <<EOF
package: name='$1' versionCode='42' versionName='1.0.0' platformBuildVersionName='14'
sdkVersion:'21'
targetSdkVersion:'34'
uses-permission: name='android.permission.INTERNET'
uses-permission: name='android.permission.CAMERA'
uses-permission: name='android.permission.ACCESS_FINE_LOCATION'
application-label:'Controle de Acesso'
launchable-activity: name='$2'  label='' icon=''
native-code: 'arm64-v8a' 'armeabi-v7a' 'x86_64'
EOF
}

failures=0
expect() {
  local desc="$1" want="$2" rc=0 out
  out="$(ANDROID_HOME="$tmp/sdk" bash "$verify" "$apk" 2>&1)" || rc=$?
  if [ "$want" = "0" ] && [ "$rc" -ne 0 ]; then
    echo "FALHA: $desc — esperava sucesso, saiu $rc"
    printf '%s\n' "$out"
    failures=$((failures + 1))
  elif [ "$want" != "0" ] && [ "$rc" -eq 0 ]; then
    echo "FALHA: $desc — esperava falha, saiu 0"
    failures=$((failures + 1))
  fi
}

# 1. Pacote completo assinado com a chave debug: aprovado.
FAKE_BADGING="$(badging "$pkg" "$activity")"
export FAKE_BADGING
expect "pacote completo com assinatura debug" 0

# 2. Pacote com separadores trocados: regex com "." solto aprovava por engano.
FAKE_BADGING="$(badging "brXfatecYerrorsquadZcontrole_acesso" "$activity")"
expect "pacote com separadores trocados" 1

# 3. Activity de entrada de outro app: reprovado.
FAKE_BADGING="$(badging "$pkg" "com.outro.app.MainActivity")"
expect "activity de entrada de outro pacote" 1

# 4. Permissao de localizacao ausente: reprovado.
FAKE_BADGING="$(badging "$pkg" "$activity" | grep -v ACCESS_FINE_LOCATION)"
expect "sem permissao de localizacao" 1

# 5. Sem binarios arm64-v8a: reprovado.
FAKE_BADGING="$(badging "$pkg" "$activity" | sed "s/'arm64-v8a' //")"
expect "sem arm64-v8a" 1

# 6. Assinado com chave que nao e a debug: reprovado.
FAKE_BADGING="$(badging "$pkg" "$activity")"
export FAKE_CERT_DN='CN=Controle Acesso, O=FATEC, C=BR'
expect "assinatura que nao e a chave debug" 1
export FAKE_CERT_DN='CN=Android Debug, O=Android, C=US'

# 7. apksigner ausente: degrada com aviso, sem derrubar o job.
mv "$tools/apksigner" "$tools/apksigner.off"
expect "apksigner ausente" 0
out="$(ANDROID_HOME="$tmp/sdk" bash "$verify" "$apk" 2>&1 || true)"
grep -q "AVISO" <<<"$out" || {
  echo "FALHA: apksigner ausente — faltou aviso explicito"
  failures=$((failures + 1))
}
mv "$tools/apksigner.off" "$tools/apksigner"

if [ "$failures" -ne 0 ]; then
  echo "FALHA: $failures caso(s) do verify_apk.sh"
  exit 1
fi
echo "OK: verify_apk.sh (7 casos)"
