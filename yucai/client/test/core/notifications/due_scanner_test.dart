import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:drift/native.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/reminder_dismissal_store.dart';

/// 内存 fake:期次候选源。
class FakeDueSource implements DueScheduleSource {
  FakeDueSource(this.entries);
  final List<DueScheduleEntry> entries;
  @override
  Future<List<DueScheduleEntry>> unpaidDueCandidates() async => entries;
}

/// 内存 fake:通知发送器(记录全部发送)。
class FakeNotifier implements ReminderNotifier {
  final sent = <DueNotificationCopy>[];
  @override
  Future<void> show(DueNotificationCopy copy) async => sent.add(copy);
}

/// 内存 fake:桶粒度已发记录。
class FakeLogStore implements ReminderLogStore {
  FakeLogStore(this.sentKeys);
  final Set<String> sentKeys;
  @override
  Future<bool> wasSent(String entryId, DueTier tier, String bucketToken) async =>
      sentKeys.contains('${tier.name}|$entryId|$bucketToken');
  @override
  Future<void> markSent(String entryId, DueTier tier, String bucketToken) async =>
      sentKeys.add('${tier.name}|$entryId|$bucketToken');
}

/// 内存 drift 挂失存储(走真实表,顺带覆盖 schema)。
ReminderDismissalStore driftDismissalStore() =>
    ReminderDismissalStore(db.AppDatabase(NativeDatabase.memory()));

DueScanner scannerWith(List<DueScheduleEntry> entries, FakeNotifier n,
        {Set<String>? keys, ReminderDismissalStore? dismissals}) =>
    DueScanner(
      source: FakeDueSource(entries),
      notifier: n,
      logStore: FakeLogStore(keys ?? <String>{}),
      dismissalStore: dismissals,
    );

void main() {
  final today = DateTime(2026, 8, 29);

  test('档位命中:窗口内(含差 1/2 天)都发,窗口外跳过', () async {
    final n = FakeNotifier();
    final s = scannerWith([
      DueScheduleEntry(id: 'e1', debtName: '房贷', totalCents: 100000, paymentDate: DateTime(2026, 9, 1)), // advance 3 天
      DueScheduleEntry(id: 'e2', debtName: '信用卡', totalCents: 200000, paymentDate: today), // advance 当天
      DueScheduleEntry(id: 'e3', debtName: '车贷', totalCents: 300000, paymentDate: DateTime(2026, 8, 25)), // overdue 4 天
      DueScheduleEntry(id: 'e4', debtName: '远期', totalCents: 400000, paymentDate: DateTime(2026, 9, 20)), // 窗口外
      DueScheduleEntry(id: 'e5', debtName: '差2天', totalCents: 500000, paymentDate: DateTime(2026, 8, 31)), // 催办:也发
    ], n);
    final result = await s.scan(today);
    expect(result.scanned, 5);
    expect(result.sent, 4);
    expect(n.sent.map((c) => c.title),
        containsAll(['御财·房贷', '御财·信用卡', '御财·车贷', '御财·差2天']));
    expect(n.sent.map((c) => c.body), contains('已逾期 4 天,应还 ¥3,000.00'));
  });

  test('桶去重:同桶已发 → 跳过', () async {
    final policy = DueReminderPolicy();
    final token = policy.bucketToken(DateTime.now());
    final n = FakeNotifier();
    final s = scannerWith(
      [DueScheduleEntry(id: 'e1', debtName: '房贷', totalCents: 100000, paymentDate: DateTime(2026, 9, 1))],
      n,
      keys: {'advance|e1|$token'},
    );
    final result = await s.scan(today);
    expect(result.sent, 0);
    expect(n.sent, isEmpty);
  });

  test('重复调用第二次 0 条(markSent 写回生效)', () async {
    final n = FakeNotifier();
    final s = scannerWith(
      [DueScheduleEntry(id: 'e2', debtName: '信用卡', totalCents: 200000, paymentDate: today)],
      n,
    );
    expect((await s.scan(today)).sent, 1);
    expect((await s.scan(today)).sent, 0);
  });

  test('挂失条目整期停催(不再提醒)', () async {
    final store = driftDismissalStore();
    await store.dismiss('e3');
    final n = FakeNotifier();
    final s = scannerWith(
      [DueScheduleEntry(id: 'e3', debtName: '车贷', totalCents: 99005, paymentDate: DateTime(2026, 8, 24))],
      n,
      dismissals: store,
    );
    final result = await s.scan(today);
    expect(result.sent, 0);
    expect(n.sent, isEmpty);
  });

  test('挂失幂等:同条目重复挂失不炸、不入重复行', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    final store = ReminderDismissalStore(database);
    await store.dismiss('x');
    await store.dismiss('x');
    expect((await store.dismissedEntryIds()), {'x'});
  });

  test('空扫描:无候选 → 0 条', () async {
    final n = FakeNotifier();
    final result = await scannerWith([], n).scan(today);
    expect(result.sent, 0);
    expect(result.scanned, 0);
  });

  test('配置热更:policyProvider 每轮扫描重读(改提前天数即时生效)', () async {
    final n = FakeNotifier();
    var cfg = const DueReminderConfig(advanceDays: 1);
    final s = DueScanner(
      source: FakeDueSource([
        DueScheduleEntry(id: 'e5', debtName: '差2天', totalCents: 500000, paymentDate: DateTime(2026, 8, 31)),
      ]),
      notifier: n,
      logStore: FakeLogStore(<String>{}),
      policyProvider: () => DueReminderPolicy(cfg),
    );
    // advanceDays=1:差 2 天 → 不发。
    expect((await s.scan(today)).sent, 0);
    // 设置改为 3:同一候选立刻进入窗口。
    cfg = const DueReminderConfig(advanceDays: 3);
    expect((await s.scan(today)).sent, 1);
  });
}
