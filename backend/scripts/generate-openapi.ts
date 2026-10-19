import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, relative } from 'node:path';
import { OPENAPI_YAML_PATH, renderOpenApiYaml } from './openapi-yaml.js';

await mkdir(dirname(OPENAPI_YAML_PATH), { recursive: true });
await writeFile(OPENAPI_YAML_PATH, renderOpenApiYaml(), 'utf8');
process.stdout.write(`contrato gerado em ${relative(process.cwd(), OPENAPI_YAML_PATH)}\n`);
