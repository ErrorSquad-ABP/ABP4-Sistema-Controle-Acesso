# DT-10 — build Android no CI

Origem: parecer Sol de 21/10 (épico E1). Branch `fix/dt-10-build-android-ci`. Na Sprint 1 o APK não foi gerado por falta de Android SDK no ambiente local, e o `ci-mobile` só rodava `flutter analyze` e `flutter test`: widgets verdes não comprovavam o empacotamento Android.

## Critérios de aceite

| Critério | Como é atendido |
|---|---|
| Job de build Android no CI | `ci-mobile-build-android` em `.github/workflows/ci-mobile.yml`: JDK 17 + Flutter 3.47.7 + `flutter build apk --release` |
| Artifact publicado | `actions/upload-artifact`, nome `controle-acesso-apk`, arquivo `controle-acesso-<sha7>.apk`, retenção de 14 dias; `if-no-files-found: error` |
| APK instalável em aparelho de referência | `ci-mobile-install-android`: emulador Pixel 6, Android 14 (API 34, x86_64) instala o artefato e abre o app (`mobile/tool/ci/android_install_smoke.sh`) |
| Falha se o empacotamento quebrar | Erro do Gradle derruba o build; `mobile/tool/ci/verify_apk.sh` falha sem assinatura válida, com pacote/activity/permissões diferentes ou sem `arm64-v8a`; o job de instalação falha se o app não instalar, não subir ou cair |

## Decisões

- **Release, não debug**: exercita o mesmo caminho de empacotamento que será publicado (R8, ABIs, plugins nativos como `mobile_scanner` e `geolocator`).
- **Assinatura debug**: ainda não há keystore de release. O APK instala, mas não é distribuível; assinar de verdade e gerar AAB ficam para a publicação.
- **`--build-number=${{ github.run_number }}`**: `versionCode` crescente por execução, para instalar um APK sobre o anterior.
- **Jobs em paralelo ao `ci-mobile-check`**: erro de lint não esconde erro de empacotamento, e vice-versa.
- **Emulador como aparelho de referência**: é reprodutível no CI. Câmera e GPS reais não são cobertos e continuam na **DT-12**.

## Verificação

- Os scripts passam `bash -n`, e `verify_apk.sh` foi exercitado localmente com `apksigner`/`aapt` simulados (aprova pacote completo; reprova sem `arm64-v8a`).
- O YAML do workflow é válido.
- O build real e o emulador **só rodam no GitHub Actions**: esta máquina não tem Flutter nem Android SDK. O resultado deve ser conferido na execução do PR (`ci-mobile-build-android`, `ci-mobile-install-android` e o artefato).

## Pendências fora do código

- Incluir `ci-mobile-build-android` e `ci-mobile-install-android` nos checks obrigatórios da `main` (configuração do repositório); sem isso, os jobs rodam mas não bloqueiam o merge.
- Keystore de release como secret e geração de AAB, antes da publicação.
