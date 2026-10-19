# design

Fonte viva: **[ABP-4DSM (Figma)](https://www.figma.com/design/nddGhlwJIi5rMzhvsK5Rkl)** — 4 páginas:
`01 · Design System` · `02 · Telas — Claro` · `03 · Telas — Escuro` · `04 · Handoff & Regras de Negócio`.

## Direção visual — "Monochrome Premium" (decidida em 15/10/2026)

Preto e branco, clean; **cor apenas como feedback de estado**. Temas **Claro e Escuro** (switch de aparência na tela de Perfil).

**Tokens** (Claro → Escuro):

| Papel | Claro | Escuro |
|---|---|---|
| Fundo | `#FAFAFA` | `#0A0A0A` |
| Superfície | `#FFFFFF` | `#161616` |
| Texto | `#0A0A0A` | `#FAFAFA` |
| Texto secundário | `#6E6E6E` | `#A3A3A3` |
| Hairline | `#E8E8E8` | `#262626` |

**Feedback** (igual nos dois temas): sucesso `#16A34A` (soft `#ECFDF3`) · erro `#DC2626` (soft `#FEF2F2`) · atenção `#D97706` (soft `#FFFBEB`).

**Uso do feedback**: como texto, sobre o fundo soft correspondente (`successSoft`, `errorSoft`, `warningSoft`), com texto escuro por cima. A cor sólida só como fundo, com texto branco. Nunca usar `success`/`error`/`warning` como texto direto no fundo escuro: o erro sobre `#161616` fica em ~3,7:1 e reprova AA.

**Forma**: tipografia **Figtree** (Google Fonts, licença OFL; no Flutter empacotada em `mobile/assets/fonts/figtree/`, sem download em runtime) (Display 32 · Título 24 · Cabeçalho 20 · Corpo 16 · Legenda 13 · Micro 11 maiúsculo) · raio 12 (controles) / 16 (cards) / pills (chips) · grid 8pt · botões primários preto↔branco · ícones de linha 1.5px · separação por hairlines (sem sombras pesadas).

O tema do Flutter (US-09) espelha estes tokens nos dois modos (ThemeData claro/escuro).

## Assets exportados (`design/figma/`)

| Pasta / arquivo | Conteúdo |
|---|---|
| `design-system/` | Fundamentos (claro e escuro) + catálogo de componentes |
| `telas-claro/` | Fluxo completo em 9 telas: Entrar → Minhas autorizações → Detalhe → Escanear QR → Acesso liberado/negado → estados |
| `telas-escuro/` | O mesmo fluxo no tema escuro + Perfil com seletor de tema |
| `handoff-regras-de-negocio.png` | Página de regras e handoffs (QR 10s, geofence 100m, perfis, NFC, fluxos) |

PNGs exportados do Figma em 16/10, já com a tipografia **Figtree** (a fonte viva continua sendo o arquivo no Figma).

> Histórico: `Page 1` (protótipo inicial) e a exploração azul anterior estão descartadas — mantidas apenas como referência.
