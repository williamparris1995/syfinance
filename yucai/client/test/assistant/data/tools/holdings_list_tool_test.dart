// F65-T1 TDD RED → GREEN:holdings_list 只读工具(FR-2,持仓面板口径)。
//
// 真库夹具:内存 drift 库 + referenceDao/holdingDao 直插(证券现价/持仓),
// 经**真实** HoldingRepositoryImpl(guest 路由)供数 —— 工具读的就是持仓
// 面板同一条本地读路径(NFR-1)。口径 = holding 面板:HoldingSummary
// (Σ round(qty×avgCost) 成本 / Σ marketValue 市值 / Σ unrealizedPnl 盈亏,
// derivedInvestFields 同式)+ 每标的 pnlPct = pnl/cost×100(页面同式);
// 期望值由测试**独立手算**(不调用工具实现)。
import 'package:dartz/dartz.dart' as dz;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/assistant/data/tools/holdings_list_tool.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/holding/data/goal_view_ds.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/data/holding_remote_ds.dart';
import 'package:yucai_client/holding/data/holding_repository_impl.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

class _MockRemote extends Mock implements HoldingRemoteDataSource {}

class _MockGoalViewDs extends Mock implements GoalViewDataSource {}

class _MockHoldingRepo extends Mock implements HoldingRepository {}

