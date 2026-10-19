import { buildContainer } from './main/composition-root.js';
import { loadEnv } from './main/config/env.js';
import { createApp } from './main/http/app.js';

/**
 * Entrada serverless (Vercel): a plataforma procura o app Express exportado por
 * `src/index.ts`. Local e Docker seguem usando `src/main/server.ts` (com `listen`).
 */
export default createApp(buildContainer(loadEnv()));
