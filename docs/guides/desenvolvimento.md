# Guia de desenvolvimento

Guia interno do ErrorSquad para o projeto ABP4. Vale para todo mundo que mexe no repo — inclusive para quem chega agora.

## Branches

- `feat/us-XX-slug` para uma user story (ex.: `feat/us-03-esqueleto-backend`).
- `fix/slug` para correção, `docs/slug` para documentação.
- Curta, sempre a partir da `main` atualizada, e **um card por branch**.

## Commits

- Convencionais em pt-BR **sem acento**: `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`.
- Cite a story quando o commit for dela: `feat: rota de autorizacoes (US-06)`.
- Commits pequenos e temáticos; nada de misturar backend com docs no mesmo commit.

## PRs

- Título: `tipo: US-XX descricao` (ex.: `feat: US-03 esqueleto do backend`).
- Corpo: descreva o que mudou e **cole o link do card do Trello** — o workflow `trello-link.yml` encontra o `US-XX` no título/corpo/branch e anexa o PR ao card automaticamente.
- **1 review mínimo** antes do merge, com CI verde.
- PR pequeno e direto; se ficou grande, quebre em PRs menores.

## CI (GitHub Actions)

Cada stack tem seu workflow, disparado em PR e em push na `main` **só quando a pasta dela muda** (filtro `paths`; o próprio YAML também dispara):

| Workflow | Pasta | Etapas |
|---|---|---|
| [`ci-backend.yml`](../../.github/workflows/ci-backend.yml) | `backend/` | `npm ci` → lint (inclui regra de camadas) → typecheck → testes com cobertura → build → build da imagem Docker + smoke test do `/health` |
| [`ci-mobile.yml`](../../.github/workflows/ci-mobile.yml) | `mobile/` | `flutter pub get` → `flutter analyze` → `flutter test` |
| [`ci-firmware.yml`](../../.github/workflows/ci-firmware.yml) | `firmware/` | `pio run` (com `config.h` copiado do `config.example.h`) |
| [`trello-link.yml`](../../.github/workflows/trello-link.yml) | — | anexa o PR ao card `US-XX` e comenta o status |

- Enquanto `mobile/pubspec.yaml` (US-09) ou `firmware/platformio.ini` (US-07) não existirem, o respectivo job **passa com um aviso** em vez de falhar; quando o esqueleto entrar, o CI passa a valer sem mudar nada.
- Antes de abrir PR, rode localmente o mesmo que o CI roda: no backend, `npm run lint && npm run typecheck && npm test && npm run build`.
- Falhou? Abra a aba **Checks** do PR: cada etapa tem nome próprio, e o resumo do job do backend mostra a tabela de cobertura.
- Os badges no `README.md` raiz mostram o estado da `main`.

## Ação de review

Quem revisa olha o PR contra o Definition of Done em [`../scrum/definition-of-done.md`](../scrum/definition-of-done.md):

- Critérios de aceite do card realmente atendidos (não só "o código roda").
- CI verde (lint, typecheck, testes, build da pasta afetada).
- Teste mínimo do que mudou.
- Documentação afetada atualizada (`README` da pasta, `docs/architecture/`, `docs/api/`).
- Nada de segredo no diff, `.env.example` atualizado quando entram variáveis novas.
- Dá para demonstrar na review.

Review não é carimbo: aponte o problema com o caminho do arquivo e o que você esperava ver.

## Rastreio

`US-XX` no card do Trello → nome da branch → título/corpo do PR. A partir do card se chega ao código e do código se chega ao card, sempre.

## Segredos

- **Nunca** commitar segredos: tokens, chaves, senhas, `.env`, conteúdo de `~/.secrets/` (inclusive o token do Trello).
- `.env` é ignorado pelo `.gitignore`; versionamos apenas `.env.example`, **mantido atualizado** a cada variável nova.
- CI/CD usam GitHub Secrets (as variáveis do Trello entram como secrets e `TRELLO_BOARD_ID` como variable).
