// 同源契约测试(2026-09 到期常显提醒,design ADR-1 / 风险 R1):
// 写侧 scanner 与读侧 DueCandidateProvider 的候选口径(什么算一条待办)
// 必须由同一共享层定义 —— 本文件钉死:同一 fixture(假源 + 假挂失集)
// 分别走 scanner 管线与 provider 管线,断言候选集一致;另覆盖共享纯函数
// filterActiveCandidates 的单元口径(窗口分档 + 挂失过滤 + daysLeft 符号)。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/notifications/due_candidate_provider.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/due_target.dart';
import 'package:yucai_client/core/notifications/reminder_dismissal_store.dart';

/// 内存 fake:候选源(照 due_scanner_test.FakeDueSource)。
class FakeDueSource implements DueScheduleSource {
  FakeDueSource(this.entries);
  final List<DueScheduleEntry> entries;
  @override
  Future<List<DueScheduleEntry>> unpaidDueCandidates() async => entries;
}

/// 内存 fake:通知发送器(记录全部发送 —— scanner 路径的候选观测面)。
class FakeNotifier implements ReminderNotifier {
  final sent = <DueNotificationCopy>[];
  @override
  Future<void> show(DueNotificationCopy copy) async => sent.add(copy);
}

/// 内存 fake:桶粒度已发记录(恒空 → scanner 发送集 = 活跃候选集)。
class FakeLogStore implements ReminderLogStore {
  final Set<String> sentKeys = {};
  @override
  Future<bool> wasSent(String entryId, DueTier tier, String bucketToken) async =>
      false;
  @override
  Future<void> markSent(String entryId, DueTier tier, String bucketToken) async {}
}

