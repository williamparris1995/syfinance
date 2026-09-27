// T2(F43 R16 sprint-1)—— ReportLedgerStoreImpl adapter 映射(drift 内存库):
//
// - accounts():Accounts 行 → AccountRow(category 本地 int = AccountCategory
//   index+1 → 枚举名字符串,照 account_local_ds 写入口径;越界/0 = 旧数据
//   缺失 → null);含 archived 不过滤(port 契约:汇编侧自行过滤)。
// - entries():TransactionEntries × Transactions(date)× Accounts(denorm
//   accountType/category)→ LedgerEntryRow,按日期升序。
// 种子走真实写路径(AccountLocalDataSource / TransactionLocalDataSource),
// 期望值全部手算。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/budget/data/budget_local_ds.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/report/data/report_ledger_store_impl.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

void main() {
  late db.AppDatabase database;
  late AccountLocalDataSource accountsDs;
  late TransactionLocalDataSource txnsDs;
  late ReportLedgerStoreImpl store;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    accountsDs = AccountLocalDataSource(database);
    txnsDs = TransactionLocalDataSource(
      database,
      BalanceLocalUpdater(database),
    );
    store = ReportLedgerStoreImpl(database);
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

  test('accounts():type/category 枚举名/期初余额/币种逐字段映射,archived 不剔除', () async {
    final cash = await createAccount(
      '现金',
      AccountType.asset,
      AccountCategory.savings,
      initialBalanceCents: 500000,
    );
    final invest = await createAccount(
      '投资',
      AccountType.asset,
      AccountCategory.investment,
    );
    final expense = await createAccount(
      '餐饮',
      AccountType.expense,
      AccountCategory.otherAsset,
    );
    final income = await createAccount(
      '工资',
      AccountType.income,
      AccountCategory.savings,
    );
    // archived 账户也在全量输出内(port:含 archived,汇编侧自行过滤)。
    await accountsDs.update(
      UpdateAccountParams(
        id: invest.id,
        version: 1,
        status: AccountStatus.archived,
      ),
    );

    final rows = await store.accounts();
    expect(rows, hasLength(4));
    expect(
      rows.map((a) => a.id),
      containsAll([cash.id, invest.id, expense.id, income.id]),
    );

    final cashRow = rows.firstWhere((a) => a.id == cash.id);
    expect(cashRow.type, 1); // contract int:1 asset
    expect(cashRow.category, 'savings'); // 本地 int 1 → 枚举名
    expect(cashRow.initialBalanceCents, 500000);
    expect(cashRow.currencyCode, 'CNY');

    final investRow = rows.firstWhere((a) => a.id == invest.id);
    expect(investRow.type, 1);
    expect(investRow.category, 'investment'); // 本地 int 3 → 枚举名

    final expenseRow = rows.firstWhere((a) => a.id == expense.id);
    expect(expenseRow.type, 5); // 5 expense
    expect(expenseRow.category, 'otherAsset'); // 本地 int 8 → 枚举名

    final incomeRow = rows.firstWhere((a) => a.id == income.id);
    expect(incomeRow.type, 4); // 4 income
  });

  test('accounts():旧数据 category 越界 int(0/超上限)→ null', () async {
    // 直接落 DAO 行模拟备份导入/旧库(category=0,枚举 index+1 值域之外)。
    await database.accountDao.insertAccount(
      db.AccountsCompanion.insert(
        id: 'legacy-0',
        name: '旧账户A',
        accountType: 1,
        category: 0,
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
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await database.accountDao.insertAccount(
      db.AccountsCompanion.insert(
        id: 'legacy-11',
        name: '旧账户B',
        accountType: 1,
        category: 11, // 超上限(AccountCategory 共 10 项)
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
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    final rows = await store.accounts();
    expect(rows.firstWhere((a) => a.id == 'legacy-0').category, isNull);
    expect(rows.firstWhere((a) => a.id == 'legacy-11').category, isNull);
  });

  test('entries():date 取头行、denorm 类型/账类、借贷金额、按日期升序、txId 配对', () async {
    final cash = await createAccount(
      '现金',
      AccountType.asset,
      AccountCategory.savings,
      initialBalanceCents: 1000000,
    );
    final expense = await createAccount(
      '餐饮',
      AccountType.expense,
      AccountCategory.otherAsset,
    );
    final income = await createAccount(
      '工资',
      AccountType.income,
      AccountCategory.savings,
    );

    // 08-15 支出 12,345(借 餐饮 / 贷 现金);08-02 收入 250,000(借 现金 / 贷 工资)。
    // 插入顺序故意倒挂,钉死输出按日期升序而非插入序。
    await txnsDs.recordExpense(
      RecordExpenseParams(
        transactionDate: DateTime(2026, 8, 15),
        expenseAccountId: expense.id,
        assetAccountId: cash.id,
        amountCents: 12345,
        description: '午饭',
      ),
    );
    await txnsDs.recordIncome(
      RecordIncomeParams(
        transactionDate: DateTime(2026, 8, 2),
        assetAccountId: cash.id,
        incomeAccountId: income.id,
        amountCents: 250000,
        description: '八月工资',
      ),
    );

    final entries = await store.entries();
    expect(entries, hasLength(4));

    // 升序:08-02 两腿在前,08-15 两腿在后。
    final dayOf = entries
        .map((e) => (e.date.year, e.date.month, e.date.day))
        .toList();
    expect(dayOf, [(2026, 8, 2), (2026, 8, 2), (2026, 8, 15), (2026, 8, 15)]);

    // 收入交易(08-02):借现金 / 贷工资,denorm 类型/账类正确。
    final incomeLegs = entries.where((e) => e.date.day == 2).toList();
    final wageLeg = incomeLegs.firstWhere((e) => e.accountId == income.id);
    expect(wageLeg.accountType, 4);
    expect(wageLeg.category, 'savings');
    expect(wageLeg.creditCents, 250000);
    expect(wageLeg.debitCents, 0);
    final cashDebitLeg = incomeLegs.firstWhere((e) => e.accountId == cash.id);
    expect(cashDebitLeg.debitCents, 250000);
    expect(cashDebitLeg.creditCents, 0);
    expect(cashDebitLeg.accountType, 1);
    expect(cashDebitLeg.category, 'savings');
    // 同一交易的两腿共享 transactionId(对手配对键)。
    expect(wageLeg.transactionId, cashDebitLeg.transactionId);

    // 支出交易(08-15):借餐饮 / 贷现金。
    final expenseLegs = entries.where((e) => e.date.day == 15).toList();
    final mealLeg = expenseLegs.firstWhere((e) => e.accountId == expense.id);
    expect(mealLeg.accountType, 5);
    expect(mealLeg.category, 'otherAsset');
    expect(mealLeg.debitCents, 12345);
    expect(mealLeg.creditCents, 0);
    final cashCreditLeg = expenseLegs.firstWhere((e) => e.accountId == cash.id);
    expect(cashCreditLeg.creditCents, 12345);
    expect(cashCreditLeg.debitCents, 0);
    // 两笔交易 id 互不相同。
    expect(mealLeg.transactionId, isNot(wageLeg.transactionId));
  });

  // T2-R1(评审 Important):镜像形态行(bound_mirror 写入口径 =
  // mirror_mappers `_utc`,drift 落 Z 后缀 UTC 文本)date 必须 **raw 直通**
  // —— 对齐 transaction 模块唯一消费者 _toEntity(transaction_local_ds
  // L531)的口径;不做 toLocal(其仅变换公历表示,UTC 以西设备会把镜像行
  // 的日历日回退一天,污染按日历日分桶的下游)。
  test('entries():镜像 Z 行 date raw 直通(UTC 形态原样出,不做 toLocal)', () async {
    final cash = await createAccount('现金', AccountType.asset,
        AccountCategory.savings,
        initialBalanceCents: 1000000);
    final salary = await createAccount(
        '工资', AccountType.income, AccountCategory.otherAsset);
    final mirrorDate = DateTime.utc(2026, 8, 15, 12); // Z 文本镜像形态
    await database.transactionDao.insertTransaction(db.TransactionsCompanion.insert(
      id: 'mirror-t1',
      transactionDate: mirrorDate,
      description: 'mirror',
      version: 1,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ));
    for (final (j, acc) in [cash.id, salary.id].indexed) {
      await database.transactionDao.insertEntry(
          db.TransactionEntriesCompanion.insert(
        id: 'mirror-e-$j',
        transactionId: 'mirror-t1',
        accountId: acc,
        chartOfAccountCode: '',
        debitCents: j == 0 ? 424242 : 0,
        creditCents: j == 0 ? 0 : 424242,
        note: '',
      ));
    }

    final entries = await store.entries();
    expect(entries, hasLength(2));
    for (final e in entries) {
      // raw 直通:UTC 形态原样出(瞬间等值 + isUtc 保持)。
      expect(e.date.isUtc, isTrue, reason: '镜像 Z 行须 raw 直通,不做 toLocal');
      expect(e.date.isAtSameMomentAs(mirrorDate), isTrue);
    }
  });

  // ---- T4 追加:budgetRows / rateToCny(port 扩方法)----

  test('budgetRows():头+item+关联账户 id/账类/名称扁平行映射,不含 item 的头不出行', () async {
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
    final budgetsDs = BudgetLocalDataSource(database);
    final view = await budgetsDs.createBudget(
      name: '八月预算',
      month: '2026-08',
      currencyCode: 'CNY',
      items: [
        (accountId: food.id, plannedAmountCents: 50000, notes: null),
        (accountId: transport.id, plannedAmountCents: 20000, notes: '通勤'),
      ],
    );
    // 转「无 item 的头」(创建单项后整项删除)→ 不产出任何行。
    final empty = await budgetsDs.createBudget(
      name: '空预算',
      month: '2026-09',
      currencyCode: 'CNY',
      items: [
        (accountId: food.id, plannedAmountCents: 1000, notes: null),
      ],
    );
    await budgetsDs.removeItem(
      budgetId: empty.id,
      itemId: (await budgetsDs.getBudget(empty.id)).items.first.id,
    );
    expect((await budgetsDs.getBudget(empty.id)).items, isEmpty);

    final rows = await store.budgetRows();
    expect(rows, hasLength(2)); // 空 09 头零 item 不出行

    final foodRow = rows.firstWhere((r) => r.accountId == food.id);
    expect(foodRow.budgetId, view.id);
    expect(foodRow.month, '2026-08');
    expect(foodRow.itemId, isNotEmpty);
    expect(foodRow.accountCategory, 'otherAsset');
    expect(foodRow.accountName, '餐饮');
    expect(foodRow.plannedCents, 50000);

    final transportRow = rows.firstWhere((r) => r.accountId == transport.id);
    expect(transportRow.plannedCents, 20000);
    expect(transportRow.accountName, '交通');
    expect(foodRow.itemId, isNot(transportRow.itemId));
  });

  test('rateToCny():该日最近可得历史→现值回退→双缺失双 null', () async {
    final dao = database.referenceDao;
    Future<void> seedRate(String id, DateTime d, double rate) =>
        dao.insertRateHistory(db.RateHistoriesCompanion.insert(
          id: id,
          currencyCode: 'USD',
          rateDate: d,
          exchangeRate: rate,
          createdAt: DateTime(2026, 9, 1),
        ));

    await seedRate('r1', DateTime(2026, 8, 10), 7.1);
    await seedRate('r2', DateTime(2026, 8, 25), 7.2); // 未来于部分查询日
    await dao.insertCurrency(db.CurrenciesCompanion.insert(
      code: 'USD',
      name: '美元',
      symbol: r'$',
      exchangeRate: 7.3,
      isActive: true,
    ));
    await dao.insertCurrency(db.CurrenciesCompanion.insert(
      code: 'EUR',
      name: '欧元',
      symbol: '€',
      exchangeRate: 7.8,
      isActive: true,
    ));

    // 该日最近可得(≤ on 取最近):08-20 查询 → 08-10 行 7.1。
    final aug20 = await store.rateToCny('USD', DateTime(2026, 8, 20));
    expect(aug20.asOfRate, 7.1);
    expect(aug20.currentRate, 7.3);
    // 恰命中历史日:08-25 查询 → 7.2。
    final aug25 = await store.rateToCny('USD', DateTime(2026, 8, 25));
    expect(aug25.asOfRate, 7.2);
    // 历史晚于查询日不计:08-05 查询 → asOf null,现值候选仍在。
    final aug5 = await store.rateToCny('USD', DateTime(2026, 8, 5));
    expect(aug5.asOfRate, isNull);
    expect(aug5.currentRate, 7.3);
    // 无历史币种:仅现值回退候选。
    final eur = await store.rateToCny('EUR', DateTime(2026, 8, 20));
    expect(eur.asOfRate, isNull);
    expect(eur.currentRate, 7.8);
    // 双缺失 → 双 null(domain 按缺失跳过折算并注记)。
    final jpy = await store.rateToCny('JPY', DateTime(2026, 8, 20));
    expect(jpy.asOfRate, isNull);
    expect(jpy.currentRate, isNull);
  });
}
