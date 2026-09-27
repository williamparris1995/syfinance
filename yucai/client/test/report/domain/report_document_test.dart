import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/report_document.dart';

/// T1 report domain:ReportPeriod 边界/label、VO 构造期派生字段
/// (savingsRate/pct/estGain)——期望值全部手算(G oracle),不复用被测代码。
void main() {
  group('ReportPeriod', () {
    test('月期边界:2026-08 → [08-01 00:00:00, 08-31 23:59:59]', () {
      final p = ReportPeriod.monthly(2026, 8);
      expect(p.start, DateTime(2026, 8, 1));
      expect(p.endInclusive, DateTime(2026, 8, 31, 23, 59, 59));
    });

    test('月期边界:闰年 2024-02 → 02-29 23:59:59;平年 2026-02 → 02-28', () {
      expect(ReportPeriod.monthly(2024, 2).endInclusive,
          DateTime(2024, 2, 29, 23, 59, 59));
      expect(ReportPeriod.monthly(2026, 2).endInclusive,
          DateTime(2026, 2, 28, 23, 59, 59));
    });

    test('年期边界:2025 → [01-01 00:00:00, 12-31 23:59:59]', () {
      final p = ReportPeriod.yearly(2025);
      expect(p.start, DateTime(2025, 1, 1));
      expect(p.endInclusive, DateTime(2025, 12, 31, 23, 59, 59));
    });

    test('label:月「2026 年 8 月」/ 年「2025 年度」', () {
      expect(ReportPeriod.monthly(2026, 8).label, '2026 年 8 月');
      expect(ReportPeriod.yearly(2025).label, '2025 年度');
    });

    test('相等性:同年月即同期(与实例无关)', () {
      expect(ReportPeriod.monthly(2026, 8), ReportPeriod.monthly(2026, 8));
      expect(ReportPeriod.yearly(2025).hashCode, ReportPeriod.yearly(2025).hashCode);
    });
  });

  group('OverviewSection 储蓄率(结余/收入,构造时算,1 位小数)', () {
    test('收入 10000.00 支出 7500.00 → 结余 2500.00、储蓄率 25.0', () {
      final o = OverviewSection.create(
        netWorthStartCents: 0,
        netWorthEndCents: 0,
        incomeCents: 1000000,
        expenseCents: 750000,
        cashDeltaCents: 0,
        notes: const [],
      );
      expect(o.surplusCents, 250000);
      expect(o.savingsRate, 25.0);
    });

    test('收入 0 → 储蓄率 0(不除零),结余为负照实', () {
      final o = OverviewSection.create(
        netWorthStartCents: 0,
        netWorthEndCents: 0,
        incomeCents: 0,
        expenseCents: 10000,
        cashDeltaCents: 0,
        notes: const [],
      );
      expect(o.surplusCents, -10000);
      expect(o.savingsRate, 0.0);
    });

    test('非整 pct 四舍五入 1 位:3.00/3.00 → 66.7', () {
      final o = OverviewSection.create(
        netWorthStartCents: 0,
        netWorthEndCents: 0,
        incomeCents: 300,
        expenseCents: 100,
        cashDeltaCents: 0,
        notes: const [],
      );
      expect(o.savingsRate, 66.7);
    });
  });

  group('CategoryAmount pct(构造时算,1 位小数)', () {
    test('1000/3000 → 33.3', () {
      final c =
          CategoryAmount.create(category: 'food', amountCents: 1000, totalCents: 3000);
      expect(c.pct, 33.3);
    });

    test('总额 0 → pct 0(空构成不除零)', () {
      final c =
          CategoryAmount.create(category: 'food', amountCents: 0, totalCents: 0);
      expect(c.pct, 0.0);
    });
  });

  group('InvestmentSection 估算收益(FR-6 口径:期末−期初−净买入)', () {
    test('期初 10000 期末 12000 净买入 5000 → 估算收益 −3000', () {
      final s = InvestmentSection.create(
        mvStartCents: 1000000,
        mvEndCents: 1200000,
        netBuyCents: 500000,
        twr: null,
      );
      expect(s.estGainCents, -300000);
    });
  });
}
