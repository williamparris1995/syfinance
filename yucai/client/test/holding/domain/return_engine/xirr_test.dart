import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/holding/domain/return_engine/xirr.dart';

DateTime d(String s) => DateTime.parse('${s}T00:00:00Z');

void main() {
  // 闭式根独立公式(与引擎的 pow 路径不同源):r = (−A2/A1)^(365/days) − 1。
  final twoFlowClosedForm = (double a1, double a2, double days) =>
      math.exp(math.log(-a2 / a1) * 365.0 / days) - 1;

  test('Excel 文档例 37.34%(G oracle)', () {
    final r = xirr([
      CashFlow(d('2008-01-01'), -10000),
      CashFlow(d('2008-03-01'), 2750),
      CashFlow(d('2008-10-30'), 4250),
      CashFlow(d('2009-02-15'), 3250),
      CashFlow(d('2009-04-01'), 2750),
    ]);
    expect(r, isNotNull);
    expect((r! - 0.373362535).abs(), lessThan(1e-6));
  });

  test('1e8 大额收敛(G oracle,F3)', () {
    final r = xirr([CashFlow(d('2024-01-01'), -1e8), CashFlow(d('2024-12-31'), 1.1e8)]);
    expect(r, isNotNull);
    expect((r! - 0.10).abs(), lessThan(1e-4));
  });

  test('1 天 +10% 极端解(G oracle,F4,闭式 ≈1.28e15)', () {
    final r = xirr([CashFlow(d('2024-01-01'), -100), CashFlow(d('2024-01-02'), 110)]);
    expect(r, isNotNull);
    final want = twoFlowClosedForm(-100, 110, 1);
    expect((r! - want).abs() / want, lessThan(1e-9));
  });

  test('包络外拒绝(1 天翻倍 2^365 > 1e16)', () {
    expect(xirr([CashFlow(d('2024-01-01'), -100), CashFlow(d('2024-01-02'), 200)]), isNull);
  });

  test('陡梯度深亏(G review R2 oracle:-0.9697111967122702)', () {
    final r = xirr([
      CashFlow(d('2010-01-01'), -1e6),
      CashFlow(d('2015-01-01'), -1e6),
      CashFlow(d('2020-01-01'), -1e6),
      CashFlow(d('2021-01-01'), 3e4),
    ]);
    expect(r, isNotNull);
    expect((r! - (-0.9697111967122702)).abs(), lessThan(1e-9));
  });

  test('归一化 scale 不变(×1e9 同根)', () {
    final base = [
      CashFlow(d('2023-01-01'), -200000000),
      CashFlow(d('2023-07-01'), -300000000),
      CashFlow(d('2024-01-01'), 610000000),
    ];
    final scaled = [for (final c in base) CashFlow(c.date, c.amount * 1e9)];
    final a = xirr(base)!;
    final b = xirr(scaled)!;
    expect((a - b).abs(), lessThan(1e-6));
  });

  test('insufficient / 全同号 → null(G oracle)', () {
    expect(xirr([CashFlow(d('2020-01-01'), -100)]), isNull);
    expect(xirr([CashFlow(d('2020-01-01'), -100), CashFlow(d('2020-06-01'), -50)]), isNull);
  });

  test('NaN graceful(>54 年混号尾流):null 或有限值,绝不 NaN/Inf', () {
    final r = xirr([
      CashFlow(d('1970-01-01'), -100),
      CashFlow(d('2025-01-01'), 500),
      CashFlow(d('2026-01-01'), -3),
    ]);
    expect(r == null || r.isFinite, isTrue);
  });
}
