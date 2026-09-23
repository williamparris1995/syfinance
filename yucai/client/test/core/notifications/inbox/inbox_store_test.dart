// InboxStore 单测(2026-09 到期常显提醒,design ADR-4/ADR-6):
// 入窗 upsert 幂等 / state=0 滚动更新 / settle 定态不复活 / lastSeen 往返。
// 内存库范式照 credit_card_due_source_test。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/due_target.dart';
import 'package:yucai_client/core/notifications/inbox/inbox_store.dart';

void main() {
  late AppDatabase db;
  late InboxStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = InboxStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('upsert 幂等:同 entryKey 不重复插;行落 type/target 编码/dueDate 格式',
      () async {
    await store.upsertActive(
      entryKey: 'd1-e0',
      title: '房贷',
      amountCents: 100000,
      dueDate: DateTime(2026, 9, 30),
      target: const DebtTarget('d1'),
    );
    await store.upsertActive(
      entryKey: 'd1-e0',
      title: '房贷',
      amountCents: 100000,
      dueDate: DateTime(2026, 9, 30),
      target: const DebtTarget('d1'),
    );
    final rows = await store.all();
    expect(rows, hasLength(1));
    final r = rows.single;
    expect(r.entryKey, 'd1-e0');
    expect(r.type, 'due_reminder'); // 本期恒到期提醒(类型预留)
    expect(r.state, InboxEntryState.pending.index);
    expect(r.handledAt, isNull);
    expect(r.targetKind, 1); // debt
    expect(r.targetId, 'd1');
    expect(r.dueDate, '2026-09-30'); // yyyy-MM-dd 文本
    expect(r.createdAt, greaterThan(0));

    // AccountTarget 编码:0 / accountId。
    await store.upsertActive(
      entryKey: 'cc:a1:2026-09',
      title: '招行卡',
      amountCents: 5000,
      dueDate: DateTime(2026, 9, 25),
      target: const AccountTarget('a1'),
    );
    final cc = (await store.all()).last;
    expect(cc.targetKind, 0); // account
    expect(cc.targetId, 'a1');
  });

  test('state=0 时 upsert 更新 title/amountCents/dueDate;createdAt 不变',
      () async {
    await store.upsertActive(
      entryKey: 'cc:a1:2026-09',
      title: '招行卡',
      amountCents: 5000,
      dueDate: DateTime(2026, 9, 25),
      target: const AccountTarget('a1'),
    );
    final firstCreatedAt = (await store.all()).single.createdAt;
    // 候选滚动:金额/到期日/名称变了(如最低还款后仍欠)。
    await store.upsertActive(
      entryKey: 'cc:a1:2026-09',
      title: '招行信用卡',
      amountCents: 3000,
      dueDate: DateTime(2026, 9, 26),
      target: const AccountTarget('a1'),
    );
    final rows = await store.all();
    expect(rows, hasLength(1)); // 仍单行
    final r = rows.single;
    expect(r.title, '招行信用卡');
    expect(r.amountCents, 3000);
    expect(r.dueDate, '2026-09-26');
    expect(r.createdAt, firstCreatedAt); // 入窗时刻是小圆点基准,不随刷新漂移
    expect(r.state, InboxEntryState.pending.index);
  });

  test('settle 定态:→handled/dismissed 写 handledAt;upsert 不复活', () async {
    await store.upsertActive(
      entryKey: 'd1-e0',
      title: '房贷',
      amountCents: 100000,
      dueDate: DateTime(2026, 9, 30),
      target: const DebtTarget('d1'),
    );
    await store.settle('d1-e0', state: InboxEntryState.handled);
    var r = (await store.all()).single;
    expect(r.state, InboxEntryState.handled.index);
    expect(r.handledAt, isNotNull);

    // 已定态 → upsert 不复活、字段不动(滚动老条目已定态就不动)。
    await store.upsertActive(
      entryKey: 'd1-e0',
      title: '房贷改',
      amountCents: 1,
      dueDate: DateTime(2026, 10, 30),
      target: const DebtTarget('d1'),
    );
    r = (await store.all()).single;
    expect(r.state, InboxEntryState.handled.index);
    expect(r.title, '房贷'); // 定态后字段冻结
    expect(r.amountCents, 100000);

    // settle 仅对 state=0 生效:已 handled 再 settle(dismissed)不动。
    await store.settle('d1-e0', state: InboxEntryState.dismissed);
    r = (await store.all()).single;
    expect(r.state, InboxEntryState.handled.index);

    // settle 不存在的 key:静默 no-op。
    await store.settle('ghost', state: InboxEntryState.handled);
    expect(await store.all(), hasLength(1));
  });

  test('settle → dismissed:挂失态落 2', () async {
    await store.upsertActive(
      entryKey: 'cc:a1:2026-09',
      title: '招行卡',
      amountCents: 5000,
      dueDate: DateTime(2026, 9, 25),
      target: const AccountTarget('a1'),
    );
    await store.settle('cc:a1:2026-09', state: InboxEntryState.dismissed);
    final r = (await store.all()).single;
    expect(r.state, InboxEntryState.dismissed.index);
    expect(r.handledAt, isNotNull);
  });

  test('activeEntries:仅 state=0 且 createdAt 升序;all 含历史', () async {
    Future<void> put(String key, {InboxEntryState settleTo = InboxEntryState.pending}) async {
      await store.upsertActive(
        entryKey: key,
        title: key,
        amountCents: 1,
        dueDate: DateTime(2026, 9, 30),
        target: DebtTarget('d$key'),
      );
      if (settleTo != InboxEntryState.pending) {
        await store.settle(key, state: settleTo);
      }
    }

    await put('k1'); // 先入窗
    await put('k2');
    await put('k3', settleTo: InboxEntryState.handled); // 历史
    await put('k4');
    await put('k5', settleTo: InboxEntryState.dismissed); // 历史

    // createdAt 是毫秒精度,同轮插入可能同值 —— 逐行断言集合与排序稳定性:
    // 待处理恰为 k1/k2/k4(升序),all 为全部 5 行。
    final active = await store.activeEntries();
    expect(active.map((r) => r.entryKey).toSet(), {'k1', 'k2', 'k4'});
    expect(active.every((r) => r.state == InboxEntryState.pending.index),
        isTrue);
    final createdKeys = active.map((r) => (r.createdAt, r.entryKey)).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    expect(createdKeys.map((e) => e.$2), active.map((r) => r.entryKey));

    final all = await store.all();
    expect(all, hasLength(5));
    expect(all.map((r) => r.entryKey).toSet(), {'k1', 'k2', 'k3', 'k4', 'k5'});
  });

  group('decodeTarget(T4 收件箱行点击直达的列解码)', () {
    test('0 → AccountTarget(accountId);1 → DebtTarget(debtId)', () {
      final acc = decodeTarget(kInboxTargetKindAccount, 'a1');
      expect(acc, isA<AccountTarget>());
      expect((acc as AccountTarget).accountId, 'a1');

      final debt = decodeTarget(kInboxTargetKindDebt, 'd1');
      expect(debt, isA<DebtTarget>());
      expect((debt as DebtTarget).debtId, 'd1');
    });

    test('未知 kind 抛 ArgumentError 且携带原值(防御钉死,不静默兜底)', () {
      expect(() => decodeTarget(7, 'x'), throwsArgumentError);
      expect(() => decodeTarget(-1, 'x'), throwsArgumentError);
      Object? captured;
      try {
        decodeTarget(7, 'x');
      } on ArgumentError catch (e) {
        captured = e;
      }
      captured as ArgumentError;
      expect(captured.invalidValue, 7, reason: '错误信息须携带未知 kind 原值');
      expect(captured.name, 'targetKind');
    });

    test('与 _encodeTarget(upsertActive 写入)往返:行解码还原目标', () async {
      await store.upsertActive(
        entryKey: 'cc:a1:2026-09',
        title: '招行卡',
        amountCents: 5000,
        dueDate: DateTime(2026, 9, 25),
        target: const AccountTarget('a1'),
      );
      await store.upsertActive(
        entryKey: 'd1-e0',
        title: '房贷',
        amountCents: 100000,
        dueDate: DateTime(2026, 9, 30),
        target: const DebtTarget('d1'),
      );
      for (final row in await store.all()) {
        final target = decodeTarget(row.targetKind, row.targetId);
        switch (target) {
          case AccountTarget(:final accountId):
            expect(row.entryKey, contains(accountId));
          case DebtTarget(:final debtId):
            expect(debtId, 'd1');
        }
      }
    });
  });

  test('lastSeen 读写往返:未看过 null;写读 epochMs 精度;覆盖更新', () async {
    expect(await store.readLastSeen(), isNull);
    final t = DateTime(2026, 9, 23, 14, 30, 5, 123);
    await store.writeLastSeen(t);
    expect((await store.readLastSeen())!.millisecondsSinceEpoch,
        t.millisecondsSinceEpoch);
    final t2 = DateTime(2026, 9, 24, 9);
    await store.writeLastSeen(t2); // 每次打开收件箱覆盖
    expect((await store.readLastSeen())!.millisecondsSinceEpoch,
        t2.millisecondsSinceEpoch);
  });
}