void main() {
  final today = DateTime(2026, 9, 23);

  /// 契约 fixture:窗口内外 / 逾期 / 已挂失 / 可被更大 advanceDays 拉入
  /// 的远期条目各占其位(名称唯一 —— scanner 路径经通知文案反查身份)。
  List<DueScheduleEntry> fixture() => [
        DueScheduleEntry(
            id: 'e1',
            debtName: '房贷',
            totalCents: 100000,
            paymentDate: DateTime(2026, 9, 26),
            target: const DebtTarget('d1')), // advance 3 天(边界)
        DueScheduleEntry(
            id: 'e2',
            debtName: '车贷',
            totalCents: 300000,
            paymentDate: DateTime(2026, 9, 19),
            target: const DebtTarget('d2')), // overdue 4 天
        DueScheduleEntry(
            id: 'e3',
            debtName: '信用卡',
            totalCents: 200000,
            paymentDate: DateTime(2026, 9, 25),
            target: const AccountTarget('a1')), // advance 2 天,将挂失
        DueScheduleEntry(
            id: 'e4',
            debtName: '远期',
            totalCents: 400000,
            paymentDate: DateTime(2026, 10, 20),
            target: const DebtTarget('d4')), // 默认窗口外
        DueScheduleEntry(
            id: 'e5',
            debtName: '当天',
            totalCents: 500000,
            paymentDate: today,
            target: const DebtTarget('d5')), // advance 0 天
        DueScheduleEntry(
            id: 'e6',
            debtName: '差5天',
            totalCents: 600000,
            paymentDate: DateTime(2026, 9, 28),
            target: const DebtTarget('d6')), // advanceDays≥5 才入窗
      ];

  /// 内存 drift 挂失存储(两管线共用同一实例 = 同一挂失真相)。
  Future<ReminderDismissalStore> driftDismissalStore(List<String> ids) async {
    final store = ReminderDismissalStore(db.AppDatabase(NativeDatabase.memory()));
    for (final id in ids) {
      await store.dismiss(id);
    }
    return store;
  }

  group('filterActiveCandidates 共享口径(单元)', () {
    test('窗口分档 + 挂失过滤:留 e1/e2/e5;e4 窗口外、e3 挂失被剔', () {
      final active = filterActiveCandidates(
        fixture(),
        const {'e3'},
        policy: DueReminderPolicy(),
        today: today,
      );
      expect(active.map((c) => c.entry.id), ['e1', 'e2', 'e5']);
    });

    test('tier/daysLeft 映射(与 policy.tierFor 同口径;负 = 逾期天数)', () {
      final active = filterActiveCandidates(
        fixture(),
        const {'e3'},
        policy: DueReminderPolicy(),
        today: today,
      );
      final byId = {for (final c in active) c.entry.id: c};
      expect(byId['e1']!.tier, DueTier.advance);
      expect(byId['e1']!.daysLeft, 3);
      expect(byId['e2']!.tier, DueTier.overdue);
      expect(byId['e2']!.daysLeft, -4); // 逾期 4 天
      expect(byId['e5']!.daysLeft, 0); // 当天
      // target 原样透传(强类型路由目标,ADR-2)。
      expect(byId['e1']!.entry.target, isA<DebtTarget>());
      expect(byId['e5']!.entry.target, isA<DebtTarget>());
    });

    test('dismissedIds=null → 不做挂失过滤(等价 scanner 未注入 store)', () {
      final active = filterActiveCandidates(
        fixture(),
        null,
        policy: DueReminderPolicy(),
        today: today,
      );
      expect(active.map((c) => c.entry.id), ['e1', 'e2', 'e3', 'e5']);
    });

    test('advanceDays 热更口径:e6 差 5 天,advanceDays=7 入窗', () {
      final active = filterActiveCandidates(
        fixture(),
        const {'e3'},
        policy: DueReminderPolicy(const DueReminderConfig(advanceDays: 7)),
        today: today,
      );
      expect(active.map((c) => c.entry.id), ['e1', 'e2', 'e5', 'e6']);
      expect(active.last.daysLeft, 5);
    });

    test('空入空出;全挂失空出', () {
      expect(
          filterActiveCandidates([], null,
              policy: DueReminderPolicy(), today: today),
          isEmpty);
      expect(
          filterActiveCandidates(
              fixture().take(3).toList(), const {'e1', 'e2', 'e3'},
              policy: DueReminderPolicy(), today: today),
          isEmpty);
    });
  });

  group('同源契约:scanner 路径 ≡ provider 路径(design ADR-1 / 风险 R1)', () {
    /// 断言形态:同一 fixture(假源)+ 同一挂失集(同一 drift 内存 store
    /// 实例 = 同一挂失真相)分别走两管线 ——
    /// - scanner 路径:空桶 log store 下去重空转,发送集 = 活跃候选集;
    /// - provider 路径:固定时钟下的 latest 视图集;
    /// 以「发送文案 = policy.compose(视图)」钉死标题/正文/档位语义双射,
    /// 两集合再对拍 fixture 预期活跃集(e1/e2/e5)。
    test('同一 fixture + 同一挂失集:两管线候选集一致', () async {
      final dismissals = await driftDismissalStore(['e3']); // e3 挂失
      const config = DueReminderConfig(advanceDays: 3);

      // 写侧路径:scanner(候选 → 通知发送)。
      final notifier = FakeNotifier();
      final scanner = DueScanner(
        source: FakeDueSource(fixture()),
        notifier: notifier,
        logStore: FakeLogStore(),
        policyProvider: () => DueReminderPolicy(config),
        dismissalStore: dismissals,
      );
      final result = await scanner.scan(today);
      expect(result.scanned, 6); // scanned = 原始条数(口径外/挂失不计发送)
      expect(result.sent, 3); // e1/e2/e5(与下方预期活跃集互证)

      // 读侧路径:provider(候选 → 视图广播;同源同挂失同配置同「今天」)。
      final provider = DueCandidateProvider(
        source: FakeDueSource(fixture()),
        dismissalStore: dismissals,
        configProvider: () => config,
        clock: () => today,
      );
      await provider.start();
      final views = provider.latest;

      // 形态 1:候选数量一致。
      expect(notifier.sent, hasLength(views.length));

      // 形态 2:scanner 发送文案集 = policy.compose 逐字套用 provider 视图
      // (标题/金额/相对天数/档位语义全对拍,compose 内部即 tierFor 口径)。
      final policy = DueReminderPolicy(config);
      (String, String) titleBody(DueCandidateView v) {
        final copy = policy.compose(
          debtName: v.title,
          totalCents: v.amountCents,
          tier: v.tier,
          today: today,
          paymentDate: v.dueDate,
        );
        return (copy.title, copy.body);
      }

      final expected = {for (final v in views) titleBody(v)};
      expect(notifier.sent.map((c) => (c.title, c.body)).toSet(), expected);

      // 形态 3:两管线都命中 fixture 预期活跃集(含逾期与挂失语义)。
      expect(views.map((v) => v.entryKey).toSet(), {'e1', 'e2', 'e5'});
      expect(
        notifier.sent.map((c) => c.title).toSet(),
        {'御财·房贷', '御财·车贷', '御财·当天'},
      );
      // 逾期语义对拍:车贷 overdue 4 天。
      expect(notifier.sent.map((c) => c.body), contains('已逾期 4 天,应还 ¥3,000.00'));

      await provider.dispose();
    });
  });
}
