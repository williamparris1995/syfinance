import js from '@eslint/js';
import tseslint from '@typescript-eslint/eslint-plugin';
import tsparser from '@typescript-eslint/parser';
import i18next from 'eslint-plugin-i18next';
import reactRefresh from 'eslint-plugin-react-refresh';

export default [
  js.configs.recommended,
  {
    files: ['src/**/*.{ts,tsx}'],
    languageOptions: {
      parser: tsparser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
      },
    },
    plugins: {
      '@typescript-eslint': tseslint,
      'react-refresh': reactRefresh,
      'i18next': i18next,
    },
    rules: {
      ...tseslint.configs.recommended.rules,
      'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
      'i18next/no-literal-string': ['error', {
        markupOnly: false,
        ignoreAttribute: ['className', 'style', 'type', 'id', 'name', 'to', 'key', 'variant', 'size', 'side'],
      }],
    },
  },
  {
    ignores: ['dist/**', 'node_modules/**'],
  },
];
