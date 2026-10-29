# DT-10 — build Android no CI

Origem: parecer Sol de 21/10 (épico E1). Branch `fix/dt-10-build-android-ci`. Na Sprint 1 o APK não foi gerado por falta de Android SDK no ambiente local, e o `ci-mobile` só rodava `flutter analyze` e `flutter test`: widgets verdes não comprovavam o empacotamento Android.

## Critérios de aceite

| Critério | Como é atendido |
|---|---|
| Job de build Android no CI | `ci-mobile-build-android` em `.github/workflows/ci-mobile.yml`: JDK 17 + Flutter 3.47.7 + `flutter build apk --release` |
| Artifact publicado | `actions/upload-artifact`, nome `controle-acesso-apk`, arquivo `controle-acesso-<sha7>.apk`, retenção de 14 dias; `if-no-files-found: error` |
| APK instalável em aparelho de referência | `ci-mobile-install-android`: emulador Pixel 6, Android 14 (API 34, x86_64) instala o artefato e abre o app (`mobile/tool/ci/android_install_smoke.sh`) |
| Falha se o empacotamento quebrar | Erro do Gradle derruba o build; `mobile/tool/ci/verify_apk.sh` falha sem assinatura válida, com certificado que não é a chave debug, com pacote/activity/permissões diferentes ou sem `arm64-v8a`; o job de instalação falha se o app não instalar, não iniciar, não ficar em primeiro plano ou cair |

## Decisões

- **Release, não debug**: exercita o mesmo caminho de empacotamento que será publicado (R8, ABIs, plugins nativos como `mobile_scanner` e `geolocator`).
- **Assinatura debug**: ainda não há keystore de release. O APK instala, mas não é distribuível; assinar de verdade e gerar AAB ficam para a publicação. O `verify_apk.sh` confere com `apksigner verify --print-certs` que o certificado é o de debug (`CN=Android Debug`); sem `apksigner` no `build-tools`, avisa e segue sem verificar identidade.
- **`--build-number=${{ github.run_number }}`**: `versionCode` crescente por execução.
- **Reinstalação**: a chave debug é criada a cada runner, então o certificado muda entre execuções. Instalar uma build sobre outra de assinatura diferente falha com `INSTALL_FAILED_UPDATE_INCOMPATIBLE`; nesse caso, `adb uninstall br.fatec.errorsquad.controle_acesso` antes do `install -r`.
- **Campos do APK comparados por igualdade**: o badging é lido campo a campo (pacote, activity, permissões, ABI), não por regex com `.` solto, que aprovaria um pacote como `brXfatecYerrorsquadZcontrole_acesso`.
- **"Abriu" exige foco**: o smoke não aceita só PID vivo — app travado no splash mantém o processo. O script exige a activity principal em `mCurrentFocus`/`mFocusedApp` (`dumpsys window`), além de processo vivo e crash buffer vazio.
- **Jobs em paralelo ao `ci-mobile-check`**: erro de lint não esconde erro de empacotamento, e vice-versa.
- **Emulador como aparelho de referência**: é reprodutível no CI. Câmera e GPS reais não são cobertos e continuam na **DT-12**.

## Execução real (GitHub Actions)

Run [`40616157431`](https://github.com/ErrorsQuad/abp4-sistema-controle-acesso/actions/runs/40616157431):

- `ci-mobile-build-android`: verde em 4m52s; APK release de ~67,4 MB; artefato `controle-acesso-apk` publicado.
- `ci-mobile-install-android`: verde em 1m29s; APK instalado, aberto e ainda em primeiro plano ao fim da janela de observação.

## Verificação

- `bash -n` nos scripts alterados e nos testes.
- Teste host dos scripts (`mobile/tool/ci/test_verify_apk.sh` e `test_android_install_smoke.sh`), com `apksigner`/`aapt`/`adb` simulados num diretório temporário: aprovam o pacote completo e reprovam pacote com separadores trocados, activity de outro app, permissão ausente, ABI ausente, certificado que não é debug, app travado no splash e crash na abertura; sem `apksigner`, o `verify_apk.sh` avisa e não quebra. Rodam no `ci-mobile-check`.
- O YAML do workflow é válido.

## Limites do que foi comprovado

- O emulador é **x86_64**; `arm64-v8a` é conferido no pacote pelo `aapt`, não executado.
- A abertura é provada por **Monkey + foco/`dumpsys`**, não por interação real de tela.
- **Sem aparelho físico**: câmera, GPS e o fluxo completo de acesso não são exercitados aqui (DT-12).
- **Sem AAB**: só APK, que depende do keystore de release para a loja.
- **Assinatura debug**: instalável, não distribuível, e o certificado pode mudar entre execuções.

## Pendências fora do código

- Incluir `ci-mobile-build-android` e `ci-mobile-install-android` nos checks obrigatórios da `main` (configuração do repositório); sem isso, os jobs rodam mas não bloqueiam o merge.
- Keystore de release como secret e geração de AAB, antes da publicação.