void main() {
  late db.AppDatabase database;
  late HoldingRepositoryImpl repo;
  late HoldingsListTool tool;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    final tracker = SessionModeTracker()..isGuest = true;
    repo = HoldingRepositoryImpl(
      _MockRemote(),
      HoldingLocalDataSource(
          database, TransactionLocalDataSource(database, BalanceLocalUpdater(database))),
      tracker,
      _MockGoalViewDs(),
    );

    // 账户(holdings.accountId 行存在即可,无 FK 约束)。
    await database.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: 'acc-inv',
      name: '投资账户',
      accountType: 1,
      category: 3,
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
    ));

    Future<void> seedSecurity(
            String id, String symbol, String name, int priceCents) =>
        database.referenceDao.insertSecurity(db.SecuritiesCompanion.insert(
          id: id,
          symbol: symbol,
          name: name,
          securityType: 'stock',
          exchange: '',
          currencyCode: 'CNY',
          currentPriceCents: priceCents,
          createdAt: DateTime.now().toUtc(),
        ));

    await seedSecurity('sec1', '600519', '贵州茅台', 5000);
    await seedSecurity('sec2', '510300', '沪深300ETF', 250);
    await seedSecurity('sec3', 'NO PRICE', '无价证券', 0);

    Future<void> seedHolding(String id, String secId, double qty, int avgCost) =>
        database.holdingDao.insertHolding(db.HoldingsCompanion.insert(
          id: id,
          accountId: 'acc-inv',
          securityId: secId,
          quantity: qty,
          avgCostCents: avgCost,
          version: 1,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ));

    // h1:10×4000 成本 40,000;现价 5,000 → 市值 50,000,浮盈 +10,000(+25%)。
    await seedHolding('h1', 'sec1', 10, 4000);
    // h2:100×300 成本 30,000;现价 250 → 市值 25,000,浮亏 −5,000(−16.67%)。
    await seedHolding('h2', 'sec2', 100, 300);
    // h3:无现价 → 市值回落成本口径 2×1000=2,000,盈亏 0(honest stale)。
    await seedHolding('h3', 'sec3', 2, 1000);

    tool = HoldingsListTool(repo);
  });

  tearDown(() => database.close());

  test('summary mirrors the holdings panel caliber, cent-exact', () async {
    final json = (await tool.execute(const {}) as ToolData).json;
    final summary = (json['summary'] as Map<String, Object?>);
    // 独立手算(面板 HoldingSummary 同式):
    expect(summary['totalCostCents'], 40000 + 30000 + 2000,
        reason: '总成本 = Σ round(qty×avgCost)');
    expect(summary['totalMarketValueCents'], 50000 + 25000 + 2000,
        reason: '总市值 = Σ marketValue');
    expect(summary['totalPnlCents'], 10000 - 5000 + 0, reason: '总浮盈 = Σ pnl');
    expect(summary['totalPnlPct'], closeTo((10000 - 5000) * 100 / 72000, 0.001),
        reason: '总浮盈% = Σpnl/Σcost×100');
    expect(summary['totalCostYuan'], '720.00', reason: '元双口径');
    expect(summary['totalMarketValueYuan'], '770.00');
    expect(summary['totalPnlYuan'], '50.00');
  });

  test('per-holding item fields: name/symbol/qty/cost/mv/pnl/pct dual-caliber',
      () async {
    final json = (await tool.execute(const {}) as ToolData).json;
    final items = (json['holdings'] as List).cast<Map<String, Object?>>();
    expect(items, hasLength(3));

    final h1 = items.singleWhere((h) => h['symbol'] == '600519');
    expect(h1['name'], '贵州茅台');
    expect(h1['quantity'], 10);
    expect(h1['avgCostCents'], 4000);
    expect(h1['costCents'], 40000);
    expect(h1['costYuan'], '400.00');
    expect(h1['marketValueCents'], 50000);
    expect(h1['marketValueYuan'], '500.00');
    expect(h1['unrealizedPnlCents'], 10000);
    expect(h1['unrealizedPnlYuan'], '100.00');
    expect(h1['pnlPct'], closeTo(25.0, 0.001));

    // 无现价证券:市值 = 成本口径回退,盈亏 0。
    final h3 = items.singleWhere((h) => h['symbol'] == 'NO PRICE');
    expect(h3['marketValueCents'], 2000);
    expect(h3['unrealizedPnlCents'], 0);
    expect(h3['pnlPct'], 0.0);
  });

  test('name filter: contains on symbol or name, case-insensitive', () async {
    final bySymbol =
        (await tool.execute({'name': '600519'}) as ToolData).json;
    expect(bySymbol['totalCount'], 1);
    expect((bySymbol['holdings'] as List).single['name'], '贵州茅台');

    final byName = (await tool.execute({'name': 'etf'}) as ToolData).json;
    expect(byName['totalCount'], 1);
    expect((byName['holdings'] as List).single['symbol'], '510300');

    // name 过滤后汇总只覆盖命中集。
    final summary = (byName['summary'] as Map);
    expect(summary['totalCostCents'], 30000);
    expect(summary['totalMarketValueCents'], 25000);
  });

  test('sort by market value desc (DS 基准序同式), pagination lenient',
      () async {
    final json = (await tool.execute(const {}) as ToolData).json;
    final mvs = (json['holdings'] as List)
        .cast<Map<String, Object?>>()
        .map((h) => h['marketValueCents'])
        .toList();
    expect(mvs, [50000, 25000, 2000], reason: '市值降序');

    final p1 = (await tool.execute({'page': 1, 'page_size': 2}) as ToolData).json;
    expect((p1['holdings'] as List), hasLength(2));
    expect(p1['totalCount'], 3);
    expect(p1['hasMore'], isTrue);

    final p2 = (await tool.execute({'page': 2, 'page_size': 2}) as ToolData).json;
    expect((p2['holdings'] as List), hasLength(1));
    expect(p2['hasMore'], isFalse);

    // 越界页:空页但汇总/totalCount 不丢(spec FR-2 场景)。
    final p9 = (await tool.execute({'page': 9}) as ToolData).json;
    expect((p9['holdings'] as List), isEmpty);
    expect(p9['totalCount'], 3);
    expect((p9['summary'] as Map)['totalCostCents'], 72000);

    // lenient:page 0 → 1;page_size 999 → 50。
    final lenient =
        (await tool.execute({'page': 0, 'page_size': 999}) as ToolData).json;
    expect(lenient['page'], 1);
    expect(lenient['pageSize'], 50);
  });

  test('repository failure → ToolError, no throw', () async {
    final failing = _MockHoldingRepo();
    when(() => failing.listHoldings(
            accountId: any(named: 'accountId')))
        .thenAnswer((_) async => const dz.Left(UnexpectedFailure('db down')));
    final result = await HoldingsListTool(failing).execute(const {});
    expect(result, isA<ToolError>());
  });
}
