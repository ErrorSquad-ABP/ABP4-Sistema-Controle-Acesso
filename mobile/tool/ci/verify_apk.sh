#!/usr/bin/env bash
# Confere que o APK gerado e um pacote Android valido para o aparelho de referencia
# (arm64, Android 7+): assinatura, identidade do signatario, permissoes do scanner e ABI.
# Uso: verify_apk.sh <apk>   (exige ANDROID_HOME com build-tools instalado)
set -euo pipefail

apk="${1:?uso: verify_apk.sh <apk>}"
expected_package="br.fatec.errorsquad.controle_acesso"
expected_activity="$expected_package.MainActivity"

[ -s "$apk" ] || { echo "APK ausente ou vazio: $apk" >&2; exit 1; }

sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
[ -n "$sdk" ] || { echo "ANDROID_HOME nao definido" >&2; exit 1; }
tools="$(find "$sdk/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
[ -n "$tools" ] || { echo "build-tools nao encontrado em $sdk" >&2; exit 1; }

fail=0
fail_msg() {
  echo "FALHA: $1" >&2
  fail=1
}

# Campos lidos do badging e comparados por igualdade: regex com "." solto aprovaria
# um pacote como brXfatecYerrorsquadZcontrole_acesso.
name_of() {
  sed -n "s/^$1: name='\([^']*\)'.*/\1/p" <<<"$badging"
}

# O DN vem como "Signer #1 certificate DN: CN=Android Debug, O=Android, C=US".
# Comparar substring aprovaria "CN=Android Debug Evil"; o CN tem de ser o campo
# inteiro, terminando em "," ou no fim do DN. Caixa e espacos ao redor do "="
# variam entre versoes do build-tools.
debug_cn() {
  awk '
    {
      i = index($0, "certificate DN:")
      if (!i) next
      dn = substr($0, i + length("certificate DN:"))
      n = split(dn, field, ",")
      for (j = 1; j <= n; j++) {
        f = field[j]
        gsub(/^[ \t]+|[ \t]+$/, "", f)
        gsub(/[ \t]+/, " ", f)
        gsub(/[ \t]*=[ \t]*/, "=", f)
        if (tolower(f) == "cn=android debug") found = 1
      }
    }
    END { exit found ? 0 : 1 }
  '
}

# A chave debug e a unica disponivel: se o certificado nao for ela, o APK nao e o
# release esperado. Sem apksigner nao ha como provar a identidade — que e o aceite —
# entao falha em vez de seguir: um check que nao verifica nada nao serve.
if [ ! -x "$tools/apksigner" ]; then
  fail_msg "apksigner ausente em $tools; instale/atualize o build-tools do ANDROID_HOME e rode de novo (sem ele a assinatura nao e verificada)"
else
  "$tools/apksigner" verify --verbose "$apk"
  # Sem ancorar no prefixo: o build-tools escolhido pelo runner pode mudar o rotulo,
  # e a saida do apksigner ja variou entre stdout e stderr. O DN e o sinal que importa.
  certs="$("$tools/apksigner" verify --print-certs "$apk" 2>&1 || true)"
  if ! debug_cn <<<"$certs"; then
    printf '%s\n' "--- apksigner --print-certs ---" "$certs" >&2
    fail_msg "assinatura nao e a chave debug"
  fi
fi

badging="$("$tools/aapt" dump badging "$apk")"

[ "$(name_of package)" = "$expected_package" ] \
  || fail_msg "pacote com identidade errada (esperado: $expected_package)"
[ "$(name_of launchable-activity)" = "$expected_activity" ] \
  || fail_msg "sem activity de entrada (esperado: $expected_activity)"

permissions="$(name_of uses-permission)"
for permission in CAMERA ACCESS_FINE_LOCATION INTERNET; do
  grep -qxF "android.permission.$permission" <<<"$permissions" \
    || fail_msg "sem permissao android.permission.$permission"
done

abis="$(sed -n 's/^native-code: //p' <<<"$badging" | grep -o "'[^']*'" | tr -d "'")"
grep -qxF arm64-v8a <<<"$abis" || fail_msg "sem binarios arm64-v8a"

grep -E "^(package|sdkVersion|targetSdkVersion|native-code|application-label):" <<<"$badging"
echo "tamanho: $(du -h "$apk" | cut -f1)"

exit "$fail"
