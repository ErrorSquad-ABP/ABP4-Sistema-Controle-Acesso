set -e
npm ci --no-audit --no-fund
npm run db:generate
npm run db:migrate:deploy
npm run db:seed:run
exec npx tsx src/main/server.ts
