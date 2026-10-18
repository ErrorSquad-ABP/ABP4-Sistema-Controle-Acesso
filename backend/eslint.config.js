// @ts-check
import js from '@eslint/js';
import globals from 'globals';
import tseslint from 'typescript-eslint';

/**
 * Regra de dependencia da clean architecture, verificada no lint:
 * domain <- application <- infrastructure <- main (main monta tudo).
 */
const layer = (forbidden, message) => ({
  'no-restricted-imports': [
    'error',
    { patterns: [{ group: forbidden, message }] },
  ],
});

export default tseslint.config(
  { ignores: ['dist/', 'coverage/', 'node_modules/'] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    languageOptions: { globals: globals.node },
    rules: {
      '@typescript-eslint/consistent-type-imports': 'error',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    },
  },
  {
    files: ['src/domain/**/*.ts'],
    rules: layer(
      ['**/application/**', '**/infrastructure/**', '**/main/**', 'express', 'zod'],
      'domain e puro: nao importa outras camadas nem libs de framework.',
    ),
  },
  {
    files: ['src/application/**/*.ts'],
    rules: layer(
      ['**/infrastructure/**', '**/main/**', 'express'],
      'application so conhece domain (via ports), nunca infraestrutura ou HTTP.',
    ),
  },
  {
    files: ['src/infrastructure/**/*.ts'],
    rules: layer(['**/main/**'], 'infrastructure implementa ports; quem monta e o main.'),
  },
  {
    files: ['src/shared/**/*.ts'],
    rules: layer(
      ['**/domain/**', '**/application/**', '**/infrastructure/**', '**/main/**'],
      'shared nao depende de nenhuma camada.',
    ),
  },
);
