// T2(F43 R16 sprint-1)—— conformance 门(ADR-2 语义一致性护栏,spec NFR):
//
// 同一 drift 内存库种子(真实写路径落库),报告侧收支聚合(经 adapter
// LedgerEntryRow + CashExpenseBasis + income credit 单边镜像语义)对照
// TransactionLocalDataSource.summary(server CASE 语义镜像):income/expense
// 总额与分类构成**逐项相等**,防两套聚合漂移。
//
// 种子覆盖(任务书钉死三要素):
// - 多 expense 科目(餐饮/交通两个 type-5 账户);
// - 贷方分录(08-20 退款:借现金/贷 expense —— debit 单边口径下两侧路径
//   都不冲抵当期支出,应相等);
// - 跨期分录(07-31 支出、09-01 收入 —— 期外不进两侧任何一边)。
// 总额同时钉手算字面量(独立 oracle,防两实现一起漂移)。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/report/data/report_ledger_store_impl.dart';
import 'package:yucai_client/report/domain/expense_basis.dart';
import 'package:yucai_client/report/domain/report_assembly_service.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

void main() {
  late db.AppDatabase database;
  late AccountLocalDataSource accountsDs;
  late TransactionLocalDataSource txnsDs;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    accountsDs = AccountLocalDataSource(database);
    txnsDs = TransactionLocalDataSource(
      database,
      BalanceLocalUpdater(database),
    );
  });

  tearDown(() => database.close());

  Future<Account> createAccount(
    String name,
    AccountType type,
    AccountCategory category, {
    int initialBalanceCents = 0,
  }) => accountsDs.create(
    CreateAccountParams(
      name: name,
      accountType: type,
      category: category,
      currencyCode: 'CNY',
      initialBalanceCents: initialBalanceCents,
      ownership: Ownership.personal,
    ),
  );

  test('报告侧收支聚合 ≡ TransactionLocalDataSource.summary(逐项相等)', () async {
    // —— 种子 ——(金额单位 cents,全部手算可复核)
    final cash1 = await createAccount(
      '现金1',
      AccountType.asset,
      AccountCategory.savings,
      initialBalanceCents: 1000000,
    );
    final cash2 = await createAccount(
      '现金2',
      AccountType.asset,
      AccountCategory.savings,
      initialBalanceCents: 500000,
    );
    final food = await createAccount(
      '餐饮',
      AccountType.expense,
      AccountCategory.otherAsset,
    );
    final transport = await createAccount(
      '交通',
      AccountType.expense,
      AccountCategory.otherAsset,
    );
    final salary = await createAccount(
      '工资',
      AccountType.income,
      AccountCategory.otherAsset,
    );
    final bonus = await createAccount(
      '奖金',
      AccountType.income,
      AccountCategory.otherAsset,
    );
    final card = await createAccount(
      '信用卡',
      AccountType.liability,
      AccountCategory.creditCard,
    );

    // 期内(2026-08):
    await txnsDs.recordIncome(
      RecordIncomeParams(
        transactionDate: DateTime(2026, 8, 1),
        assetAccountId: cash1.id,
        incomeAccountId: salary.id,
        amountCents: 300000,
      ),
    );
    await txnsDs.recordIncome(
      RecordIncomeParams(
        transactionDate: DateTime(2026, 8, 3),
        assetAccountId: cash2.id,
        incomeAccountId: bonus.id,
        amountCents: 50000,
      ),
    );
    await txnsDs.recordExpense(
      RecordExpenseParams(
        transactionDate: DateTime(2026, 8, 5),
        expenseAccountId: food.id,
        assetAccountId: cash1.id,
        amountCents: 12345,
      ),
    );
    await txnsDs.recordExpense(
      RecordExpenseParams(
        transactionDate: DateTime(2026, 8, 8),
        expenseAccountId: transport.id,
        assetAccountId: cash1.id,
        amountCents: 2500,
      ),
    );
    // 信用卡刷卡(不涉现金):expense 照计(debit 单边)。
    await txnsDs.recordExpense(
      RecordExpenseParams(
        transactionDate: DateTime(2026, 8, 10),
        expenseAccountId: food.id,
        assetAccountId: card.id,
        amountCents: 8888,
      ),
    );
    // 退款(贷方分录):借现金 / 贷餐饮 —— debit 单边口径不冲抵支出。
    await txnsDs.recordTransaction(
      RecordTransactionParams(
        transactionDate: DateTime(2026, 8, 20),
        entries: [
          TransactionEntry(
            accountId: cash1.id,
            debitCents: 200,
            creditCents: 0,
          ),
          TransactionEntry(accountId: food.id, debitCents: 0, creditCents: 200),
        ],
      ),
    );
    // 现金内部划转(资产↔资产):两侧路径都不产收支。
    await txnsDs.recordTransfer(
      RecordTransferParams(
        transactionDate: DateTime(2026, 8, 25),
        fromAccountId: cash1.id,
        toAccountId: cash2.id,
        amountCents: 100000,
      ),
    );
    // 期外:07-31 支出、09-01 收入,不进任何一边。
    await txnsDs.recordExpense(
      RecordExpenseParams(
        transactionDate: DateTime(2026, 7, 31),
        expenseAccountId: food.id,
        assetAccountId: cash1.id,
        amountCents: 9999,
      ),
    );
    await txnsDs.recordIncome(
      RecordIncomeParams(
        transactionDate: DateTime(2026, 9, 1),
        assetAccountId: cash1.id,
        incomeAccountId: salary.id,
        amountCents: 77777,
      ),
    );

    // —— 报告侧(adapter 行 VO + domain 聚合)——
    final store = ReportLedgerStoreImpl(database);
    final period = ReportPeriod.monthly(2026, 8);
    final rows = await store.entries();

    // income:经 ReportAssemblyService 生产聚合(T2 遗留#4 收编:income
    // 科目 credit 单边,镜像 summary 的「income accounts: credit side
    // counts」语义)。
    final reportIncome = ReportAssemblyService.totalIncome(rows, period);
    final incomeByAccount = {
      for (final c in ReportAssemblyService.incomeByCategory(rows, period))
        c.category: c.amountCents,
    };

    // expense:经 CashExpenseBasis(生产代码,FR-7 现金口径)。
    const basis = CashExpenseBasis();
    final reportExpense = basis.totalExpense(rows, period);
    final expenseRows = basis.expenseByCategory(rows, period);
    final expenseByAccount = {
      for (final c in expenseRows) c.category: c.amountCents,
    };

    // —— 对照侧(legacy DS,server CASE 语义镜像)——
    final s = await txnsDs.summary(2026, 8);
    final summaryByAccount = <String, int>{};
    for (final day in s.byDay) {
      for (final c in day.byCategory) {
        summaryByAccount[c.categoryId] =
            (summaryByAccount[c.categoryId] ?? 0) + c.amountCents;
      }
    }
    final summaryIncomeByAccount = {
      for (final e in summaryByAccount.entries)
        if (e.key == salary.id || e.key == bonus.id) e.key: e.value,
    };
    final summaryExpenseByAccount = {
      for (final e in summaryByAccount.entries)
        if (e.key == food.id || e.key == transport.id) e.key: e.value,
    };

    // —— 总额逐项相等 + 手算字面量 ——
    // income = 300,000 + 50,000(期外 77,777 不进;退款不涉收入)。
    expect(reportIncome, s.incomeCents);
    expect(s.incomeCents, 350000);
    // expense(debit 单边)= 餐饮 12,345 + 8,888(退款 credit 200 不冲抵)
    // + 交通 2,500 = 23,733(期外 9,999 不进)。
    expect(reportExpense, s.expenseCents);
    expect(s.expenseCents, 23733);

    // —— 分类构成逐项相等(income 按科目、expense 按 basis 维度)——
    expect(incomeByAccount, summaryIncomeByAccount);
    expect(incomeByAccount, {salary.id: 300000, bonus.id: 50000});
    expect(expenseByAccount, summaryExpenseByAccount);
    expect(expenseByAccount, {
      food.id: 12345 + 8888, // 21,233:退款不冲抵
      transport.id: 2500,
    });
  });
}
