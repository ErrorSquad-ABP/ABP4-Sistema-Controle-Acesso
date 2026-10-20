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
- Corpo: descreva o que mudou e informe **uma linha `Card: US-XX — <link do card>`** — o `trello-link.yml` usa só essa linha (título e branch não vinculam). Para outros cards citados, use `Dependências:`; o vínculo automático significa **story entregue**, não dependência.
- **1 review mínimo** antes do merge, com CI verde.
- PR pequeno e direto; se ficou grande, quebre em PRs menores.

## CI (GitHub Actions)

Cada stack tem seu workflow. **Em PR os três rodam sempre** (são os checks obrigatórios da `main`); em push na `main`, só quando a pasta dele muda (filtro `paths`):

| Workflow | Pasta | Job (check obrigatório) | Etapas |
|---|---|---|---|
| [`ci-backend.yml`](../../.github/workflows/ci-backend.yml) | `backend/` | `ci-backend-check` · `ci-backend-docker` | `npm ci` → lint (inclui regra de camadas) → typecheck → testes com cobertura → build → imagem Docker + smoke test do `/health` |
| [`ci-mobile.yml`](../../.github/workflows/ci-mobile.yml) | `mobile/` | `ci-mobile-check` | `flutter pub get` → `flutter analyze` → `flutter test` |
| [`ci-firmware.yml`](../../.github/workflows/ci-firmware.yml) | `firmware/` | `ci-firmware-build` | testes C++ host → `pio run` (com `config.h` copiado do `config.example.h`) |
| [`trello-link.yml`](../../.github/workflows/trello-link.yml) | — | — | anexa o PR ao card da linha `Card: US-XX` e comenta o status |

- O `ci-firmware-build` sempre exige os testes host e o build; ausência de `firmware/platformio.ini` ou do exemplo de configuração falha o check, sem skip.
- Os quatro checks acima são obrigatórios na `main`, além de 1 aprovação. Merge com check vermelho ou pendente não passa.
- Os badges no `README.md` raiz mostram o estado da `main`.
- Antes de abrir PR, rode localmente o mesmo que o CI roda: no backend, `npm run lint && npm run typecheck && npm test && npm run build`.
- Falhou? Abra a aba **Checks** do PR: cada etapa tem nome próprio, e o resumo do job do backend mostra a tabela de cobertura.

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

`US-XX` no card do Trello → nome da branch → linha `Card: US-XX` do PR. A partir do card se chega ao código e do código se chega ao card, sempre.

## Segredos

- **Nunca** commitar segredos: tokens, chaves, senhas, `.env`, conteúdo de `~/.secrets/` (inclusive o token do Trello).
- `.env` é ignorado pelo `.gitignore`; versionamos apenas `.env.example`, **mantido atualizado** a cada variável nova.
- CI/CD usam GitHub Secrets (as variáveis do Trello entram como secrets e `TRELLO_BOARD_ID` como variable).
