# syntax=docker/dockerfile:1

# ---- deps: todas as dependencias (inclui dev, para o build) ----
FROM node:24-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# ---- build: gera o Prisma Client e compila TypeScript -> dist ----
FROM deps AS build
COPY tsconfig.json tsconfig.build.json ./
COPY prisma7.config.ts ./
COPY prisma ./prisma
COPY src ./src
RUN npm run db:generate && npm run build

# ---- runtime: so dist + dependencias de producao ----
FROM node:24-alpine AS runtime
ENV NODE_ENV=production \
    PORT=3000
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "dist/main/server.js"]
