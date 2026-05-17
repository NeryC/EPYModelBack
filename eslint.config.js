import js from '@eslint/js';
import tseslint from '@typescript-eslint/eslint-plugin';
import tsparser from '@typescript-eslint/parser';
import prettier from 'eslint-config-prettier';

export default [
  js.configs.recommended,
  {
    files: ['src/**/*.{ts,js}', 'tests/**/*.{ts,js}'],
    languageOptions: {
      parser: tsparser,
      parserOptions: {
        sourceType: 'module',
        ecmaVersion: 2022,
        // Reference BOTH tsconfigs: the production one (src only) and the
        // test one (src + tests + *.test.ts / *.spec.ts). ESLint's TS parser
        // accepts an array and resolves each file against any matching project.
        project: ['./tsconfig.json', './tsconfig.test.json'],
      },
      globals: {
        console: 'readonly',
        process: 'readonly',
        Buffer: 'readonly',
      },
    },
    plugins: {
      '@typescript-eslint': tseslint,
    },
    rules: {
      ...tseslint.configs.recommended.rules,
      '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-floating-promises': 'error',
      'no-case-declarations': 'off',
    },
  },
  prettier,
  {
    ignores: ['dist/**', 'node_modules/**', 'coverage/**'],
  },
];
