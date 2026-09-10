// F19-T1(2026-09-11,spec FR-2/design ADR-2):合并前全量标记 DAO —— 8 头表
// 各 markAllPendingForSync()(synced → pending;幂等;返回影响行数)。
// guest 期行 syncState=synced 不在 PendingCollector 通路 —— 绑定合并确认后
// 经此全量标记进入 push 通路。guest 无墓碑(F10 语义:guest 删除不落墓碑),
// 墓碑表无对应方法(注释契约,不另测)。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  // 各表种子:一行 synced + 一行 pending(+ 一行 synced 供「只动 synced」面)。
  Future<void> seed() async {
    final now = DateTime.utc(2026, 9, 11);
    Future<void> row(Future<void> Function(String id, String state) insert) async {
      await insert('r-sync', SyncState.synced);
      await insert('r-sync-2', SyncState.synced);
      await insert('r-pend', SyncState.pending);
    }

    await row((id, s) => db.accountDao.insertAccount(AccountsCompanion.insert(
          id: id,
          name: 'n-$id',
          accountType: 1,
          category: 2,
          currencyCode: 'CNY',
          initialBalanceCents: 0,
          currentBalanceCents: 0,
          ownership: 1,
          icon: '',
          color: '',
          chartCode: '',
          isSystem: false,
          sortOrder: 0,
          institution: '',
          cardNumberTail: '',
          notes: '',
          goldProductType: '',
          status: 1,
          version: 1,
          createdAt: now,
          updatedAt: now,
          syncState: Value(s),
        )));
    await row((id, s) => db.transactionDao.insertTransaction(
            TransactionsCompanion.insert(
          id: id,
          transactionDate: now,
          description: 'd-$id',
          version: 1,
          createdAt: now,
          updatedAt: now,
          syncState: Value(s),
        )));
    await row((id, s) => db.debtDao.insertDebt(DebtsCompanion.insert(
          id: id,
          accountId: 'a1',
          counterparty: 'c',
          interestRate: 1,
          amortizationMethod: 1,
          startDate: now,
          dueDate: now,
          totalPrincipalCents: 100,
          debtType: 1,
          subtype: '',
          contact: '',
          contractRef: '',
          version: 1,
          createdAt: now,
          updatedAt: now,
          syncState: Value(s),
        )));
    await row((id, s) => db.budgetDao.insertBudget(BudgetsCompanion.insert(
          id: id,
          name: 'b-$id',
          month: '2026-09',
          totalAmountCents: 100,
          currencyCode: 'CNY',
          isActive: true,
          version: 1,
          createdAt: now,
          updatedAt: now,
          syncState: Value(s),
        )));
    await row((id, s) => db.goalDao.insertGoal(GoalsCompanion.insert(
          id: id,
          name: 'g-$id',
          goalType: 1,
          targetAmountCents: 100,
          currentAmountCents: 0,
          currencyCode: 'CNY',
          notes: '',
          isCompleted: false,
          version: 1,
          createdAt: now,
          updatedAt: now,
          syncState: Value(s),
        )));
    await row((id, s) => db.holdingDao.insertHolding(HoldingsCompanion.insert(
          id: id,
          accountId: 'a1',
          securityId: 'sec1',
          quantity: 1,
          avgCostCents: 100,
          version: 1,
          createdAt: now,
          updatedAt: now,
          syncState: Value(s),
        )));
    await row((id, s) => db.tagDao.insertTag(TagsCompanion.insert(
          id: id,
          name: 't-$id',
          color: '#000000',
          version: 1,
          createdAt: now,
          updatedAt: now,
          syncState: Value(s),
        )));
    await row((id, s) => db.templateDao.insertTemplate(
            TransactionTemplatesCompanion.insert(
          id: id,
          name: 'tp-$id',
          description: '',
          amountCents: 100,
          direction: 1,
          sourceAccountId: 'a1',
          cycle: 2,
          cycleDays: 0,
          billingDay: 1,
          nextDate: now,
          startDate: now,
          autoRecord: false,
          paused: false,
          category: '',
          version: 1,
          createdAt: now,
          updatedAt: now,
          syncState: Value(s),
        )));
  }

  Future<List<String>> states(Future<List<dynamic>> Function() read) async =>
      [for (final r in await read()) r.syncState as String];

  test('8 头表 markAllPendingForSync:仅 synced→pending,返回影响行数,幂等',
      () async {
    await seed();

    // 各表:2 行 synced 被标记(返回影响行数),pending 行原样。
    expect(await db.accountDao.markAllPendingForSync(), 2);
    expect(await db.transactionDao.markAllPendingForSync(), 2);
    expect(await db.debtDao.markAllPendingForSync(), 2);
    expect(await db.budgetDao.markAllPendingForSync(), 2);
    expect(await db.goalDao.markAllPendingForSync(), 2);
    expect(await db.holdingDao.markAllPendingForSync(), 2);
    expect(await db.tagDao.markAllPendingForSync(), 2);
    expect(await db.templateDao.markAllPendingForSync(), 2);

    // 全表全行 pending(guest 全量进入收集通路)。
    expect(await states(() => db.accountDao.getAllAccounts()),
        everyElement(SyncState.pending));
    expect(
        await states(() async => [
              for (final t in await db.transactionDao.getAllTransactions()) t
            ]),
        everyElement(SyncState.pending));
    expect(await states(() async => [for (final d in await db.debtDao.watchAllDebts().first) d]),
        everyElement(SyncState.pending));
    expect(await states(() async => [for (final b in await db.budgetDao.watchAllBudgets().first) b]),
        everyElement(SyncState.pending));
    expect(await states(() async => [for (final g in await db.goalDao.watchAllGoals().first) g]),
        everyElement(SyncState.pending));
    expect(await states(() async => [for (final h in await db.holdingDao.watchAllHoldings().first) h]),
        everyElement(SyncState.pending));
    expect(await states(() async => [for (final t in await db.tagDao.watchAllTags().first) t]),
        everyElement(SyncState.pending));
    expect(
        await states(
            () async => [for (final t in await db.templateDao.watchAllTemplates().first) t]),
        everyElement(SyncState.pending));

    // 幂等:二次调用无 synced 行可动,返回 0,状态不变。
    expect(await db.accountDao.markAllPendingForSync(), 0);
    expect(await db.transactionDao.markAllPendingForSync(), 0);
    expect(await db.debtDao.markAllPendingForSync(), 0);
    expect(await db.budgetDao.markAllPendingForSync(), 0);
    expect(await db.goalDao.markAllPendingForSync(), 0);
    expect(await db.holdingDao.markAllPendingForSync(), 0);
    expect(await db.tagDao.markAllPendingForSync(), 0);
    expect(await db.templateDao.markAllPendingForSync(), 0);
    expect(await states(() => db.accountDao.getAllAccounts()),
        everyElement(SyncState.pending));
  });

  test('空表 markAllPendingForSync 返回 0(空库直通无影响)', () async {
    expect(await db.accountDao.markAllPendingForSync(), 0);
    expect(await db.transactionDao.markAllPendingForSync(), 0);
    expect(await db.debtDao.markAllPendingForSync(), 0);
    expect(await db.budgetDao.markAllPendingForSync(), 0);
    expect(await db.goalDao.markAllPendingForSync(), 0);
    expect(await db.holdingDao.markAllPendingForSync(), 0);
    expect(await db.tagDao.markAllPendingForSync(), 0);
    expect(await db.templateDao.markAllPendingForSync(), 0);
  });

  // F19-T1 fix round 1:markXSynced OR 守卫分片(sync_state.dart 常量 doc 的
  // SQLite 栈溢出修复)—— 多分片(>50 行)时影响行数正确求和,版本守卫
  // 跨分片不漏行。
  test('markAccountsSynced 120 行(3 分片)→ 返回 120,全行 synced', () async {
    final now = DateTime.utc(2026, 9, 11);
    for (var i = 0; i < 120; i++) {
      await db.accountDao.insertAccount(AccountsCompanion.insert(
        id: 'acc-$i',
        name: 'n-$i',
        accountType: 1,
        category: 2,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: 0,
        ownership: 1,
        icon: '',
        color: '',
        chartCode: '',
        isSystem: false,
        sortOrder: 0,
        institution: '',
        cardNumberTail: '',
        notes: '',
        goldProductType: '',
        status: 1,
        version: 1,
        createdAt: now,
        updatedAt: now,
        syncState: const Value(SyncState.pending),
      ));
    }

    final updated = await db.accountDao.markAccountsSynced(
        {for (var i = 0; i < 120; i++) 'acc-$i': 1});

    expect(updated, 120); // 50+50+20 三分片求和,不重不漏。
    expect(await states(() => db.accountDao.getAllAccounts()),
        everyElement(SyncState.synced));
  });
}
