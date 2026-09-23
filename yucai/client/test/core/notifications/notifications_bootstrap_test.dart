// T5 装配冒烟(2026-09 到期常显提醒,design ADR-1/ADR-5):
// assembleDueCandidatePipeline 后 —— getIt 可取共享 provider/store(与
// 返回值同源);syncer 挂管道尾(注入假件断言 diff 被调);真实管线端到端
// —— 窗口内期次入箱 / 窗口外不入 / 挂失后候选消失且收件箱定态。
// drift 走内存库;防抖 500ms 为真实 Timer,以轮询等待。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/due_candidate_provider.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/drift_due_source.dart';
import 'package:yucai_client/core/notifications/inbox/inbox_store.dart';
import 'package:yucai_client/core/notifications/inbox/inbox_syncer.dart';
import 'package:yucai_client/core/notifications/notifications_bootstrap.dart';
import 'package:yucai_client/core/notifications/reminder_dismissal_store.dart';

/// 假件:记录 diff 调用次数,行为沿用真实现(brief 必测项「可注入假件
/// 断言 diff 被调」)。
class _RecordingSyncer extends InboxSyncer {
  _RecordingSyncer({required super.store, required super.dismissalStore});
  int diffCalls = 0;

  @override
  Future<void> diff(List<DueCandidateView> candidates) async {
    diffCalls++;
    await super.diff(candidates);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    // 先停 provider(撤 watch 订阅)再清 getIt,避免泄漏到下一用例。
    if (getIt.isRegistered<DueCandidateProvider>()) {
      await getIt<DueCandidateProvider>().dispose();
    }
    getIt.reset();
  });

  /// 种子:1 笔窗口内未付期次(e1,3 天后)+ 1 笔窗口外(e2,30 天后)。
  Future<AppDatabase> seededDb() async {
    final db = AppDatabase(NativeDatabase.memory());
    final now = DateTime.now();
    await db.into(db.debts).insert(DebtsCompanion.insert(
          id: 'd1',
          accountId: 'a-x',
          counterparty: '房贷',
          interestRate: 0.03,
          amortizationMethod: 0,
          startDate: now,
          dueDate: now.add(const Duration(days: 3600)),
          totalPrincipalCents: 1000000,
          debtType: 0,
          subtype: '',
          contact: '',
          contractRef: '',
          version: 1,
          createdAt: now,
          updatedAt: now,
        ));
    Future<void> entry(String id, Duration offset) async {
      await db.into(db.paymentScheduleEntries).insert(
            PaymentScheduleEntriesCompanion.insert(
              id: id,
              debtId: 'd1',
              paymentDate:
                  DateTime(now.year, now.month, now.day).add(offset),
              principalCents: 50000,
              interestCents: 500,
              totalCents: 50500,
              paidCents: 0,
              paid: false,
            ),
          );
    }

    await entry('e1', const Duration(days: 3)); // advance 3 天窗口内
    await entry('e2', const Duration(days: 30)); // 窗口外
    return db;
  }

  /// 轮询等待条件成立(防抖 500ms 真实 Timer;drift watch 事件异步)。
  Future<bool> until(bool Function() cond,
      [int rounds = 40, Duration gap = const Duration(milliseconds: 50)]) async {
    for (var i = 0; i < rounds; i++) {
      if (cond()) return true;
      await Future<void>.delayed(gap);
    }
    return cond();
  }

  test('装配冒烟:注册可取 + syncer 挂尾 diff 被调 + 端到端入箱/窗口过滤', () async {
    final db = await seededDb();
    addTearDown(db.close);
    final store = InboxStore(db);
    final dismissals = ReminderDismissalStore(db);
    final syncer = _RecordingSyncer(store: store, dismissalStore: dismissals);
    final provider = await assembleDueCandidatePipeline(
      db: db,
      // 与写侧 scanner 同构的 MultiDueSource(生产侧为同一实例,NFR-1)。
      source: MultiDueSource([
        DriftDueSource(db,
            configProvider: () => const DueReminderConfig()),
      ]),
      dismissalStore: dismissals,
      configProvider: () => const DueReminderConfig(),
      syncer: syncer,
    );

    // 注册冒烟:provider 与返回值同一实例;store 可取且经同库读到同一
    // 台账(InboxStore 是无状态 CRUD 包装、多实例同库无害 —— 注入假件
    // syncer 时函数内部另构 store 注册,数据面等价,T4 兜底同语义)。
    expect(getIt.isRegistered<DueCandidateProvider>(), isTrue);
    expect(getIt.isRegistered<InboxStore>(), isTrue);
    expect(identical(getIt<DueCandidateProvider>(), provider), isTrue);

    // syncer 挂管道尾:启动初始 refresh 即调 diff ≥ 1 次。
    expect(syncer.diffCalls, greaterThanOrEqualTo(1));

    // 端到端:窗口内候选入箱(真实 syncer 效果),窗口外不入。
    final rows = await store.activeEntries();
    expect(rows.map((r) => r.entryKey), ['e1']);
    expect(rows.single.title, '房贷');
    expect(rows.single.targetKind, kInboxTargetKindDebt);
    // getIt 取得的 store 读到同一台账(同库等价)。
    expect((await getIt<InboxStore>().activeEntries())
        .map((r) => r.entryKey), ['e1']);

    // latest:候选视图窗口过滤后只剩 e1,天数口径 3。
    expect(provider.latest.map((v) => v.entryKey), ['e1']);
    expect(provider.latest.single.daysLeft, 3);
  });

  test('挂失 → watch 触发防抖刷新:候选消失、diff 再调、收件箱定态 dismissed', () async {
    final db = await seededDb();
    addTearDown(db.close);
    final store = InboxStore(db);
    final dismissals = ReminderDismissalStore(db);
    final syncer = _RecordingSyncer(store: store, dismissalStore: dismissals);
    final provider = await assembleDueCandidatePipeline(
      db: db,
      source: MultiDueSource([
        DriftDueSource(db,
            configProvider: () => const DueReminderConfig()),
      ]),
      dismissalStore: dismissals,
      configProvider: () => const DueReminderConfig(),
      syncer: syncer,
    );
    expect(provider.latest.map((v) => v.entryKey), ['e1']);
    final diffBefore = syncer.diffCalls;

    // 「不再提醒」挂失 e1 → reminderDismissals 表 watch → 500ms 防抖刷新。
    await dismissals.dismiss('e1');
    expect(
      await until(
          () => provider.latest.where((v) => v.entryKey == 'e1').isEmpty),
      isTrue,
      reason: '挂失后候选应在防抖刷新后消失',
    );

    // diff 再次被调(管道尾寄宿,非一次性)。
    expect(syncer.diffCalls, greaterThan(diffBefore));

    // 收件箱定态:e1 → dismissed(ADR-3 挂失表查证)。
    final row = (await store.all()).singleWhere((r) => r.entryKey == 'e1');
    expect(row.state, InboxEntryState.dismissed.index);
    expect(row.handledAt, isNotNull);
  });
}
