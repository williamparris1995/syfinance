import { describe, it, expect } from 'vitest';
import { convertMoney, getMissingRates, formatCurrency, buildRateMap } from '../lib/currency';

describe('Currency Utilities', () => {
  describe('convertMoney', () => {
    const rates = new Map([
      ['CNY', 1.0],    // Base currency
      ['USD', 7.25],   // 1 USD = 7.25 CNY
      ['EUR', 8.00],   // 1 EUR = 8.00 CNY
    ]);

    it('should convert CNY to USD correctly', () => {
      const result = convertMoney(100, 'CNY', 'USD', rates);
      expect(result).toBeCloseTo(13.79, 2);
    });

    it('should convert USD to EUR correctly', () => {
      const result = convertMoney(100, 'USD', 'EUR', rates);
      expect(result).toBeCloseTo(90.63, 2);
    });

    it('should convert USD to CNY correctly', () => {
      const result = convertMoney(100, 'USD', 'CNY', rates);
      expect(result).toBe(725);
    });

    it('should return same amount for same currency', () => {
      const result = convertMoney(100, 'CNY', 'CNY', rates);
      expect(result).toBe(100);
    });

    it('should return null for missing source rate', () => {
      const result = convertMoney(100, 'JPY', 'CNY', rates);
      expect(result).toBeNull();
    });

    it('should return null for missing target rate', () => {
      const result = convertMoney(100, 'CNY', 'JPY', rates);
      expect(result).toBeNull();
    });

    it('should handle zero amount', () => {
      const result = convertMoney(0, 'USD', 'EUR', rates);
      expect(result).toBe(0);
    });

    it('should handle negative amount', () => {
      const result = convertMoney(-100, 'USD', 'EUR', rates);
      expect(result).toBeCloseTo(-90.63, 1);
    });
  });

  describe('getMissingRates', () => {
    const rates = new Map([
      ['CNY', 1.0],
      ['USD', 7.25],
    ]);

    it('should return empty array when all rates exist', () => {
      const missing = getMissingRates(['CNY', 'USD'], 'CNY', rates);
      expect(missing).toEqual([]);
    });

    it('should detect missing currency rate', () => {
      const missing = getMissingRates(['CNY', 'USD', 'EUR'], 'CNY', rates);
      expect(missing).toContain('EUR');
    });

    it('should not include target currency in missing list', () => {
      const missing = getMissingRates(['JPY'], 'JPY', rates);
      expect(missing).toEqual([]);
    });

    it('should handle empty currency list', () => {
      const missing = getMissingRates([], 'CNY', rates);
      expect(missing).toEqual([]);
    });
  });

  describe('formatCurrency', () => {
    it('should format CNY with symbol', () => {
      const formatted = formatCurrency(1234.56, 'CNY');
      expect(formatted).toBe('¥1,234.56');
    });

    it('should format USD with symbol', () => {
      const formatted = formatCurrency(1234.56, 'USD');
      expect(formatted).toBe('$1,234.56');
    });

    it('should format EUR with symbol', () => {
      const formatted = formatCurrency(1234.56, 'EUR');
      expect(formatted).toBe('€1,234.56');
    });

    it('should use code for unknown currency', () => {
      const formatted = formatCurrency(1234.56, 'XXX');
      expect(formatted).toBe('XXX1,234.56');
    });

    it('should handle zero amount', () => {
      const formatted = formatCurrency(0, 'USD');
      expect(formatted).toBe('$0.00');
    });
  });

  describe('buildRateMap', () => {
    it('should build rate map from currency DTOs', () => {
      const currencies = [
        { code: 'CNY', exchange_rate: '1.0' },
        { code: 'USD', exchange_rate: '7.25' },
        { code: 'EUR', exchange_rate: '8.00' },
      ];

      const rateMap = buildRateMap(currencies);
      
      expect(rateMap.get('CNY')).toBe(1.0);
      expect(rateMap.get('USD')).toBe(7.25);
      expect(rateMap.get('EUR')).toBe(8.0);
    });

    it('should skip invalid rates', () => {
      const currencies = [
        { code: 'CNY', exchange_rate: '1.0' },
        { code: 'INVALID', exchange_rate: 'not-a-number' },
      ];

      const rateMap = buildRateMap(currencies);
      
      expect(rateMap.has('CNY')).toBe(true);
      expect(rateMap.has('INVALID')).toBe(false);
    });
  });
});
