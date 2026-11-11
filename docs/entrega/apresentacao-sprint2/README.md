# Sprint 2 — apresentação

**12 slides · 16:9 · 10–15 minutos · ErrorSquad / FATEC Jacareí**

- [Versão HTML offline](apresentacao.html)
- [Fechamento e ressalvas da Sprint 2](../review-2.md)

O PDF, o PPTX e a prévia são **gerados localmente** e não ficam versionados (ver
`.gitignore` desta pasta). Rode o gerador para produzi-los:

```powershell
python docs/entrega/apresentacao-sprint2/gerar.py
```

- `ABP4DSM-Sprint2-Apresentacao.pdf` — 12 slides, 16:9, Figtree incorporada.
- `ABP4DSM-Sprint2-Apresentacao.pptx` — textos e formas editáveis, com notas de fala.
- `previa-geral.png` — contato com os 12 slides.

Referência do sistema: `main` em **`a0625d7`**, após os merges dos PRs #67 e #68.
O PDF incorpora a fonte Figtree. Para editar o PPTX sem substituição tipográfica,
instale a [Figtree empacotada no projeto](../../../mobile/assets/fonts/figtree/).
Textos, números e formas do PowerPoint são editáveis; capturas continuam sendo imagens.

## O que foi executado

As imagens de login, Home, scanner, acesso liberado e negado são **capturas de
tela do APK rodando em um Motorola g86 5G (Android 15)**, feitas com
`adb exec-out screencap`. Câmera e GPS são os do aparelho; API, worker, banco e
broker são reais, em execução local. Nada de mockup ou tela redesenhada.

| Parte | Ambiente e limite |
|---|---|
| App | APK de debug no aparelho (`adb reverse` para a API local); não é build release nem publicação em loja |
| Câmera | câmera traseira do celular lendo o QR exibido no monitor |
| Posição | GPS do aparelho: 6,8 m (liberado) e 1.207,9 m (negado) |
| API e worker | Processos reais separados, `ACCESS_MODE=real`; não foi usado decisor permissivo |
| Banco | PostgreSQL 17 isolado em Docker, com migrations e seed fictícia do projeto |
| MQTT | Mosquitto real local; observador registra mensagens sanitizadas |
| Terminal | `SimulatedTerminal` do projeto; `online` e ACKs sintéticos, sem ESP32 conectado nesta captura |
| ESP32 físico | Placa real contra o EMQX em 06/11 (TLS + RC522), servo desligado; sem nova gravação nesta sessão — [US-23](../evidencias/us-23-nfc-rc522.md) |
| Produção | API na Vercel (`a0625d7`, `database: ok`) e worker no Render `live` com `mqtt conectado` no EMQX — [US-37](../evidencias/us-37.md) |

O fluxo capturado comprova câmera e GPS reais do aparelho, decisão no backend e
persistência. **Não comprova movimento da cancela, autonomia energética nem
publicação em loja.** O ACK do simulador não é prova de abertura física. O NFC
apresentado no slide 8 usa código real do firmware e a bancada registrada, não
uma foto inventada.

## Roteiro de fala

As notas também estão no PPTX. A sequência abaixo dura cerca de **11min30s**;
sobram até 3min30s para perguntas na janela de 15 minutos. Para 10 minutos,
reduza explicações dos slides 2, 5, 8 e 10 e não faça uma segunda demo ao vivo.

| Slide | Tempo | Foco da fala |
|---|---|---|
| 1. O acesso ganhou um fluxo real | 0:40 | Da fundação da S1 à integração da S2; declarar a simulação nas entradas |
| 2. Do contrato à decisão | 0:50 | Login e regras deixaram de ser demonstração/stub |
| 3. App no aparelho | 1:00 | APK no celular: login na API, sessão restaurada ao reabrir |
| 4. Câmera e GPS reais | 1:20 | Scanner lendo o monitor; 6,8 m liberado e 1.207,9 m negado |
| 5. Backend | 1:00 | QR de 25 s, JWT, janela, usos e teto de 100 m; admin existe na API |
| 6. Banco | 1:00 | Consulta SQL real com decisões QR/NFC e motivos; QR fora do raio não abre |
| 7. MQTT | 1:00 | Comando e ACK compartilham `commandId`; QoS 1 não é prova de movimento |
| 8. ESP32 e NFC | 1:10 | RC522 integrado; uma tentativa por apresentação e feedback após decisão |
| 9. Consistência | 0:50 | Usos observados: **5 → 6 → 6** ao repetir o mesmo `requestId` |
| 10. Qualidade | 0:50 | 460 backend no CI, 215 Flutter locais e 31 E2E, sem somar suítes distintas |
| 11. Está no ar | 1:00 | App, API, banco, broker e worker rodando; bancada é o que falta, não integração |
| 12. Encerramento | 0:50 | Nomes completos da equipe, próxima validação física e perguntas |

