# Capturas do aplicativo

Coloque aqui as capturas do app Android, com o aparelho desbloqueado e o app logado. Sugestão de nomes e telas:

| Arquivo | Tela |
|---|---|
| `01-autorizacoes.png` | Minhas autorizações com uma autorização ativa |
| `02-detalhe.png` | Detalhe da autorização |
| `03-nfc.png` | Acesso por NFC com prova ativa |
| `04-scanner.png` | Scanner apontando para o QR do terminal |
| `05-liberado.png` | Resultado liberado |
| `06-negado.png` | Resultado negado (prova reutilizada ou QR vencido) |
| `07-perfil.png` | Perfil |

Captura via ADB, com o aparelho conectado e desbloqueado:

```powershell
adb exec-out screencap -p > 01-autorizacoes.png
```

As imagens entram no relatório e nos slides como evidência de interface; não substituem os eventos e ACKs do banco.
