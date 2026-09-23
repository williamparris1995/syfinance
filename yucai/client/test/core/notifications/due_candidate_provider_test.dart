// DueCandidateProvider 单测(2026-09 到期常显提醒,design ADR-1):
// 启动初始值 / 防抖合流 / 挂失过滤 / tier·daysLeft 映射(同 policy 口径)/
// 时钟注入确定性 / 源失败降级 / dispose 撤订阅 / syncer 寄宿入箱。
// 防抖用 fakeAsync(照 tray_controller_test 范式);drift 走内存库。
import 'dart:async';

import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/due_candidate_provider.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/due_target.dart';
import 'package:yucai_client/core/notifications/inbox/inbox_store.dart';
import 'package:yucai_client/core/notifications/inbox/inbox_syncer.dart';
import 'package:yucai_client/core/notifications/reminder_dismissal_store.dart';

/// 内存 fake:可变候选源(防抖刷新前后换内容,断言 latest 跟随)。
class FakeSource implements DueScheduleSource {
  FakeSource(this.entries);
  List<DueScheduleEntry> entries;
  bool failNext = false;

  @override
  Future<List<DueScheduleEntry>> unpaidDueCandidates() async {
    if (failNext) {
      failNext = false;
      throw StateError('db corrupted');
    }
    return entries;
  }
}

