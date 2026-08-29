import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/notifications/auto_record_scheduler.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';

class FakeTemplates implements AutoRecordTemplates {
  FakeTemplates(this.rows) : _next = {for (final r in rows) r.id: r.nextDate};
  final List<AutoRecordTemplate> rows;
  final Map<String, DateTime> _next; // 模拟 repo:record 推进自身 nextDate
  final recorded = <String>[];
  int failOnNthCallOf = -1; // 第 N 次 record 调用抛错(1-based,含失败调用)
  int _calls = 0;

  @override
  Future<List<AutoRecordTemplate>> listAutoRecordDue() async => rows;

  @override
  Future<DateTime?> record(String id) async {
    _calls++;
    if (_calls == failOnNthCallOf) {
      throw StateError('boom');
    }
    recorded.add(id);
    final advanced = _next[id]!.add(const Duration(days: 7)); // weekly
    _next[id] = advanced;
    return advanced;
  }
}

class FakeNotifier implements ReminderNotifier {
  final sent = <DueNotificationCopy>[];
  @override
  Future<void> show(DueNotificationCopy copy) async => sent.add(copy);
}

AutoRecordTemplate tmpl(
  String id, {
  required DateTime nextDate,
  DateTime? endDate,
  String name = '房租',
  int amountCents = 200000,
}) =>
    AutoRecordTemplate(
        id: id,
        name: name,
        amountCents: amountCents,
        nextDate: nextDate,
        endDate: endDate);

void main() {
  final today = DateTime(2026, 9, 15);

  test('一次性补齐:断网 3 周(weekly nextDate=8/25)→ 含今日共 4 期全记 + 批量通知', () async {
    final t = FakeTemplates([tmpl('a', nextDate: DateTime(2026, 8, 25))]);
    final n = FakeNotifier();
    final r = await AutoRecordScheduler(templates: t, notifier: n).run(today);
    expect(r.recorded, 4); // 8/25, 9/1, 9/8, 9/15(到期含当日)
    expect(n.sent.single.title, '御财·房租');
    expect(n.sent.single.body, '已自动补记 4 笔');
  });

  test('单笔场景:今日到期 → 记 1 笔 + 单笔通知含金额', () async {
    final t = FakeTemplates([tmpl('a', nextDate: today)]);
    final n = FakeNotifier();
    final r = await AutoRecordScheduler(templates: t, notifier: n).run(today);
    expect(r.recorded, 1);
    expect(n.sent.single.body, '已自动记账,应记 ¥2,000.00');
  });

  test('endDate 截断:发生日 ≤ endDate 才记(9/1 与 9/8 均记,9/15 超期停)', () async {
    final t = FakeTemplates(
        [tmpl('a', nextDate: DateTime(2026, 9, 1), endDate: DateTime(2026, 9, 8))]);
    final n = FakeNotifier();
    final r = await AutoRecordScheduler(templates: t, notifier: n).run(today);
    expect(r.recorded, 2);
  });

  test('未到期(同日重跑语义:nextDate 已过 today)→ 零新增零通知', () async {
    final t = FakeTemplates([tmpl('a', nextDate: DateTime(2026, 9, 20))]);
    final n = FakeNotifier();
    final r = await AutoRecordScheduler(templates: t, notifier: n).run(today);
    expect(r.recorded, 0);
    expect(n.sent, isEmpty);
  });

  test('多模板各自补齐 + 单模板失败继续其余', () async {
    final t = FakeTemplates([
      tmpl('a', nextDate: DateTime(2026, 8, 25)), // 4 笔
      tmpl('b', nextDate: today, name: '工资'), // 1 笔
    ]);
    t.failOnNthCallOf = 1; // 首次 record 抛错(a 的第一笔)
    final n = FakeNotifier();
    final r = await AutoRecordScheduler(templates: t, notifier: n).run(today);
    expect(r.failed, 1);
    expect(r.recorded, 1); // b 的 1 笔
  });
}
