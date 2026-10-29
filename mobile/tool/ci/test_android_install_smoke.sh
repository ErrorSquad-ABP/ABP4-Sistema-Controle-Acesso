#!/usr/bin/env bash
# Teste host do android_install_smoke.sh: adb simulado. Cobre app travado no splash
# (nao ganha foco), app aberto de fato (inclusive no formato do Android 14, com o
# componente abreviado no mFocusedApp) e crash na abertura. Sem emulador.
# Uso: bash mobile/tool/ci/test_android_install_smoke.sh
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
smoke="$here/android_install_smoke.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

pkg="br.fatec.errorsquad.controle_acesso"
fakebin="$tmp/bin"
state="$tmp/state"
mkdir -p "$fakebin" "$state"
apk="$tmp/app-release.apk"
printf 'apk fake\n' >"$apk"

cat >"$fakebin/adb" <<'FAKE'
#!/usr/bin/env bash
# adb simulado: foco e crash vem de $FAKE_STATE, o resto e fixo.
case "${1:-}" in
  wait-for-device|install) exit 0 ;;
  logcat)
    if [ "${FAKE_CRASH:-0}" = 1 ] && [ "${2:-}" != "-c" ]; then
      echo "FATAL EXCEPTION: br.fatec.errorsquad.controle_acesso"
    fi
    exit 0 ;;
  shell)
    shift
    case "$*" in
      *boot_completed*) echo 1 ;;
      *"pm list packages"*) echo "package:$FAKE_PACKAGE" ;;
      *monkey*) exit 0 ;;
      *pidof*) [ "${FAKE_PID:-1}" = 1 ] && echo 4242; exit 0 ;;
      *dumpsys*) cat "$FAKE_STATE/focus" ;;
    esac
    exit 0 ;;
esac
exit 0
FAKE
chmod +x "$fakebin/adb"

cat >"$state/splash" <<EOF
mCurrentFocus=Window{9f3 u0 com.android.launcher3/com.android.launcher3.Launcher}
mFocusedApp=ActivityRecord{a1 u0 com.android.launcher3/.Launcher t1}
EOF

cat >"$state/app" <<EOF
mCurrentFocus=Window{e42 u0 $pkg/$pkg.MainActivity}
mFocusedApp=ActivityRecord{b7 u0 $pkg/.MainActivity t7}
EOF

# Android 14: o mCurrentFocus pode estar em outro componente (IME, dialogo) e o
# app so aparece no mFocusedApp, com o componente abreviado ($pkg/.MainActivity).
cat >"$state/app14" <<EOF
mCurrentFocus=Window{71 u0 InputMethod}
mFocusedApp=ActivityRecord{1e9dd9c u0 $pkg/.MainActivity t42}
EOF

# Componente parecido, mas nao a MainActivity: nao pode passar.
cat >"$state/evil" <<EOF
mCurrentFocus=Window{71 u0 InputMethod}
mFocusedApp=ActivityRecord{1e9dd9c u0 $pkg/.MainActivityEvil t42}
EOF

failures=0
run() {
  local desc="$1" want="$2" rc=0 out
  out="$(PATH="$fakebin:$PATH" FAKE_STATE="$state" FAKE_PACKAGE="$pkg" \
    SMOKE_FOCUS_TIMEOUT=2 SMOKE_OBSERVE_SECONDS=1 \
    bash "$smoke" "$apk" 2>&1)" || rc=$?
  if [ "$want" = "0" ] && [ "$rc" -ne 0 ]; then
    echo "FALHA: $desc — esperava sucesso, saiu $rc"
    printf '%s\n' "$out"
    failures=$((failures + 1))
  elif [ "$want" != "0" ] && [ "$rc" -eq 0 ]; then
    echo "FALHA: $desc — esperava falha, saiu 0"
    failures=$((failures + 1))
  fi
}

# 1. App travado no splash: processo vivo e sem crash, mas sem foco -> falha.
cp "$state/splash" "$state/focus"
run "app travado no splash" 1

# 2. App realmente em primeiro plano -> sucesso.
cp "$state/app" "$state/focus"
run "app aberto em primeiro plano" 0

# 3. Crash na abertura -> falha.
FAKE_CRASH=1 run "crash na abertura" 1

# 4. Formato do Android 14: foco em outro componente e componente abreviado no
#    mFocusedApp -> sucesso.
cp "$state/app14" "$state/focus"
run "activity em primeiro plano no formato do Android 14" 0

# 5. Componente parecido (.MainActivityEvil) nao e a activity principal -> falha.
cp "$state/evil" "$state/focus"
run "componente parecido com a MainActivity" 1

if [ "$failures" -ne 0 ]; then
  echo "FALHA: $failures caso(s) do android_install_smoke.sh"
  exit 1
fi
echo "OK: android_install_smoke.sh (5 casos)"