## Origem das capturas e dos números

Capturas do aparelho em **2026-11-11, 16:08–16:13 (America/Sao_Paulo)**; as de
API, banco, MQTT e idempotência vêm da execução local de 12:32–12:43. Dados
fictícios; IDs identificam a execução, não fixtures universais.

| Arquivo | Origem |
|---|---|
| `capturas/app-android-*.png`, `app-android-scanner.jpg` | `adb exec-out screencap` do APK no Motorola g86 5G; apenas reduzidas de tamanho |
| `capturas/app-*.png` (sem `android`) | Screenshots Playwright do build web, mantidos como registro anterior |
| `capturas/api-openapi.png`, `api-qr.png` | Swagger real da API em `127.0.0.1:3012/docs`; recorte com zoom de leitura |
| `capturas/banco.png`, `banco-recorte.png` | Saída real de `psql`, apresentada como texto no navegador; recorte remove espaço vazio |
| `capturas/banco-consulta.txt` | Consulta executada e resultado do PostgreSQL; nenhum dado foi criado para preencher a imagem |
| `capturas/mqtt.png`, `mqtt-foco.png` | Observações reais do broker, formatadas para leitura; UID/token não são exibidos |
| `capturas/mqtt-observado.txt` | Projeção sanitizada das mensagens de comando/ACK |
| `capturas/execucao-local.json` | Decisões, eventos, comandos e trace sanitizados da execução local |
| `capturas/idempotencia.json` | Medição posterior: antes, primeiro POST e repetição do mesmo ID |
| `capturas/validacoes-ci.txt` | Trechos do log do [CI da main](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/runs/43046423082) |

Horários de colunas SQL sem fuso não foram usados no resumo dos eventos; a
captura identifica seu próprio instante UTC. A consulta visual não exibe horários.
Tokens, senhas, UID bruto, hashes de credenciais, cookies e configurações locais
não fazem parte do material. O token visível no Swagger é o **exemplo estático
inválido do contrato**, não uma credencial usada na execução.

O Trello foi consultado integralmente: 63 cards; 49 em listas concluídas
(27 US + 22 DT), US-23 em review, US-25 em andamento, 10 na S3 e 2 bloqueados.
Há 50 flags `complete`, mas uma pertence à US-23 ainda em review; não confundir
flag com posição no quadro. A documentação não moveu cards nem deu aceite físico.

## Reproduzir e regenerar

Para outra execução do sistema, siga os [guias locais](../../guides/como-rodar.md),
o [README mobile](../../../mobile/README.md) e o
[roteiro NFC](../../guides/testar-us-23-nfc.md). Use banco de demonstração
isolado; não rode a seed sobre dados que precisam ser preservados.

Os containers desta captura chamam-se `abp4-review2-pg` e `abp4-review2-mqtt`,
com portas de loopback `5448` e `1888`. Não substituem o ambiente de desenvolvimento
existente. São recursos temporários da captura, não serviços da apresentação.
**O PDF funciona offline**, sem depender deles.

O gerador reutiliza as capturas já salvas e a fonte local. Requer `python-pptx`,
Pillow e Playwright com Chromium; o verificador também requer PyMuPDF.
Essas ferramentas estão disponíveis no ambiente de autoria e não adicionam
dependências ao backend ou ao app.

```powershell
python docs/entrega/apresentacao-sprint2/gerar.py
python docs/entrega/apresentacao-sprint2/verificar.py
```

`gerar.py` produz PDF, PPTX, HTML e prévias individuais. `verificar.py` confere
12 páginas/slides, proporção 16:9, notas, limites das formas, overflow do HTML,
imagens carregadas e consistência/ausência de campos secretos nas evidências.
Uma conferência visual das 12 páginas continua necessária antes de apresentar.
