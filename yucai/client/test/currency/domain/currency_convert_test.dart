import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';

void main() {
  group('toPreferredCents', () {
    test('same currency returns original cents', () {
      expect(
        toPreferredCents(1000, 'USD', {'USD': 1.08}, 'USD'),
        1000,
      );
    });

    test('cross-rate USD 1000 -> CNY = 7231', () {
      final rates = <String, double>{'USD': 1.08, 'CNY': 7.81};
      // (1000 * 7.81 / 1.08).round() = 7231
      expect(toPreferredCents(1000, 'USD', rates, 'CNY'), 7231);
    });

    test('missing fromCode rate returns original', () {
      final rates = <String, double>{'CNY': 7.81};
      expect(toPreferredCents(1000, 'USD', rates, 'CNY'), 1000);
    });

    test('rates[from] == 0 returns original (divide-by-zero fallback)', () {
      final rates = <String, double>{'USD': 0.0, 'CNY': 7.81};
      expect(toPreferredCents(1000, 'USD', rates, 'CNY'), 1000);
    });

    test('missing preferred rate returns original', () {
      final rates = <String, double>{'USD': 1.08};
      expect(toPreferredCents(1000, 'USD', rates, 'CNY'), 1000);
    });

    test('EUR -> USD cross-rate (EUR not in map is base)', () {
      // EUR base: rate 1.0 implied. USD 1.08. 1000 EUR-cents -> USD = 1080.
      final rates = <String, double>{'USD': 1.08};
      expect(toPreferredCents(1000, 'EUR', rates, 'USD'), 1080);
    });
  });

  group('currencySymbol', () {
    test('CNY -> ¥', () {
      expect(currencySymbol('CNY'), '¥');
    });
    test('USD -> \$', () {
      expect(currencySymbol('USD'), '\$');
    });
    test('EUR -> €', () {
      expect(currencySymbol('EUR'), '€');
    });
    test('GBP -> £', () {
      expect(currencySymbol('GBP'), '£');
    });
    test('JPY -> ¥', () {
      expect(currencySymbol('JPY'), '¥');
    });
    test('HKD -> HK\$', () {
      expect(currencySymbol('HKD'), 'HK\$');
    });
    test('SGD (unknown) -> "SGD"', () {
      expect(currencySymbol('SGD'), 'SGD');
    });
  });
}
