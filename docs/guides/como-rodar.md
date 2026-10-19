# Como rodar localmente

Guia para subir o ambiente de desenvolvimento na sua máquina. Todos os comandos são executados na raiz do repo.

## Pré-requisitos

- **Docker Desktop** (com Docker Compose) — infraestrutura local.
- **Node LTS** — backend.
- **Flutter SDK** — app móvel (alvo Android).
- **VS Code + extensão PlatformIO** — firmware ESP32.

## 1) Subir a infraestrutura de dev

Sobe o broker MQTT (Mosquitto) e o PostgreSQL. No host, as portas publicadas são `1884` (Mosquitto) e `5436` (PostgreSQL) — as portas padrão `1883`/`5432` já estão ocupadas por outros projetos nesta máquina. Dentro dos containers as portas continuam padrão: `1883` e `5432`.

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

Ainda não há código executável: o esqueleto chega pelo card **US-07** (`firmware/`), compilado pelo PlatformIO ou simulado no Wokwi. Quando entrar, o `README.md` da pasta e este guia são atualizados com os comandos reais.

## 5) Parar tudo

```bash
docker compose -f infra/docker-compose.dev.yml down
```

Use `down -v` só quando quiser descartar também os dados do Postgres — é destrutivo.
