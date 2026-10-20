import { fileURLToPath } from 'node:url';
import { stringify } from 'yaml';
import { buildOpenApiDocument } from '../src/main/http/contract/openapi.js';

/** Arquivo versionado do contrato, consumido pelo time mobile. */
export const OPENAPI_YAML_PATH = fileURLToPath(new URL('../../docs/api/openapi.yaml', import.meta.url));

const HEADER = `# GERADO por \`npm run openapi:generate\` (backend) — NAO edite a mao.
# Fonte: backend/src/main/http/contract/ (schemas Zod + operations.ts).
`;

export function renderOpenApiYaml(): string {
  return HEADER + stringify(buildOpenApiDocument(), { lineWidth: 0, aliasDuplicateObjects: false });
}
