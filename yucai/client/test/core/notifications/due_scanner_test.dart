import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';

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

/// 内存 fake:当日已发记录。
class FakeLogStore implements ReminderLogStore {
  FakeLogStore(this.sentKeys);
  final Set<String> sentKeys;
  @override
  Future<bool> wasSentToday(String entryId, DueTier tier, DateTime today) async =>
      sentKeys.contains('${tier.name}|$entryId|${_day(today)}');
  @override
  Future<void> markSent(String entryId, DueTier tier, DateTime today) async =>
      sentKeys.add('${tier.name}|$entryId|${_day(today)}');

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

DueScanner scannerWith(List<DueScheduleEntry> entries, FakeNotifier n, {Set<String>? keys}) =>
    DueScanner(source: FakeDueSource(entries), notifier: n, logStore: FakeLogStore(keys ?? <String>{}));

void main() {
  final today = DateTime(2026, 8, 29);

  test('三档命中:t3/t0/overdue 各发一条,窗口外与差 1/2 天跳过', () async {
    final n = FakeNotifier();
    final s = scannerWith([
      DueScheduleEntry(id: 'e1', debtName: '房贷', totalCents: 100000, paymentDate: DateTime(2026, 9, 1)), // t3
      DueScheduleEntry(id: 'e2', debtName: '信用卡', totalCents: 200000, paymentDate: today), // t0
      DueScheduleEntry(id: 'e3', debtName: '车贷', totalCents: 300000, paymentDate: DateTime(2026, 8, 25)), // overdue 4 天
      DueScheduleEntry(id: 'e4', debtName: '远期', totalCents: 400000, paymentDate: DateTime(2026, 9, 20)), // 窗口外
      DueScheduleEntry(id: 'e5', debtName: '差2天', totalCents: 500000, paymentDate: DateTime(2026, 8, 31)), // 不发
    ], n);
    final result = await s.scan(today);
    expect(result.scanned, 5);
    expect(result.sent, 3);
    expect(n.sent.map((c) => c.title), containsAll(['御财·房贷', '御财·信用卡', '御财·车贷']));
    expect(n.sent.map((c) => c.body), contains('已逾期 4 天,应还 ¥3,000.00'));
  });

  test('当日去重:同档同日已发 → 跳过', () async {
    final n = FakeNotifier();
    final s = scannerWith(
      [DueScheduleEntry(id: 'e1', debtName: '房贷', totalCents: 100000, paymentDate: DateTime(2026, 9, 1))],
      n,
      keys: {'t3|e1|2026-08-29'},
    );
    final result = await s.scan(today);
    expect(result.sent, 0);
    expect(n.sent, isEmpty);
  });

  test('逾期跨日再发:昨日 overdue 已发,今日再扫仍发(每日一次语义)', () async {
    final n = FakeNotifier();
    final s = scannerWith(
      [DueScheduleEntry(id: 'e3', debtName: '车贷', totalCents: 99005, paymentDate: DateTime(2026, 8, 24))],
      n,
      keys: {'overdue|e3|2026-08-28'},
    );
    final result = await s.scan(today);
    expect(result.sent, 1);
    expect(n.sent.single.body, '已逾期 5 天,应还 ¥990.05');
  });

  test('空扫描:无候选 → 0 条', () async {
    final n = FakeNotifier();
    final result = await scannerWith([], n).scan(today);
    expect(result.sent, 0);
    expect(result.scanned, 0);
  });

  test('已发档位写回日志(重复调用第二次 0 条)', () async {
    final n = FakeNotifier();
    final s = scannerWith(
      [DueScheduleEntry(id: 'e2', debtName: '信用卡', totalCents: 200000, paymentDate: today)],
      n,
    );
    expect((await s.scan(today)).sent, 1);
    expect((await s.scan(today)).sent, 0); // markSent 生效
  });
}
