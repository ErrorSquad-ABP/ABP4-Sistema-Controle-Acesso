# Mídias do projeto

Pasta de apoio ao relatório ABNT (US-36) e à apresentação da Sprint 3. Cada arquivo tem origem e legenda sugerida para uso direto em figuras.

## Diagramas

| Arquivo | Conteúdo | Fonte | Legenda sugerida |
|---|---|---|---|
| `diagramas/componentes.png` | Componentes do sistema e responsabilidades | `docs/architecture/componentes-implantacao.md` | Figura — Componentes da solução |
| `diagramas/implantacao.png` | Implantação em desenvolvimento e produção | idem | Figura — Implantação em desenvolvimento e produção |
| `diagramas/casos-de-uso.png` | Atores e casos de uso | `docs/architecture/casos-de-uso.md` | Figura — Casos de uso |
| `diagramas/sequencia-qr-rotacao.png` | Rotação do QR no terminal | `docs/architecture/sequencias.md` | Figura — Rotação do QR |
| `diagramas/sequencia-qr-acesso.png` | Acesso por QR, do app ao ACK | idem | Figura — Acesso por QR |
| `diagramas/sequencia-nfc.png` | Acesso por NFC (tag e HCE) | idem | Figura — Acesso por NFC |
| `diagramas/modelo-dados.png` | Modelo de dados | `docs/architecture/modelo-dados.md` | Figura — Modelo de dados |

Os PNGs foram renderizados a partir dos blocos Mermaid versionados. Para regerar, edite o Markdown de origem e repita a renderização.

## Demo web

| Arquivo | Conteúdo | Origem |
|---|---|---|
| `web/entrar-desktop-claro.png` | Tela de entrada, tema claro, 1280×800 | Captura de `https://abp4-demo-web.vercel.app` em 24/11/2026 |
| `web/entrar-desktop-escuro.png` | Tela de entrada, tema escuro, 1280×800 | idem |
| `web/entrar-mobile-claro.png` | Tela de entrada, tema claro, 390×844 | idem |
| `web/entrar-mobile-escuro.png` | Tela de entrada, tema escuro, 390×844 | idem |

As capturas mostram o aviso de limitações do navegador (NFC apenas no terminal Android; câmera e localização exigem HTTPS e permissão).

## App Android (a capturar)

O aparelho usado na bancada é o Motorola g86 5G. Capturas pendentes, com o app logado:

1. Minhas autorizações (lista com uma autorização ativa).
2. Detalhe da autorização.
3. Acesso por NFC com a prova ativa.
4. Scanner apontando para o QR do terminal.
5. Resultado liberado.
6. Resultado negado (prova reutilizada ou QR vencido).
7. Perfil e, se necessário para a banca, telas de administração.

Sugestão de captura: `adb exec-out screencap -p > app-<tela>.png`, com o aparelho desbloqueado e o app em primeiro plano. Guardar em `app/`.

## Terminal ESP32 (a fotografar)

Fotos pendentes, com o conjunto montado:

1. Terminal completo (ESP32, OLED, LCD, RC522, servo, LEDs e buzzer).
2. Close do OLED exibindo o QR e do LCD com o status.
3. Celular encostado no RC522 durante uma leitura HCE.
4. Tag física no leitor.
5. Servo em repouso e em abertura.
6. Bancada ligada, com o terminal em operação.

Guardar em `terminal/`. Evitar enquadrar senhas, redes Wi-Fi ou etiquetas com credenciais. As fotos entram no relatório como evidência de montagem; a decisão de acesso continua comprovada pelos eventos e ACKs no banco.

## Uso no relatório

As figuras do relatório referenciam `../midias/...` a partir de `docs/entrega/relatorio/`. Ao substituir uma captura, manter o mesmo nome de arquivo para não quebrar as referências.
