# Como rodar localmente

Guia para subir o ambiente de desenvolvimento na sua máquina. Todos os comandos são executados na raiz do repo.

## Pré-requisitos

- **Docker Desktop** (com Docker Compose) — infraestrutura local.
- **Node LTS** — backend.
- **Flutter SDK** — app móvel (alvo Android).
- **VS Code + extensão PlatformIO** — firmware ESP32.

## 1) Subir a infraestrutura de dev

Sobe o broker MQTT (Mosquitto) e o PostgreSQL. No host, as portas publicadas são `1884` (Mosquitto) e `5436` (PostgreSQL) — portas alternativas para não conflitar com instalações locais que já usem `1883`/`5432` (ajuste no compose se precisar). Dentro dos containers as portas continuam padrão: `1883` e `5432`.

```bash
docker compose -f infra/docker-compose.dev.yml up -d
```

Conferindo que subiu:

```bash
docker compose -f infra/docker-compose.dev.yml ps
docker compose -f infra/docker-compose.dev.yml logs mosquitto
docker compose -f infra/docker-compose.dev.yml exec postgres pg_isready -U abp4
```

Esperado: os dois serviços `running`, o Mosquitto registrando que escuta na porta 1883 (interna do container) e o `pg_isready` respondendo `accepting connections`. Do host, acesse-os em `localhost:1884` (MQTT) e `localhost:5436` (PostgreSQL). Os valores de conexão locais (usuário/senha/banco `abp4`) servem só para dev — em produção valem Neon + HiveMQ Cloud.

## 2) Backend

```bash
cd backend
cp .env.example .env     # opcional: sem .env valem os defaults
npm ci
npm run dev
```

Conferindo: `curl -i http://localhost:3000/health` deve responder `200` com `{"status":"ok",...}`. Antes de abrir PR rode `npm run lint && npm run typecheck && npm test`. Detalhes (scripts, variáveis e Docker) em [`backend/README.md`](../../backend/README.md).

## 3) Mobile

```bash
cd mobile
flutter pub get
flutter run -d chrome    # sem Android SDK; com emulador/aparelho: flutter run
```

Conferindo: abre a tela inicial "Controle de acesso" em Figtree, no tema claro ou escuro conforme o sistema. Antes de abrir PR rode `flutter analyze && flutter test`. Detalhes (estrutura, tema e rotas) em [`mobile/README.md`](../../mobile/README.md).

## 4) Firmware

O esqueleto **US-07** compila para ESP32 com PlatformIO Core 6.1.18:

```bash
cd firmware
cp include/config.example.h include/config.h  # PowerShell: Copy-Item; apenas na primeira vez
pio run
```

No VS Code, selecione `firmware/wokwi/wokwi.toml` pela ação **Wokwi: Select Config File**
e execute **Wokwi: Start Simulator** (requer licença ativada pelo usuário).
O exemplo usa `Wokwi-GUEST` e `host.wokwi.internal:1884` para acessar o Mosquitto
do compose pelo gateway integrado da extensão. O gateway público do navegador
não alcança localhost. Não exponha o broker na internet.

O firmware conecta e se inscreve no tópico de comandos; os módulos físicos são
esqueletos sem atuação. Instalação, testes host, smoke test MQTT e limitações
em [`firmware/README.md`](../../firmware/README.md).

## 5) Parar tudo

```bash
docker compose -f infra/docker-compose.dev.yml down
```

Use `down -v` só quando quiser descartar também os dados do Postgres — é destrutivo.
