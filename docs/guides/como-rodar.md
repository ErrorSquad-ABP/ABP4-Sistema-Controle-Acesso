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
npm run db:generate      # Prisma Client em src/generated/prisma
npm run db:migrate:deploy  # cria as tabelas no Postgres do compose
npm run db:seed          # dados de demonstração (pode rodar de novo; só banco local)
npm run dev
```

Conferindo: `curl -i http://localhost:3000/health` deve responder `200` com `{"status":"ok","database":"ok",...}` (com o Postgres no ar). Sem `DATABASE_URL`, o mesmo endpoint responde `database: not_configured`. Antes de abrir PR rode `npm run lint && npm run typecheck && npm test`. Detalhes (scripts, variáveis e Docker) em [`backend/README.md`](../../backend/README.md).

### Seed demo × provisionamento real (DT-07)

- `npm run db:seed` grava contas de **demonstração** com senha pública (`admin@abp4.local`, `usuario@abp4.local`) e reativa essas contas a cada execução. Por isso recusa `NODE_ENV=production`/`VERCEL_ENV=production` e qualquer `DATABASE_URL` que não seja local (`localhost`, `127.0.0.1`, `::1`, `postgres`). A seed **não** roda em banco remoto, nem com variável de opt-in: para dados reais use `db:provision`. O guard também rejeita `?host=`/`?hostaddr=` na URL (o driver `pg` aceitaria sobrescrever o host). No Prisma 7, `migrate dev`/`migrate reset` **não** executam a seed automaticamente; rode `npm run db:seed` explicitamente. O guard protege a seed, não o reset destrutivo do banco.
- Para o **primeiro administrador real** (produção inclusive), informe as credenciais só na execução:

  ```bash
  ADMIN_EMAIL=admin@empresa.com.br ADMIN_PASSWORD='<senha com 12+ caracteres>' npm run db:provision
  ```

  Cria apenas esse usuário, com salt aleatório, e não altera nada se o e-mail já existir. Não aceita e-mail `@abp4.local`.

### Testando o MQTT (US-04)

Com a infraestrutura de pé, rode em dois terminais (contrato em [`contratos-mqtt.md`](../architecture/contratos-mqtt.md)):

```bash
cd backend
npm run mqtt:consumer     # terminal 1: assina os tópicos e fica escutando
npm run sim:terminal      # terminal 2: publica a leitura NFC e responde o comando
```

Esperado: o consumidor loga `tentativa de acesso recebida`, `comando enviado` e `ack correlacionado`; o simulador loga `leitura nfc publicada`, `porta aberta` e sai com código 0. Sem o consumidor, o simulador espera 10 s e sai com erro. Na S1 o consumidor libera qualquer UID (decisão provisória até as US-19/US-20).

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
