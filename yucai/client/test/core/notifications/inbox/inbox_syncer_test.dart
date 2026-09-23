// InboxSyncer 单测(2026-09 到期常显提醒,design ADR-1/ADR-3 + LLD 伪代码):
// 入箱 upsert / 消失定态(挂失→2、滚动·还清→1)/ 幂等 / 滚动刷新 /
// 定态不复活。内存库范式照 inbox_store_test。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/due_candidate_provider.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_target.dart';
import 'package:yucai_client/core/notifications/inbox/inbox_store.dart';
import 'package:yucai_client/core/notifications/inbox/inbox_syncer.dart';
import 'package:yucai_client/core/notifications/reminder_dismissal_store.dart';

void main() {
  late AppDatabase db;
  late InboxStore store;
  late ReminderDismissalStore dismissals;
  late InboxSyncer syncer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = InboxStore(db);
    dismissals = ReminderDismissalStore(db);
    syncer = InboxSyncer(store: store, dismissalStore: dismissals);
  });

  tearDown(() async {
    await db.close();
  });

  /// 视图工厂(直构 DueCandidateView —— syncer 只消费候选形态,不问来处)。
  DueCandidateView view(
    String key,
    String title,
    int cents,
    DateTime due,
    DueTarget target,
  ) =>
      DueCandidateView(
        entryKey: key,
        title: title,
        amountCents: cents,
        dueDate: due,
        tier: DueTier.advance,
        daysLeft: 2,
        target: target,
      );

  test('入箱 upsert:候选 → 待处理行,字段齐(type/target 编码/dueDate)',
      () async {
    await syncer.diff([
      view('d1-e0', '房贷', 100000, DateTime(2026, 9, 26), const DebtTarget('d1')),
      view('cc:a1:2026-09', '招行卡', 5000, DateTime(2026, 9, 25),
          const AccountTarget('a1')),
    ]);
    final rows = await store.all();
    expect(rows, hasLength(2));
    expect(rows.every((r) => r.state == InboxEntryState.pending.index), isTrue);
    expect(rows.every((r) => r.type == 'due_reminder'), isTrue);
    expect(rows.every((r) => r.handledAt == null), isTrue);
    final debt = rows.firstWhere((r) => r.entryKey == 'd1-e0');
    expect(debt.title, '房贷');
    expect(debt.amountCents, 100000);
    expect(debt.dueDate, '2026-09-26');
    expect(debt.targetKind, 1); // debt
    expect(debt.targetId, 'd1');
    final cc = rows.firstWhere((r) => r.entryKey == 'cc:a1:2026-09');
    expect(cc.targetKind, 0); // account
    expect(cc.targetId, 'a1');
  });

  test('幂等:重复 diff 同一候选集 → 不重复插、仍 pending', () async {
    final c = [view('d1-e0', '房贷', 100000, DateTime(2026, 9, 26), const DebtTarget('d1'))];
    await syncer.diff(c);
    await syncer.diff(c);
    final rows = await store.all();
    expect(rows, hasLength(1));
    expect(rows.single.state, InboxEntryState.pending.index);
    expect(rows.single.handledAt, isNull);
  });

  test('消失 → 挂失表在 → dismissed(2)+ handledAt(ADR-3)', () async {
    await syncer.diff(
        [view('cc:a1:2026-09', '招行卡', 5000, DateTime(2026, 9, 25), const AccountTarget('a1'))]);
    // 用户「不再提醒」:挂失表新增 + 候选流过滤 → 下一轮 diff 候选消失。
    await dismissals.dismiss('cc:a1:2026-09');
    await syncer.diff([]);
    final r = (await store.all()).single;
    expect(r.state, InboxEntryState.dismissed.index);
    expect(r.handledAt, isNotNull);
  });

  test('消失 → 不在挂失表(还清/跨月滚动)→ handled(1)+ handledAt(ADR-3)',
      () async {
    await syncer.diff([
      view('d1-e0', '房贷', 100000, DateTime(2026, 9, 26), const DebtTarget('d1')),
      view('cc:a1:2026-09', '招行卡', 5000, DateTime(2026, 9, 25), const AccountTarget('a1')),
    ]);
    // 期次标记已付(d1-e0 消失);跨月滚动(cc 旧月 key 消失、新月 key 顶班)。
    await syncer.diff([
      view('cc:a1:2026-10', '招行卡', 5000, DateTime(2026, 10, 25), const AccountTarget('a1')),
    ]);
    final rows = await store.all();
    final paid = rows.firstWhere((r) => r.entryKey == 'd1-e0');
    expect(paid.state, InboxEntryState.handled.index);
    expect(paid.handledAt, isNotNull);
    final rolled = rows.firstWhere((r) => r.entryKey == 'cc:a1:2026-09');
    expect(rolled.state, InboxEntryState.handled.index); // 近似裁决:滚动标已处理
    final fresh = rows.firstWhere((r) => r.entryKey == 'cc:a1:2026-10');
    expect(fresh.state, InboxEntryState.pending.index); // 新月条目顶班不漏事
  });

  test('滚动刷新:同 key 金额变 → 行字段更新(createdAt 不动由 store 保证)',
      () async {
    await syncer.diff(
        [view('cc:a1:2026-09', '招行卡', 5000, DateTime(2026, 9, 25), const AccountTarget('a1'))]);
    // 最低还款后仍欠:金额变化但条目未消失。
    await syncer.diff(
        [view('cc:a1:2026-09', '招行卡', 3000, DateTime(2026, 9, 25), const AccountTarget('a1'))]);
    final rows = await store.all();
    expect(rows, hasLength(1));
    expect(rows.single.amountCents, 3000);
    expect(rows.single.state, InboxEntryState.pending.index);
  });

  test('部分消失:仅消失的定态,仍在的不动', () async {
    await syncer.diff([
      view('k1', 'A', 100, DateTime(2026, 9, 25), const DebtTarget('d1')),
      view('k2', 'B', 200, DateTime(2026, 9, 26), const DebtTarget('d2')),
    ]);
    await syncer.diff(
        [view('k2', 'B', 200, DateTime(2026, 9, 26), const DebtTarget('d2'))]);
    final rows = await store.all();
    final gone = rows.firstWhere((r) => r.entryKey == 'k1');
    final stay = rows.firstWhere((r) => r.entryKey == 'k2');
    expect(gone.state, InboxEntryState.handled.index);
    expect(stay.state, InboxEntryState.pending.index);
    expect(stay.handledAt, isNull);
  });

  test('定态不复活:消失定态后候选再回(同 key)→ 不动仍 handled', () async {
    await syncer.diff(
        [view('k1', 'A', 100, DateTime(2026, 9, 25), const DebtTarget('d1'))]);
    await syncer.diff([]);
    await syncer.diff(
        [view('k1', 'A', 999, DateTime(2026, 9, 25), const DebtTarget('d1'))]);
    final r = (await store.all()).single;
    expect(r.state, InboxEntryState.handled.index); // ADR-3:定态不可逆
    expect(r.amountCents, 100); // 字段冻结
  });
}
