// T2(F43 R16 sprint-1)—— NFR-1 性能门:典型账本(10,000 条分录)报告
// 汇编全链(读取 adapter 全量行 → 余额回放 → 现金流分类 → 支出口径
// 聚合)wall clock ≤ 2s(阈值按 spec NFR-1 留余量写 2s)。
//
// 种子:6 账户 × 5,000 笔双录交易(=10,000 条分录),日期确定性伪随机
// 分布在 [2025-09-01, 2026-08-28](跨年,期前/期内都有)。直接走 DAO 批量
// 落库(种子路径不计入计时窗口);oracle:期末现金 = 期初 + Σ收入 − Σ支出
// (生成器手算),证明计时链路在算真数据而非空转。
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/report/data/report_ledger_store_impl.dart';
import 'package:yucai_client/report/domain/balance_replay.dart';
import 'package:yucai_client/report/domain/cash_flow_classifier.dart';
import 'package:yucai_client/report/domain/expense_basis.dart';
import 'package:yucai_client/report/domain/report_document.dart';

void main() {
  test('NFR-1:10,000 条分录 回放+分类+basis 全链 ≤ 2s(wall clock)', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    // —— 种子(不计入计时)——
    const initialCash1 = 1000000, initialCash2 = 500000;
    const ids = (
      cash1: 'acc-cash1',
      cash2: 'acc-cash2',
      food: 'acc-food',
      transport: 'acc-transport',
      salary: 'acc-salary',
      bonus: 'acc-bonus',
    );
    final now = DateTime.now().toUtc();
    Future<void> seedAccount(
      String id,
      String name,
      int type,
      int category,
      int initial,
    ) => database.accountDao.insertAccount(
      db.AccountsCompanion.insert(
        id: id,
        name: name,
        accountType: type,
        category: category,
        currencyCode: 'CNY',
        initialBalanceCents: initial,
        currentBalanceCents: initial,
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
      ),
    );
    await seedAccount(ids.cash1, '现金1', 1, 1, initialCash1);
    await seedAccount(ids.cash2, '现金2', 1, 1, initialCash2);
    await seedAccount(ids.food, '餐饮', 5, 8, 0);
    await seedAccount(ids.transport, '交通', 5, 8, 0);
    // 科目账户 category 惯例 = otherAsset(demo_seed 同款):savings 专属
    // 资产账户 —— 分类器按 category=='savings' 严格判现金,科目误挂
    // savings 会被当现金对手方导致勾稽失败(T1 语义,种子须真实)。
    await seedAccount(ids.salary, '工资', 4, 8, 0);
    await seedAccount(ids.bonus, '奖金', 4, 8, 0);

    // 确定性伪随机:日期 2025-09-01..2026-08-28,金额 100..10,000 cents,
    // 类型 ~55% 支出 / ~45% 收入(保证两类路径都有量)。
    final rng = Random(42);
    const txCount = 5000; // × 2 腿 = 10,000 条分录
    var totalIncome = 0, totalExpense = 0;
    await database.transaction(() async {
      for (var i = 0; i < txCount; i++) {
        final date = DateTime(
          2025,
          9,
          1,
        ).add(Duration(days: rng.nextInt(362))); // ≤ 2026-08-28
        final amount = 100 + rng.nextInt(9901);
        final txnId = 't-$i';
        await database.transactionDao.insertTransaction(
          db.TransactionsCompanion.insert(
            id: txnId,
            transactionDate: date,
            description: 'perf-$i',
            version: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final (debitAcc, creditAcc) = rng.nextDouble() < 0.55
            ? (
                i.isEven ? ids.food : ids.transport,
                i.isEven ? ids.cash1 : ids.cash2,
              )
            : (
                i.isEven ? ids.cash1 : ids.cash2,
                i.isEven ? ids.salary : ids.bonus,
              );
        final isExpense = debitAcc == ids.food || debitAcc == ids.transport;
        if (isExpense) {
          totalExpense += amount;
        } else {
          totalIncome += amount;
        }
        for (final (j, acc) in [debitAcc, creditAcc].indexed) {
          final debit = j == 0 ? amount : 0;
          await database.transactionDao.insertEntry(
            db.TransactionEntriesCompanion.insert(
              id: 'e-$i-$j',
              transactionId: txnId,
              accountId: acc,
              chartOfAccountCode: '',
              debitCents: debit,
              creditCents: amount - debit,
              note: '',
            ),
          );
        }
      }
    });

    // —— 计时窗口:读取 + 回放 + 分类 + basis 全链 ——
    final store = ReportLedgerStoreImpl(database);
    final period = ReportPeriod.monthly(2026, 8);
    final sw = Stopwatch()..start();
    final accounts = await store.accounts();
    final entries = await store.entries();
    final balances = BalanceReplay().replay(
      accounts: accounts,
      entries: entries,
      period: period,
    );
    final cashIds = [ids.cash1, ids.cash2];
    final cashStart = cashIds.fold<int>(
      0,
      (s, id) => s + balances[id]!.startCents,
    );
    final cashEnd = cashIds.fold<int>(0, (s, id) => s + balances[id]!.endCents);
    final cashFlow = const CashFlowClassifier().classify(
      entries: entries,
      period: period,
      cashStartCents: cashStart,
      cashEndCents: cashEnd,
    );
    const basis = CashExpenseBasis();
    final expense = basis.totalExpense(entries, period);
    final byCategory = basis.expenseByCategory(entries, period);
    sw.stop();
    // ignore: avoid_print
    print(
      'NFR-1 chain: ${entries.length} entries, '
      '${sw.elapsedMilliseconds}ms (budget 2000ms), '
      'expense=$expense, categories=${byCategory.length}, '
      'netDelta=${cashFlow.netDeltaCents}',
    );

    // —— 门:≤ 2s(spec NFR-1,阈值留余量)——
    expect(sw.elapsedMilliseconds, lessThanOrEqualTo(2000));
    // —— 链路算的是真数据(oracle,防空转)——
    expect(entries.length, 10000);
    expect(cashEnd, initialCash1 + initialCash2 + totalIncome - totalExpense);
  });
}
