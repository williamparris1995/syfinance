import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/widgets/category_fields.dart';

void main() {
  group('currencySymbolOf', () {
    test('maps supported currency codes to symbols', () {
      expect(currencySymbolOf('CNY'), '¥');
      expect(currencySymbolOf('USD'), '\$');
      expect(currencySymbolOf('EUR'), '€');
      expect(currencySymbolOf('GBP'), '£');
      expect(currencySymbolOf('JPY'), '¥');
      expect(currencySymbolOf('HKD'), 'HK\$');
      expect(currencySymbolOf('AUD'), 'A\$');
      expect(currencySymbolOf('SGD'), 'S\$');
    });

    test('falls back to ¥ for unknown codes', () {
      expect(currencySymbolOf('UNKNOWN'), '¥');
      expect(currencySymbolOf(''), '¥');
    });
  });

  test('categoryFieldsWidget accepts currencySymbol param (drives AmountInput prefix)', () {
    // 签名级验证：currencySymbol 是命名可选参数（默认 ¥），各 category 都能渲染不抛异常。
    // AmountInput 前缀随 currencySymbol 变化由 FormPage setState → 重渲染驱动（集成层验证）。
    final bundle = CategoryFieldBundle();
    for (final c in AccountCategory.values) {
      final widgetsUsd = categoryFieldsWidget(c, bundle, currencySymbol: '\$');
      final widgetsDefault = categoryFieldsWidget(c, bundle);
      expect(widgetsUsd, isNotEmpty, reason: '$c 应有字段');
      expect(widgetsDefault, hasSameLengthAs(widgetsUsd), reason: '$c 字段数不应随符号变');
    }
    bundle.dispose();
  });
}

/// 匹配器：两个集合长度相同。
Matcher hasSameLengthAs(Object expected) =>
    predicate<List<Object>>((a) => a.length == (expected as List).length,
        'has same length as $expected');
