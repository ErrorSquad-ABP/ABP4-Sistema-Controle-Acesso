# Como rodar localmente

Guia para subir o ambiente de desenvolvimento na sua máquina. Todos os comandos são executados na raiz do repo.

## Pré-requisitos

- **Docker Desktop** (com Docker Compose) — infraestrutura local.
- **Node LTS** — backend.
- **Flutter SDK** — app móvel (alvo Android).
- **VS Code + extensão PlatformIO** — firmware ESP32.

## 1) Subir a infraestrutura de dev

Sobe o broker MQTT (Mosquitto, porta `1883`) e o PostgreSQL (porta `5432`):

```bash
docker compose -f infra/docker-compose.dev.yml up -d
```

Conferindo que subiu:

```bash
docker compose -f infra/docker-compose.dev.yml ps
docker compose -f infra/docker-compose.dev.yml logs mosquitto
docker compose -f infra/docker-compose.dev.yml exec postgres pg_isready -U abp4
```

Esperado: os dois serviços `running`, o Mosquitto registrando que escuta na porta 1883 e o `pg_isready` respondendo `accepting connections`. Os valores de conexão locais (usuário/senha/banco `abp4`) servem só para dev — em produção valem Neon + HiveMQ Cloud.

## 2) Backend, mobile e firmware

Ainda não há código executável: os esqueletos chegam na Sprint 1.

- Backend — card **US-03** (`backend/`), instalado e rodado com Node.
- Mobile — card **US-09** (`mobile/`), rodado com o Flutter SDK.
- Firmware — card **US-07** (`firmware/`), compilado pelo PlatformIO ou simulado no Wokwi.

Quando cada esqueleto entrar, o `README.md` da respectiva pasta e este guia são atualizados com os comandos reais.

## 3) Parar tudo

```bash
docker compose -f infra/docker-compose.dev.yml down
```

Use `down -v` só quando quiser descartar também os dados do Postgres — é destrutivo.
