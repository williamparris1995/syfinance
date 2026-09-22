import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';

void main() {
  final today = DateTime(2026, 8, 29);

  group('tierFor 差值分类(催办模式:窗口内持续提醒)', () {
    // 默认配置 advanceDays=3。
    final policy = DueReminderPolicy();
    final cases = <String, (DateTime, DueTier?)>{
      '到期前 3 天(窗口边界)→ advance': (DateTime(2026, 9, 1), DueTier.advance),
      '到期前 2 天 → advance(催办:窗口内每天都提醒)':
          (DateTime(2026, 8, 31), DueTier.advance),
      '到期前 1 天 → advance': (DateTime(2026, 8, 30), DueTier.advance),
      '当天 → advance': (DateTime(2026, 8, 29), DueTier.advance),
      '逾期 1 天 → overdue': (DateTime(2026, 8, 28), DueTier.overdue),
      '逾期 5 天 → overdue': (DateTime(2026, 8, 24), DueTier.overdue),
      '远期 4 天(窗口外)→ 不提醒': (DateTime(2026, 9, 2), null),
      '远期 60 天 → 不提醒': (DateTime(2026, 10, 28), null),
    };
    for (final e in cases.entries) {
      test(e.key, () {
        expect(policy.tierFor(today, e.value.$1), e.value.$2);
      });
    }
  });

  group('advanceDays 可配置(设置页改动即时生效)', () {
    test('advanceDays=7:窗口扩大,前 7 天内都 advance', () {
      final policy = DueReminderPolicy(const DueReminderConfig(advanceDays: 7));
      expect(policy.tierFor(today, DateTime(2026, 9, 5)), DueTier.advance);
      expect(policy.tierFor(today, DateTime(2026, 9, 6)), isNull); // 第 8 天
    });
    test('advanceDays=1:只提前一天', () {
      final policy = DueReminderPolicy(const DueReminderConfig(advanceDays: 1));
      expect(policy.tierFor(today, DateTime(2026, 8, 30)), DueTier.advance);
      expect(policy.tierFor(today, DateTime(2026, 8, 31)), isNull); // 第 2 天
    });
  });

  group('shouldSend 桶内去重', () {
    test('本桶未发 → 发', () {
      expect(DueReminderPolicy.shouldSend(alreadySentInBucket: false), isTrue);
    });
    test('本桶已发 → 不重发(桶宽 = repeatHours)', () {
      expect(DueReminderPolicy.shouldSend(alreadySentInBucket: true), isFalse);
    });
  });

  group('bucketToken 重复间隔(每次提醒最长间隔 6 小时)', () {
    test('同桶:间隔小于 repeatHours 的两次扫描同 token', () {
      final policy = DueReminderPolicy(const DueReminderConfig(repeatHours: 6));
      final a = DateTime(2026, 8, 29, 10, 0);
      final b = DateTime(2026, 8, 29, 13, 59); // +3h59m < 6h
      expect(policy.bucketToken(a), policy.bucketToken(b));
    });
    test('跨桶:间隔达到 2×repeatHours 必不同桶', () {
      final policy = DueReminderPolicy(const DueReminderConfig(repeatHours: 6));
      final a = DateTime(2026, 8, 29, 0, 30);
      final b = DateTime(2026, 8, 29, 13, 0); // +12.5h > 2 桶宽
      expect(policy.bucketToken(a) != policy.bucketToken(b), isTrue);
    });
    test('repeatHours=1:小时粒度桶', () {
      final policy = DueReminderPolicy(const DueReminderConfig(repeatHours: 1));
      final a = DateTime(2026, 8, 29, 10, 30);
      final b = DateTime(2026, 8, 29, 11, 0);
      expect(policy.bucketToken(a) != policy.bucketToken(b), isTrue);
    });
  });

  group('文案(名称+金额+相对天数)', () {
    test('advance 多天', () {
      final policy = DueReminderPolicy();
      final n = policy.compose(
        debtName: '房贷',
        totalCents: 123456,
        tier: DueTier.advance,
        today: today,
        paymentDate: DateTime(2026, 9, 1),
      );
      expect(n.title, '御财·房贷');
      expect(n.body, '3 天后到期,应还 ¥1,234.56');
    });
    test('advance 当天', () {
      final policy = DueReminderPolicy();
      final n = policy.compose(
        debtName: '信用卡',
        totalCents: 500000,
        tier: DueTier.advance,
        today: today,
        paymentDate: today,
      );
      expect(n.body, '今日到期,应还 ¥5,000.00');
    });
    test('overdue 含天数', () {
      final policy = DueReminderPolicy();
      final n = policy.compose(
        debtName: '车贷',
        totalCents: 99005,
        tier: DueTier.overdue,
        today: today,
        paymentDate: DateTime(2026, 8, 24),
      );
      expect(n.body, '已逾期 5 天,应还 ¥990.05');
    });
  });

  /// 档位序数契约守卫(镜像 review R1):ReminderLogs 持久化 DueTier.index,
  /// 枚举重排会静默错读历史记录 —— 此处钉死顺序。旧版 t3/t0 行的
  /// sentDate 是 yyyy-MM-dd 日粒度,与桶 token 数字串不共键,不受影响。
  test('DueTier 枚举顺序契约(advance=0/overdue=1,持久化依赖)', () {
    expect(DueTier.values.map((t) => t.index).toList(), [0, 1]);
    expect(DueTier.values.toList(), [DueTier.advance, DueTier.overdue]);
  });
}
