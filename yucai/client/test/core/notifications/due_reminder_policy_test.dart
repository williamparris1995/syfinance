import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';

void main() {
  final today = DateTime(2026, 8, 29);

  group('tierFor 差值分类(spec FR-2 三档)', () {
    final cases = <String, (DateTime, DueTier?)>{
      '到期前 3 天 → t3': (DateTime(2026, 9, 1), DueTier.t3),
      '到期前 2 天 → 不提醒': (DateTime(2026, 8, 31), null),
      '到期前 1 天 → 不提醒': (DateTime(2026, 8, 30), null),
      '当天 → t0': (DateTime(2026, 8, 29), DueTier.t0),
      '逾期 1 天 → overdue': (DateTime(2026, 8, 28), DueTier.overdue),
      '逾期 5 天 → overdue': (DateTime(2026, 8, 24), DueTier.overdue),
      '远期 10 天 → 不提醒': (DateTime(2026, 9, 8), null),
      '远期 60 天 → 不提醒': (DateTime(2026, 10, 28), null),
    };
    for (final e in cases.entries) {
      test(e.key, () {
        expect(DueReminderPolicy.tierFor(today, e.value.$1), e.value.$2);
      });
    }
  });

  group('shouldSend 当日去重', () {
    test('未发过 → 发', () {
      expect(DueReminderPolicy.shouldSend(alreadySentToday: false), isTrue);
    });
    test('同日已发 → 不重发(t3/t0/overdue 同一日只一次)', () {
      expect(DueReminderPolicy.shouldSend(alreadySentToday: true), isFalse);
    });
  });

  group('文案(spec FR-5:名称+金额+相对天数)', () {
    test('t3', () {
      final n = DueReminderPolicy.compose(
        debtName: '房贷',
        totalCents: 123456,
        tier: DueTier.t3,
        today: today,
        paymentDate: DateTime(2026, 9, 1),
      );
      expect(n.title, '御财·房贷');
      expect(n.body, '3 天后到期,应还 ¥1,234.56');
    });
    test('t0', () {
      final n = DueReminderPolicy.compose(
        debtName: '信用卡',
        totalCents: 500000,
        tier: DueTier.t0,
        today: today,
        paymentDate: today,
      );
      expect(n.body, '今日到期,应还 ¥5,000.00');
    });
    test('overdue 含天数', () {
      final n = DueReminderPolicy.compose(
        debtName: '车贷',
        totalCents: 99005,
        tier: DueTier.overdue,
        today: today,
        paymentDate: DateTime(2026, 8, 24),
      );
      expect(n.body, '已逾期 5 天,应还 ¥990.05');
    });
  });
}
