import '@testing-library/jest-dom/vitest';
import { vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// Flat key-value lookup built from en.json at test startup
const translations: Record<string, string> = {};

function flattenKeys(obj: Record<string, unknown>, prefix = ''): void {
  for (const [key, value] of Object.entries(obj)) {
    const fullKey = prefix ? `${prefix}.${key}` : key;
    if (typeof value === 'string') {
      translations[fullKey] = value;
    } else if (typeof value === 'object' && value !== null) {
      flattenKeys(value as Record<string, unknown>, fullKey);
    }
  }
}

// Load English locale synchronously so the mock t() resolves keys to real text
try {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = dirname(__filename);
  const localePath = resolve(__dirname, 'src', 'i18n', 'locales', 'en.json');
  const en = JSON.parse(readFileSync(localePath, 'utf-8'));
  flattenKeys(en as Record<string, unknown>);
} catch {
  // If read fails, leave translations empty — t() falls back to returning the key
}

Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: (query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addEventListener: () => {},
    removeEventListener: () => {},
    addListener: () => {},
    removeListener: () => {},
    dispatchEvent: () => false,
  }),
});

vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, options?: Record<string, unknown>) => {
      const translated = translations[key];
      if (translated === undefined) return key;
      if (!options) return translated;
      return translated.replace(/\{\{(\w+)\}\}/g, (_: string, name: string) =>
        String(options[name] ?? options.count ?? `{{${name}}}`)
      );
    },
    i18n: {
      language: 'en',
      changeLanguage: () => Promise.resolve(),
    },
    ready: true,
  }),
  initReactI18next: { type: '3rdParty', init: () => {} },
  Trans: ({ children }: { children: React.ReactNode }) => children,
}));
