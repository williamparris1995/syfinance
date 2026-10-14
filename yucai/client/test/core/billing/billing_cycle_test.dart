// F60 账单周期计算矩阵测试(NFR-1:账单日 {1,12,20,28,30,31} × 月边界 ×
// 平/闰年 × 账单日当天 × 短月钳制;拍板 A:账单日当天归下期)。
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/billing/billing_cycle.dart';

void main() {
  group('FR-1 周期计算', () {
    test('账单日 20:月中日期归当期账单', () {
      final c = billingCycleOf(DateTime(2026, 10, 15), billingDay: 20);
      expect(c.start, DateTime(2026, 9, 20));
      expect(c.end, DateTime(2026, 10, 20));
    });

    test('账单日 20:账单日当天归下期(拍板 A)', () {
      final c = billingCycleOf(DateTime(2026, 10, 20), billingDay: 20);
      expect(c.start, DateTime(2026, 10, 20));
      expect(c.end, DateTime(2026, 11, 20));
    });

    test('账单日 20:账单日前一天归上期(边界紧邻)', () {
      final c = billingCycleOf(DateTime(2026, 10, 19), billingDay: 20);
      expect(c.start, DateTime(2026, 9, 20));
      expect(c.end, DateTime(2026, 10, 20));
    });

    test('账单日 12:月内常规', () {
      final c = billingCycleOf(DateTime(2026, 10, 12), billingDay: 12);
      expect(c.start, DateTime(2026, 10, 12));
      expect(c.end, DateTime(2026, 11, 12));
    });

    test('账单日 28:月末附近', () {
      final c = billingCycleOf(DateTime(2026, 10, 30), billingDay: 28);
      expect(c.start, DateTime(2026, 10, 28));
      expect(c.end, DateTime(2026, 11, 28));
    });

    test('跨年:12 月账单日后', () {
      final c = billingCycleOf(DateTime(2026, 12, 25), billingDay: 20);
      expect(c.start, DateTime(2026, 12, 20));
      expect(c.end, DateTime(2027, 1, 20));
    });

    test('跨年:1 月账单日前(起点在上一年)', () {
      final c = billingCycleOf(DateTime(2027, 1, 5), billingDay: 20);
      expect(c.start, DateTime(2026, 12, 20));
      expect(c.end, DateTime(2027, 1, 20));
    });
  });

  group('FR-1 短月钳制(30/31 号账单日)', () {
    test('31 号卡二月内:起点为 1/31,终点钳制 2/28(平年)', () {
      final c = billingCycleOf(DateTime(2026, 2, 10), billingDay: 31);
      expect(c.start, DateTime(2026, 1, 31));
      expect(c.end, DateTime(2026, 2, 28));
    });

    test('31 号卡二月钳制日当天(2/28)归下期', () {
      final c = billingCycleOf(DateTime(2026, 2, 28), billingDay: 31);
      expect(c.start, DateTime(2026, 2, 28));
      expect(c.end, DateTime(2026, 3, 31));
    });

    test('31 号卡一月当天', () {
      final c = billingCycleOf(DateTime(2026, 1, 31), billingDay: 31);
      expect(c.start, DateTime(2026, 1, 31));
      expect(c.end, DateTime(2026, 2, 28));
    });

    test('30 号卡二月(平年):终点钳制 2/28', () {
      final c = billingCycleOf(DateTime(2026, 2, 5), billingDay: 30);
      expect(c.start, DateTime(2026, 1, 30));
      expect(c.end, DateTime(2026, 2, 28));
    });

    test('30 号卡二月(闰年 2028):终点钳制 2/29', () {
      final c = billingCycleOf(DateTime(2028, 2, 5), billingDay: 30);
      expect(c.start, DateTime(2028, 1, 30));
      expect(c.end, DateTime(2028, 2, 29));
    });

    test('31 号卡闰年二月内:起点 1/31 终点 2/29', () {
      final c = billingCycleOf(DateTime(2028, 2, 10), billingDay: 31);
      expect(c.start, DateTime(2028, 1, 31));
      expect(c.end, DateTime(2028, 2, 29));
    });

    test('31 号卡四月(30 天月)钳制 4/30', () {
      final c = billingCycleOf(DateTime(2026, 4, 15), billingDay: 31);
      expect(c.start, DateTime(2026, 3, 31));
      expect(c.end, DateTime(2026, 4, 30));
    });
  });

  group('FR-2 回落与等价', () {
    test('无账单日:回落自然月', () {
      final c = billingCycleOf(DateTime(2026, 10, 15));
      expect(c.start, DateTime(2026, 10, 1));
      expect(c.end, DateTime(2026, 11, 1));
    });

    test('越界账单日(0/32):回落自然月', () {
      expect(billingCycleOf(DateTime(2026, 10, 15), billingDay: 0).start,
          DateTime(2026, 10, 1));
      expect(billingCycleOf(DateTime(2026, 10, 15), billingDay: 32).start,
          DateTime(2026, 10, 1));
    });

    test('账单日 1 号:与自然月逐日等价(兼容零迁移)', () {
      for (final d in [
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 28),
        DateTime(2026, 10, 15),
        DateTime(2028, 2, 29),
        DateTime(2026, 12, 31),
      ]) {
        final c = billingCycleOf(d, billingDay: 1);
        expect(c.start, DateTime(d.year, d.month, 1), reason: '$d start');
        expect(c.end, DateTime(d.year, d.month + 1, 1), reason: '$d end');
      }
    });

    test('时间分量归一:date-only 语义', () {
      final c = billingCycleOf(DateTime(2026, 10, 15, 23, 59, 59), billingDay: 20);
      expect(c.start, DateTime(2026, 9, 20));
    });
  });

    test('M-1 钉测:28 号卡闰年 2028-02-29(当天)', () {
      final c = billingCycleOf(DateTime(2028, 2, 29), billingDay: 28);
      expect(c.start, DateTime(2028, 2, 28));
      expect(c.end, DateTime(2028, 3, 28));
    });

    test('M-1 钉测:30 号卡账单日当天(10-30)', () {
      final c = billingCycleOf(DateTime(2026, 10, 30), billingDay: 30);
      expect(c.start, DateTime(2026, 10, 30));
      expect(c.end, DateTime(2026, 11, 30));
    });

    test('M-1 钉测:12 号卡月初日期(起点在上月)', () {
      final c = billingCycleOf(DateTime(2026, 10, 5), billingDay: 12);
      expect(c.start, DateTime(2026, 9, 12));
      expect(c.end, DateTime(2026, 10, 12));
    });

    test('M-2 contains 四边界(左闭右开)', () {
      final c = billingCycleOf(DateTime(2026, 10, 15), billingDay: 20);
      expect(c.contains(DateTime(2026, 9, 20)), isTrue, reason: 'start 含');
      expect(c.contains(DateTime(2026, 9, 19)), isFalse, reason: 'start 前一日不含');
      expect(c.contains(DateTime(2026, 10, 20)), isFalse, reason: 'end 不含');
      expect(c.contains(DateTime(2026, 10, 19)), isTrue, reason: 'end-1 含');
    });

    test('M-2 Set 语义(hashCode)', () {
      final set = <BillingCycle>{
        billingCycleOf(DateTime(2026, 10, 15), billingDay: 20),
        billingCycleOf(DateTime(2026, 10, 1), billingDay: 20),
      };
      expect(set.length, 1);
    });

  group('值对象语义', () {
    test('==/hashCode 按区间', () {
      expect(billingCycleOf(DateTime(2026, 10, 15), billingDay: 20),
          billingCycleOf(DateTime(2026, 10, 1), billingDay: 20));
    });
  });
}
