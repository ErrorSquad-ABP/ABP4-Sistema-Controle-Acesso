# US-29 — execução em aparelho físico

Complemento de [`us-29.md`](us-29.md), que registra os testes automatizados e a
validação contra o backend local. Aqui está o que foi executado **manualmente**
em aparelho, em 11/11/2026.

## Ambiente observado

- **Aparelho:** Motorola g86 5G, **Android 15**.
- **Build:** APK **debug** instalado no aparelho.
- **Rede:** `adb reverse` ligando o aparelho ao backend local; nenhuma
  credencial, UID ou token é registrada nesta evidência.

## O que foi executado

- **Login** com a conta de demonstração e restauração da sessão.
- **Autorizações:** lista "Minhas autorizações" e abertura do **detalhe** de uma
  autorização.
- **Scanner:** leitura de um **QR exibido no monitor**, com o pedido de acesso
  chegando ao backend.
- **Perfil:** conferência nos **dois temas** (claro e escuro).
- **Locais:** cadastro real de um local ("Portaria", raio de **100 m**) e
  conferência do registro no **PostgreSQL**.
- **Administração:** telas de **autorizações** (US-30) e de **usuários e
  histórico** (US-31).

## O que NÃO foi verificado

- **Abertura física:** servo/cancela não foram acionados; o QR foi lido de um
  monitor, não do display de um terminal ESP32.
- **Medições:** não há medição de precisão do GPS, de tempo de leitura, de
  latência do pedido ou de consumo do aparelho.
- **Cobertura de todos os estados:** a execução não percorreu todas as variações
  de erro, permissões negadas, QR vencido e queda de rede em aparelho.
- **Release:** o APK é debug, assinado com a chave de desenvolvimento; não há
  APK/AAB de release nem publicação em loja.
- **Automação:** a execução foi manual; não virou teste de CI nem script
  reproduzível. Android 15 foi o único sistema observado.

## Como reproduzir

```bash
# backend local no ar (ver docs/guides/como-rodar.md)
cd mobile
flutter run --dart-define=API_BASE_URL=http://localhost:3000
# ou instalar o APK debug e ligar a porta:
adb reverse tcp:3000 tcp:3000
```

Depois, entrar com a conta de demonstração e repetir o roteiro acima. Para o
cadastro de local, usar um usuário ADMIN. Não registrar UID, token ou
credencial nas capturas e nos logs.