void main() {
  // 固定时钟(可注入,测试确定性):2026-09-23。
  final today = DateTime(2026, 9, 23);

  /// 广播流事件在非同步控制器里晚于 await 返回一轮送达 —— 排空事件环
  /// (照 tray_controller_test 的 pump 范式)。
  Future<void> pump([int times = 2]) async {
    for (var i = 0; i < times; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  List<DueScheduleEntry> fixture() => [
        DueScheduleEntry(
            id: 'e1',
            debtName: '房贷',
            totalCents: 100000,
            paymentDate: DateTime(2026, 9, 26),
            target: const DebtTarget('d1')), // advance 3 天
        DueScheduleEntry(
            id: 'e2',
            debtName: '车贷',
            totalCents: 300000,
            paymentDate: DateTime(2026, 9, 19),
            target: const DebtTarget('d2')), // overdue 4 天
        DueScheduleEntry(
            id: 'e3',
            debtName: '远期',
            totalCents: 400000,
            paymentDate: DateTime(2026, 10, 20),
            target: const DebtTarget('d3')), // 窗口外
        DueScheduleEntry(
            id: 'cc:a1:2026-09',
            debtName: '招行卡',
            totalCents: 5000,
            paymentDate: DateTime(2026, 9, 24),
            target: const AccountTarget('a1')), // advance 1 天
      ];

  DueCandidateProvider providerWith(
    FakeSource source,
    ReminderDismissalStore dismissals, {
    List<Stream<void>> triggers = const [],
    InboxSyncer? syncer,
  }) =>
      DueCandidateProvider(
        changeTriggers: triggers,
        source: source,
        dismissalStore: dismissals,
        configProvider: () => const DueReminderConfig(),
        syncer: syncer,
        clock: () => today,
      );

  test('start() 即发初始值:latest/stream 有数;窗口外剔除;tier·daysLeft·target 映射',
      () async {
    final source = FakeSource(fixture());
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dismissals = ReminderDismissalStore(db);
    final provider = providerWith(source, dismissals);
    final emissions = <List<DueCandidateView>>[];
    final sub = provider.stream.listen(emissions.add);
    expect(provider.latest, isEmpty); // 未 start 前 latest 为空

    await provider.start();
    await pump();

    expect(emissions, hasLength(1)); // 广播已发初始值
    final views = provider.latest;
    expect(views.map((v) => v.entryKey), ['e1', 'e2', 'cc:a1:2026-09']); // e3 窗口外
    final e1 = views.firstWhere((v) => v.entryKey == 'e1');
    expect(e1.title, '房贷');
    expect(e1.amountCents, 100000);
    expect(e1.dueDate, DateTime(2026, 9, 26));
    expect(e1.tier, DueTier.advance);
    expect(e1.daysLeft, 3);
    expect(e1.target, isA<DebtTarget>());
    final e2 = views.firstWhere((v) => v.entryKey == 'e2');
    expect(e2.tier, DueTier.overdue);
    expect(e2.daysLeft, -4); // 逾期 4 天(负 = 逾期天数)
    final cc = views.firstWhere((v) => v.entryKey == 'cc:a1:2026-09');
    expect(cc.daysLeft, 1);
    expect(cc.target, isA<AccountTarget>()); // 强类型路由目标透传(ADR-2)
    await sub.cancel();
    await provider.dispose();
  });

  test('挂失过滤:dismissed 集合内条目不出现在候选(挂失 = 本期不存在)', () async {
    final source = FakeSource(fixture());
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dismissals = ReminderDismissalStore(db);
    await dismissals.dismiss('e1');
    final provider = providerWith(source, dismissals);
    await provider.start();
    expect(provider.latest.map((v) => v.entryKey),
        ['e2', 'cc:a1:2026-09']); // e1 挂失被剔
    await provider.dispose();
  });

  test('防抖合流:窗口内 3 事件合流 1 次刷新;499ms 未刷;刷新跟源内容',
      () {
    fakeAsync((async) {
      final sc = StreamController<void>.broadcast();
      final source = FakeSource(fixture());
      final dismissals = ReminderDismissalStore(AppDatabase(NativeDatabase.memory()));
      final provider = providerWith(source, dismissals, triggers: [sc.stream]);
      final emissions = <List<DueCandidateView>>[];
      provider.stream.listen(emissions.add);
      unawaited(provider.start());
      async.flushMicrotasks();
      expect(emissions, hasLength(1)); // 初始值

      // 源变更(新候选 e5 当天到期)+ 3 事件落在同一防抖窗口。
      source.entries = [
        ...fixture(),
        DueScheduleEntry(
            id: 'e5',
            debtName: '当天',
            totalCents: 500000,
            paymentDate: today,
            target: const DebtTarget('d5')),
      ];
      sc.add(null);
      sc.add(null);
      sc.add(null);
      async.elapse(const Duration(milliseconds: 499));
      expect(emissions, hasLength(1)); // 防抖窗口内未刷
      expect(provider.latest.map((v) => v.entryKey), isNot(contains('e5')));

      async.elapse(const Duration(milliseconds: 2));
      async.flushMicrotasks();
      expect(emissions, hasLength(2)); // 3 事件合流为 1 次刷新
      expect(provider.latest.map((v) => v.entryKey), contains('e5'));

      unawaited(provider.dispose());
      async.flushMicrotasks();
    });
  });

  test('新事件重置防抖窗口', () {
    fakeAsync((async) {
      final sc = StreamController<void>.broadcast();
      final source = FakeSource(fixture());
      final dismissals = ReminderDismissalStore(AppDatabase(NativeDatabase.memory()));
      final provider = providerWith(source, dismissals, triggers: [sc.stream]);
      final emissions = <List<DueCandidateView>>[];
      provider.stream.listen(emissions.add);
      unawaited(provider.start());
      async.flushMicrotasks();

      sc.add(null);
      async.elapse(const Duration(milliseconds: 400));
      sc.add(null); // 重置窗口
      async.elapse(const Duration(milliseconds: 400));
      expect(emissions, hasLength(1)); // 距首事件 800ms 仍未刷(窗口被重置)
      async.elapse(const Duration(milliseconds: 101));
      async.flushMicrotasks();
      expect(emissions, hasLength(2)); // 距末事件 501ms 才刷

      unawaited(provider.dispose());
      async.flushMicrotasks();
    });
  });

  test('dispose():撤订阅与防抖 —— 后续 trigger 不再刷新', () {
    fakeAsync((async) {
      final sc = StreamController<void>.broadcast();
      final source = FakeSource(fixture());
      final dismissals = ReminderDismissalStore(AppDatabase(NativeDatabase.memory()));
      final provider = providerWith(source, dismissals, triggers: [sc.stream]);
      final emissions = <List<DueCandidateView>>[];
      provider.stream.listen(emissions.add);
      unawaited(provider.start());
      async.flushMicrotasks();
      expect(emissions, hasLength(1));

      unawaited(provider.dispose());
      async.flushMicrotasks();
      sc.add(null);
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(emissions, hasLength(1)); // 订阅已撤,不再刷新
    });
  });

  test('源抛错 → 保持旧 latest、不新发、不炸(附属降级,下次触发重试)', () {
    fakeAsync((async) {
      final sc = StreamController<void>.broadcast();
      final source = FakeSource(fixture());
      final dismissals = ReminderDismissalStore(AppDatabase(NativeDatabase.memory()));
      final provider = providerWith(source, dismissals, triggers: [sc.stream]);
      final emissions = <List<DueCandidateView>>[];
      provider.stream.listen(emissions.add);
      unawaited(provider.start());
      async.flushMicrotasks();
      final before = provider.latest;
      expect(before, isNotEmpty);

      source.failNext = true;
      sc.add(null);
      async.elapse(const Duration(milliseconds: 501));
      async.flushMicrotasks();
      expect(emissions, hasLength(1)); // 失败不新发
      expect(provider.latest, same(before)); // 旧值原样保持

      // 下次触发恢复(failNext 已自复位)。
      sc.add(null);
      async.elapse(const Duration(milliseconds: 501));
      async.flushMicrotasks();
      expect(emissions, hasLength(2));

      unawaited(provider.dispose());
      async.flushMicrotasks();
    });
  });

  test('syncer 寄宿:refresh 尾随入箱;挂失后下一轮定态 dismissed(2)',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = InboxStore(db);
    final dismissals = ReminderDismissalStore(db);
    final syncer = InboxSyncer(store: store, dismissalStore: dismissals);
    final source = FakeSource(fixture());
    final provider = providerWith(source, dismissals, syncer: syncer);

    await provider.start();
    var rows = await store.activeEntries();
    expect(rows.map((r) => r.entryKey).toSet(),
        {'e1', 'e2', 'cc:a1:2026-09'}); // 窗口内未挂失全部入箱
    expect(rows.every((r) => r.state == InboxEntryState.pending.index), isTrue);

    // 用户「不再提醒」e1 → 挂失表写入;再触发一轮(手动调 diff 由 provider
    // 寄宿,此处直接以刷新后的候选集验证:候选流剔 e1 + 收件箱定态)。
    await dismissals.dismiss('e1');
    await syncer.diff(provider.latest.where((v) => v.entryKey != 'e1').toList());
    rows = await store.activeEntries();
    expect(rows.map((r) => r.entryKey), ['e2', 'cc:a1:2026-09']); // e1 沉底
    final settled = (await store.all()).firstWhere((r) => r.entryKey == 'e1');
    expect(settled.state, InboxEntryState.dismissed.index);
    await provider.dispose();
  });

  test('配置热更:configProvider 每轮刷新重读(advanceDays 扩窗即时生效)',
      () {
    fakeAsync((async) {
      final sc = StreamController<void>.broadcast();
      final source = FakeSource(fixture());
      final dismissals = ReminderDismissalStore(AppDatabase(NativeDatabase.memory()));
      var cfg = const DueReminderConfig(advanceDays: 3);
      final provider = DueCandidateProvider(
        changeTriggers: [sc.stream],
        source: source,
        dismissalStore: dismissals,
        configProvider: () => cfg,
        clock: () => today,
      );
      unawaited(provider.start());
      async.flushMicrotasks();
      expect(provider.latest.map((v) => v.entryKey),
          isNot(contains('e3'))); // 差 27 天:3 天窗口外

      cfg = const DueReminderConfig(advanceDays: 30); // 设置页扩窗
      sc.add(null);
      async.elapse(const Duration(milliseconds: 501));
      async.flushMicrotasks();
      expect(provider.latest.map((v) => v.entryKey), contains('e3'));

      unawaited(provider.dispose());
      async.flushMicrotasks();
    });
  });
}
