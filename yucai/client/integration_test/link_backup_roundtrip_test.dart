/// F6 FR-10 备份归档往返 E2E(管道链路,真实本地数据源)。
///
/// 链路:8 类实体夹具(账户/交易/债务含期次/预算/目标/标签×2/模板/持仓+标的)
/// → LocalSnapshotExporter.exportAll()(JSON envelope)→ 快照记数与关键字段
/// → 追加「标记」实体(不在快照内,证清库)→ ArchiveCodec.encrypt/decrypt
/// (照 settings_page.dart 实际调用链)→ ArchiveImporter.importAll()(读代码
/// 确认:单个 drift 事务内**全量覆盖** —— 先 purge 依赖方优先(14 次 deleteAll
/// 覆盖 15 张契约表,deleteAllLinks 一并清 goal_account_links 与
/// goal_debt_links 两张),再按 account-first 顺序回插;「清库」即此内建
/// wipe,无需另行删库文件)
/// → 逐类:数量一致 + 抽关键字段一致(id/金额/名称/日期)。
///
/// 契约现状(照实断言,非缺陷定性):
/// - TransactionTags 连接表 local-only 不入备份契约 → 导入后标签关联不保全
///   (getTransactionTags 为空);tags 本体两行照常恢复。
/// - Securities / HoldingLots 是契约外本地表:importer 既不 purge 也不回插,
///   原样保留(标的名/行情与 FIFO lots 不随导入丢失)。
/// - 所有行的 updatedAt 在导入时重打时间戳 → 字段比对避开 updatedAt。
///
/// **清库测试置于文件末位(最后一个 testWidgets,ADR-5/风险表)**:
/// importAll 是破坏性全量覆盖,末位隔离避免波及同文件其他链。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/link_backup_roundtrip_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/backup/data/archive_codec.dart';
import 'package:yucai_client/backup/data/archive_importer.dart';
import 'package:yucai_client/backup/data/local_snapshot_exporter.dart';
import 'package:yucai_client/budget/data/budget_local_ds.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart' hide TransactionEntry;
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/goal/data/goal_local_ds.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/tag/data/tag_repository_impl.dart';
import 'package:yucai_client/template/data/template_local_ds.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AccountLocalDataSource accounts;
  late TransactionLocalDataSource txns;
  late HoldingLocalDataSource holdings;
  late TagLocalDataSource tags;

  late String fundsId; // 备链资金(CNY 储蓄,初始 50,000.00)
  late String investId; // 备链投资(asset investment,买入的持仓账户)
  late String diningId; // 备链餐饮(expense,预算项/支出腿)
  late String recvId; // 备链应收(borrowedOut 债权账户)
  late String taggedTxnId; // 备链支出(挂 1 标签,验 junction 不保全)
  late String debtId; // 备链好友借出(1,200,000 / 3 期)
  late String goalId; // 备链旅行(挂资金账户)
  late String securityId; // 备链指数基金(ETF 标的)

  // ---- 快照(备链① 采集,备链② 逐类比对;updatedAt 导入重打,不比对) ----
  late Uint8List envelope; // 导出的 envelope JSON 字节(codec 输入)
  late int snapAccounts, snapTxns, snapEntries, snapDebts, snapSchedule,
      snapBudgets, snapBudgetItems, snapGoals, snapTags, snapTemplates,
      snapHoldings, snapHoldingTxns, snapLots;
  late DateTime snapTaggedDate; // 挂标签交易的交易日(往返后瞬间相等)
  late DateTime snapTemplateNext; // 模板 nextDate(往返后瞬间相等)

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子(照 link_receivable_collect_test.dart)。
    await resetTestDb();
    db = getIt<AppDatabase>();
    accounts = AccountLocalDataSource(db);
    txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    holdings = HoldingLocalDataSource(db, txns);
    tags = TagLocalDataSource(db);

    // ---- 自包含夹具(备链* 前缀,与演示数据零耦合;8 类各 ≥1,账户 ≥2) ----
    fundsId = await fundsAccount('备链资金', 5000000); // 50,000.00
    final invest = await accounts.create(const CreateAccountParams(
      name: '备链投资',
      accountType: AccountType.asset,
      category: AccountCategory.investment,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    investId = invest.id;
    final dining = await accounts.create(const CreateAccountParams(
      name: '备链餐饮',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    diningId = dining.id;
    final recv = await accounts.create(const CreateAccountParams(
      name: '备链应收',
      accountType: AccountType.asset,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    recvId = recv.id;

    // 交易:9 月 10 日支出 660.00(debit 餐饮 / credit 资金)—— 挂标签那笔。
    taggedTxnId = await txns
        .recordTransaction(RecordTransactionParams(
          transactionDate: DateTime.utc(2026, 9, 10),
          description: '备链支出',
          entries: [
            TransactionEntry(
                accountId: diningId, debitCents: 66000, creditCents: 0),
            TransactionEntry(
                accountId: fundsId, debitCents: 0, creditCents: 66000),
          ],
        ))
        .then((x) => x.id);

    // 债务(含期次):借出 12,000.00 / 3 个月 / 3%,资金出、应收入(双写)。
    final debt = await DebtLocalDataSource(db, txns).create(
      accountId: recvId,
      counterparty: '备链好友',
      interestRate: 0.03,
      amortizationIndex: 0, // 等额本息 → 3 期
      startDate: DateTime.utc(2026, 9, 1),
      dueDate: DateTime.utc(2026, 12, 1),
      totalPrincipalCents: 1200000,
      type: DebtType.borrowedOut,
      sourceAccountId: fundsId,
    );
    debtId = debt.id;

    // 预算:2026-09 餐饮 5,000.00。
    await BudgetLocalDataSource(db).createBudget(
      name: '备链九月伙食',
      month: '2026-09',
      currencyCode: 'CNY',
      items: [
        (accountId: diningId, plannedAmountCents: 500000, notes: null),
      ],
    );

    // 目标:80,000.00,挂资金账户(linkedAccountIDs 数组往返)。
    final goal = await GoalLocalDataSource(db, holdings).createGoal(
      name: '备链旅行基金',
      type: GoalType.savings,
      targetAmountCents: 8000000,
      linkedAccountIds: [fundsId],
    );
    goalId = goal.id;

    // 标签 ×2;「备链标签一」挂到备链支出(junction 现状断言用)。
    final tagA = await tags.create(name: '备链标签一', color: '#2E7D32');
    await tags.create(name: '备链标签二', color: '#1565C0');
    await tags.addTagToTransaction(tagId: tagA.id, transactionId: taggedTxnId);

    // 模板:月度支出 88.00(billingDay 15)。
    await TemplateLocalDataSource(db, txns).create(
      name: '备链订阅',
      amountCents: 8800,
      direction: TemplateDirection.expense,
      sourceAccountId: fundsId,
      cycle: TemplateCycle.monthly,
      billingDay: 15,
      startDate: '2026-08-15',
      autoRecord: false,
    );

    // 持仓 + 标的:ETF 50 份 @200.00 元,fee 10.00 元(fee 不走现金腿)。
    final sec = await holdings.createSecurity(
      symbol: 'F6BAK01',
      name: '备链指数基金',
      type: SecurityType.etf,
      exchange: 'CN',
      currency: 'CNY',
    );
    securityId = sec.id;
    await holdings.buy(
      accountId: investId,
      securityId: securityId,
      fromAccountId: fundsId,
      quantity: 50,
      priceCents: 20000,
      feeCents: 1000,
      tradeDate: '2026-09-01',
    );

    // oracle sanity(导出前资金终值;导入按列原样恢复,应回到同一值):
    // 5,000,000 − 66,000(支出)− 1,200,000(借出双写)− 1,000,000(买入
    // 现金腿 = price×qty,fee 不减现金)= 2,734,000 分 = 27,340.00 元。
    expect(await balanceOf(db, fundsId), 2734000,
        reason: '导出前资金终值 oracle(往返后应原样恢复)');
  });

  tearDownAll(deleteTestDb);

  testWidgets('备链①导出:envelope 结构 + 8 类计数快照(只读,不清库)', (t) async {
    envelope = await LocalSnapshotExporter(db).exportAll();

    // envelope 结构(读代码确认:snake_case 顶层 + PascalCase 模块载荷)。
    final env = jsonDecode(utf8.decode(envelope)) as Map<String, dynamic>;
    expect(env['version'], 1, reason: '契约版本 1');
    expect(env['tenant_id'], '00000000-0000-0000-0000-000000000000',
        reason: '本地导出 tenant 为占位零 UUID(server 覆写)');
    final modules = env['modules'] as Map<String, dynamic>;
    expect(modules.keys.toSet(),
        {'account', 'transaction', 'debt', 'budget', 'goal', 'tag', 'template', 'holding'},
        reason: '恰 8 类契约模块');
    for (final k in [
      'account', 'transaction', 'debt', 'budget', 'goal', 'tag', 'template'
    ]) {
      expect((modules[k] as List).isNotEmpty, isTrue, reason: '$k 模块非空');
    }
    // holding 模块:holdings/transactions 兄弟数组(server shape)。
    final holdingModule = modules['holding'] as Map<String, dynamic>;
    expect((holdingModule['holdings'] as List).isNotEmpty, isTrue);
    expect((holdingModule['transactions'] as List).isNotEmpty, isTrue);
    // junction(TransactionTags)结构性缺席:模块键集合已恰为 8 类,无连接表载荷。

    // ---- 计数快照(demo 种子 + 备链夹具全库口径;② 逐类比对) ----
    snapAccounts = (await db.accountDao.getAllAccounts()).length;
    snapTxns = (await db.transactionDao.getAllTransactions()).length;
    snapEntries = (await db.transactionDao.getAllEntries()).length;
    snapDebts = (await db.debtDao.watchAllDebts().first).length;
    snapSchedule = (await db.debtDao.getScheduleByDebt(debtId)).length; // 3 期
    final budgetRows0 = await db.budgetDao.watchAllBudgets().first;
    snapBudgets = budgetRows0.length;
    snapBudgetItems = (await db.budgetDao.getItemsByBudget(
            budgetRows0.firstWhere((b) => b.name == '备链九月伙食').id))
        .length;
    snapGoals = (await db.goalDao.watchAllGoals().first).length;
    snapTags = (await db.tagDao.watchAllTags().first).length;
    snapTemplates = (await db.templateDao.watchAllTemplates().first).length;
    final holdingRows0 = await db.holdingDao.watchAllHoldings().first;
    snapHoldings = holdingRows0.length;
    snapHoldingTxns = (await db.holdingDao.getAllHoldingTransactions()).length;
    snapLots = (await db.derivedDao.getLotsByHolding(
            holdingRows0.firstWhere((h) => h.accountId == investId).id))
        .length;

    // 关键字段快照(往返后瞬间相等;避开导入重打的 updatedAt)。
    snapTaggedDate = (await db.transactionDao.getTransactionById(taggedTxnId))!
        .transactionDate;
    snapTemplateNext = (await db.templateDao.watchAllTemplates().first)
        .firstWhere((r) => r.name == '备链订阅')
        .nextDate;

    // 夹具计数下限(≥1 口径;demo 另有存量)。
    expect(snapSchedule, 3, reason: '债务夹具 3 期');
    expect(snapAccounts, greaterThanOrEqualTo(6 + 4), reason: 'demo 6 + 备链 4');
    expect(snapTags, greaterThanOrEqualTo(4), reason: 'demo 2 + 备链 2');
  });

  // 文件内置末位(ADR-5):importAll 全量覆盖(内建清库)是破坏性操作,
  // 本测试之后文件即结束,不再有依赖库内既有数据的断言。
  testWidgets('备链②清库导入(末位):标记实体消失 + 逐类数量/关键字段一致', (t) async {
    // 导出后追加「标记」账户 + 交易(不在 envelope 内 → 全量覆盖后应消失)。
    await accounts.create(const CreateAccountParams(
      name: '备链导入后消失',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 700,
      ownership: Ownership.personal,
    ));
    await txns.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime.utc(2026, 9, 12),
      description: '备链标记',
      entries: [
        TransactionEntry(accountId: diningId, debitCents: 1000, creditCents: 0),
        TransactionEntry(accountId: fundsId, debitCents: 0, creditCents: 1000),
      ],
    ));
    expect((await db.accountDao.getAllAccounts()).length, snapAccounts + 1,
        reason: 'sanity:标记已入库');

    // 照实际调用链(settings_page.dart:341/380):encrypt → decrypt → importAll。
    const password = 'f6-e2e-pass';
    final sealed = ArchiveCodec.encrypt(envelope, password);
    final restored = ArchiveCodec.decrypt(sealed, password);
    expect(utf8.decode(restored), utf8.decode(envelope),
        reason: 'codec(scrypt+AES-GCM+gzip)往返无损');

    await ArchiveImporter(db).importAll(restored);

    // ---- 标记消失(证全量覆盖,非追加) ----
    final accountsAfter = await db.accountDao.getAllAccounts();
    expect(accountsAfter.length, snapAccounts, reason: '账户数回到快照');
    expect(accountsAfter.where((a) => a.name == '备链导入后消失'), isEmpty,
        reason: '标记账户被清库 wipe');
    expect((await db.transactionDao.getAllTransactions()).length, snapTxns,
        reason: '交易数回到快照(标记交易被清)');

    // ---- 账户:关键字段(id/名称/币种/金额列) ----
    final fundsRow = accountsAfter.firstWhere((a) => a.id == fundsId);
    expect(
        (fundsRow.name, fundsRow.currencyCode, fundsRow.currentBalanceCents),
        ('备链资金', 'CNY', 2734000),
        reason: '资金行:余额按导出列原样恢复(标记交易不影响)');
    expect(await balanceOf(db, fundsId), 2734000,
        reason: 'raw drift 复核:资金余额 = 导出快照值');

    // ---- 交易:头 + entries(id/日期/金额) ----
    expect((await db.transactionDao.getAllEntries()).length, snapEntries);
    final tagged =
        (await db.transactionDao.getTransactionById(taggedTxnId))!;
    expect(tagged.description, '备链支出');
    expect(tagged.transactionDate, snapTaggedDate, reason: '交易日往返相等');
    final taggedEntries =
        await db.transactionDao.watchEntriesByTransaction(taggedTxnId).first;
    expect(taggedEntries, hasLength(2));
    expect(
        taggedEntries
            .firstWhere((e) => e.accountId == diningId)
            .debitCents,
        66000);
    expect(
        taggedEntries.firstWhere((e) => e.accountId == fundsId).creditCents,
        66000);

    // ---- 债务:头 + 期次(对方/本金/利率/期数) ----
    final debtsAfter = await db.debtDao.watchAllDebts().first;
    expect(debtsAfter.length, snapDebts);
    final debtRow = debtsAfter.firstWhere((d) => d.id == debtId);
    expect((debtRow.counterparty, debtRow.totalPrincipalCents,
        debtRow.interestRate),
        ('备链好友', 1200000, 0.03));
    final schedule = await db.debtDao.getScheduleByDebt(debtId);
    expect(schedule.length, snapSchedule, reason: '3 期全恢复');
    expect(schedule.every((s) => !s.paid), isTrue, reason: '期次未还位保留');

    // ---- 预算:头 + items(月份/计划额) ----
    final budgetsAfter = await db.budgetDao.watchAllBudgets().first;
    expect(budgetsAfter.length, snapBudgets);
    final budgetRow = budgetsAfter.firstWhere((b) => b.name == '备链九月伙食');
    expect((budgetRow.month, budgetRow.totalAmountCents), ('2026-09', 500000));
    final items = await db.budgetDao.getItemsByBudget(budgetRow.id);
    expect(items.length, snapBudgetItems);
    expect(
        (items.single.accountId, items.single.plannedAmountCents),
        (diningId, 500000));

    // ---- 目标:头 + linkedAccountIDs 数组还原为 link 表 ----
    final goalsAfter = await db.goalDao.watchAllGoals().first;
    expect(goalsAfter.length, snapGoals);
    final goalRow = goalsAfter.firstWhere((g) => g.id == goalId);
    expect((goalRow.name, goalRow.targetAmountCents), ('备链旅行基金', 8000000));
    final (linkedAccounts, linkedDebts) = await db.goalDao.linksFor(goalId);
    expect(linkedAccounts, [fundsId], reason: 'LinkedAccountIDs 数组往返');
    expect(linkedDebts, isEmpty);

    // ---- 标签:本体恢复;junction 不保全(契约现状,照实断言) ----
    final tagsAfter = await db.tagDao.watchAllTags().first;
    expect(tagsAfter.length, snapTags);
    final tagNames =
        tagsAfter.map((x) => (x.name, x.color)).toSet();
    expect(tagNames, containsAll([('备链标签一', '#2E7D32'), ('备链标签二', '#1565C0')]));
    // TransactionTags 连接表 local-only 不入契约:importer purge 后不回插
    // → 交易上的标签关联丢失。这是契约现状非缺陷(简报 ADR-5 注记)。
    expect(await tags.getTransactionTags(taggedTxnId), isEmpty,
        reason: '标签关联(junction)不保全 —— 契约现状,照实断言');

    // ---- 模板(名称/金额/nextDate) ----
    final templatesAfter = await db.templateDao.watchAllTemplates().first;
    expect(templatesAfter.length, snapTemplates);
    final tplRow = templatesAfter.firstWhere((r) => r.name == '备链订阅');
    expect((tplRow.amountCents, tplRow.billingDay), (8800, 15));
    expect(tplRow.nextDate, snapTemplateNext, reason: 'nextDate 往返相等');

    // ---- 持仓:头 + 台账(数量/均价/方向/金额/费用) ----
    final holdingsAfter = await db.holdingDao.watchAllHoldings().first;
    expect(holdingsAfter.length, snapHoldings);
    final holdingRow = holdingsAfter.firstWhere((h) => h.accountId == investId);
    expect((holdingRow.securityId, holdingRow.quantity, holdingRow.avgCostCents),
        (securityId, 50.0, 20020),
        reason: '50 份,均价 = (1,000,000+1,000)/50 = 20,020(fee 资本化)');
    final ledger = await db.holdingDao.getAllHoldingTransactions();
    expect(ledger.length, snapHoldingTxns);
    final tradeRow = ledger.firstWhere((x) => x.securityId == securityId);
    expect(
        (tradeRow.tradeType, tradeRow.amountCents, tradeRow.feeCents),
        (TradeType.buy.index + 1, 1000000, 1000),
        reason: '台账方向买(=1),金额 price×qty,fee 列保留');

    // ---- 契约外本地表照实断言:Securities / HoldingLots 不 purge 不回插 ----
    final secRow = await db.referenceDao.getSecurityById(securityId);
    expect(secRow, isNotNull, reason: '标的行原样保留(本地引用表)');
    expect(secRow!.symbol, 'F6BAK01');
    final lotsAfter = await db.derivedDao.getLotsByHolding(holdingRow.id);
    expect(lotsAfter.length, snapLots,
        reason: 'FIFO lots 原样保留(派生表,导入不清不重建)');
  });
}
