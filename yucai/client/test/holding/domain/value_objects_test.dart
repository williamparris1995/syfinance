import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';

/// SecurityType / TradeType 枚举值与 NAME 验证。
///
/// 域枚举索引从 0 开始(stock=0 / buy=0),proto 则 UNSPECIFIED=0 / 业务值从 1 起
/// (off-by-one)。data 层 mapper 按符号 NAME 显式映射,绝不按 int 强转 ——
/// 此处的 `.name` 断言即为该 NAME 契约的护栏。
void main() {
  group('SecurityType', () {
    test('values 齐全(7 种,顺序对齐 proto 业务值减一)', () {
      expect(SecurityType.values.length, 7);
    });

    test('每个值的 .name 符合 mapper NAME 契约', () {
      expect(SecurityType.stock.name, 'stock');
      expect(SecurityType.fund.name, 'fund');
      expect(SecurityType.etf.name, 'etf');
      expect(SecurityType.bond.name, 'bond');
      expect(SecurityType.gold.name, 'gold');
      expect(SecurityType.option.name, 'option');
      expect(SecurityType.other.name, 'other');
    });

    test('index 从 0 连续递增(无 UNSPECIFIED 占位)', () {
      expect(SecurityType.stock.index, 0);
      expect(SecurityType.other.index, 6);
    });
  });

  group('TradeType', () {
    test('values 齐全(4 种)', () {
      expect(TradeType.values.length, 4);
    });

    test('每个值的 .name 符合 mapper NAME 契约', () {
      expect(TradeType.buy.name, 'buy');
      expect(TradeType.sell.name, 'sell');
      expect(TradeType.dividend.name, 'dividend');
      expect(TradeType.split.name, 'split');
    });

    test('index 从 0 连续递增(无 UNSPECIFIED 占位)', () {
      expect(TradeType.buy.index, 0);
      expect(TradeType.split.index, 3);
    });
  });
}
