import express from 'express';
import { buildContainer } from './main/composition-root.js';
import { loadEnv } from './main/config/env.js';
import { configureApp } from './main/http/app.js';

/**
 * Entrada serverless (Vercel): a plataforma procura um app Express exportado por
 * `src/index.ts` e exige que o arquivo importe `express`. Local e Docker seguem
 * usando `src/main/server.ts` (com `listen`).
 */
const app = configureApp(express(), buildContainer(loadEnv()));

export default app;
