// F65-T1 TDD RED → GREEN:performance_range 只读工具(FR-2,报告口径)。
// 真库夹具:内存 drift + 真实 HoldingLocalDataSource.buy/sell 落台账
// (F43 既有测试同款 FR-6 oracle 范式,holding_perf_range_passthrough_test
// 同源),经**真实** HoldingRepositoryImpl(guest 路由)取数。工具走 F43
// 汇编器同款区间入口(getPortfolioPerformance 显式 rangeStart/rangeEnd,
// 强制本地引擎)→ PeriodPerformance(期初/期末市值/净买入/估算收益/
// 区间 TWR);期望值 = F43 区间测试的手算 oracle,逐分断言。
import 'package:dartz/dartz.dart' as dz;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/assistant/data/tools/performance_range_tool.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/holding/data/goal_view_ds.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/data/holding_remote_ds.dart';
import 'package:yucai_client/holding/data/holding_repository_impl.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

class _MockRemote extends Mock implements HoldingRemoteDataSource {}

class _MockGoalViewDs extends Mock implements GoalViewDataSource {}

class _MockHoldingRepo extends Mock implements HoldingRepository {}

/// FR-6 oracle(F43 local_performance_assembler_range_test 同款,cents):
/// 07-01 买 10@4,277(窗前)→ 08-02 买 10@4,777、08-15 卖 10@4,577
/// → 窗口 [08-01, 08-31]:期初 42,770 / 期末 45,770 / 净买入 2,000 /
/// 估算收益 1,000 / TWR = ((47770/42770)×(91540/95540)×1−1)×100。
const _fr6BeginMv = 42770;
const _fr6EndMv = 45770;
const _fr6NetBuy = 2000;
const _fr6Gain = 1000;
const _fr6Twr = ((47770 / 42770) * (91540 / 95540) * (45770 / 45770) - 1) * 100;

final _fixedNow = DateTime(2026, 10, 23, 12);

void main() {
  late db.AppDatabase database;
  late HoldingRepositoryImpl repo;

  Future<void> seedFr6() async {
    final txns = TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    final holding = HoldingLocalDataSource(database, txns);
    Future<String> seedAccount(String id, String name, int balance) async {
      await database.accountDao.insertAccount(db.AccountsCompanion.insert(
        id: id,
        name: name,
        accountType: 1,
        category: 2,
        currencyCode: 'CNY',
        initialBalanceCents: balance,
        currentBalanceCents: balance,
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
      return id;
    }

    final cash = await seedAccount('acc-cash', 'cash', 1000000);
    final inv = await seedAccount('acc-inv', 'inv', 1000000);
    final sec = (await holding.createSecurity(
            symbol: 'FR6', name: 'FR6', type: SecurityType.stock, currency: 'CNY'))
        .id;
    await holding.buy(
        accountId: inv, securityId: sec, fromAccountId: cash,
        quantity: 10, priceCents: 4277, tradeDate: '2026-07-01');
    await holding.buy(
        accountId: inv, securityId: sec, fromAccountId: cash,
        quantity: 10, priceCents: 4777, tradeDate: '2026-08-02');
    await holding.sell(
        accountId: inv, securityId: sec, fromAccountId: cash,
        quantity: 10, priceCents: 4577, tradeDate: '2026-08-15');
  }

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    final tracker = SessionModeTracker()..isGuest = true;
    repo = HoldingRepositoryImpl(
      _MockRemote(),
      HoldingLocalDataSource(database,
          TransactionLocalDataSource(database, BalanceLocalUpdater(database))),
      tracker,
      _MockGoalViewDs(),
    );
  });

  tearDown(() => database.close());

  Map<String, Object?> run(ToolResult r) => (r as ToolData).json;

  test('explicit window matches the F43 report oracle, cent-exact', () async {
    await seedFr6();
    final tool = PerformanceRangeTool(repo, () => _fixedNow);
    final json = run(await tool.execute({
      'start': '2026-08-01',
      'end': '2026-08-31',
    }));

    expect(json['start'], '2026-08-01', reason: '区间日期回显');
    expect(json['end'], '2026-08-31');
    expect(json['beginMvCents'], _fr6BeginMv);
    expect(json['beginMvYuan'], '427.70');
    expect(json['endMvCents'], _fr6EndMv);
    expect(json['endMvYuan'], '457.70');
    expect(json['netBuyCents'], _fr6NetBuy);
    expect(json['netBuyYuan'], '20.00');
    expect(json['estimatedGainCents'], _fr6Gain);
    expect(json['estimatedGainYuan'], '10.00');
    expect((json['twrPct'] as double), closeTo(_fr6Twr, 0.001));
    expect(json['currency'], 'CNY');
    expect(json['caliber'], isA<String>(),
        reason: '口径说明字段(spec:输出含区间日期与口径说明)');
    expect((json['caliber'] as String), contains('report'));
  });

  test('default window = year-to-date (Jan 1 → today, injected clock)',
      () async {
    await seedFr6();
    final tool = PerformanceRangeTool(repo, () => _fixedNow);
    final json = run(await tool.execute(const {}));

    expect(json['start'], '2026-01-01', reason: '缺省 = 年初');
    expect(json['end'], '2026-10-23', reason: '缺省 = 至今(注入时钟)');
    // 年初至今窗含 07-01 首笔建仓 → 期初 0;净买入 = 全部三笔
    // (42,770 + 47,770 − 45,770 = 44,770);估算收益仍 = 1,000。
    expect(json['beginMvCents'], 0);
    expect(json['endMvCents'], _fr6EndMv);
    expect(json['netBuyCents'], 42770 + 47770 - 45770);
    expect(json['estimatedGainCents'], _fr6Gain);
  });

  test('half-open windows: start-only extends to today; end-only starts Jan 1 of that year',
      () async {
    await seedFr6();
    final tool = PerformanceRangeTool(repo, () => _fixedNow);

    final startOnly = run(await tool.execute({'start': '2026-08-01'}));
    expect(startOnly['start'], '2026-08-01');
    expect(startOnly['end'], '2026-10-23');
    expect(startOnly['estimatedGainCents'], _fr6Gain);

    final endOnly = run(await tool.execute({'end': '2026-08-31'}));
    expect(endOnly['start'], '2026-01-01');
    expect(endOnly['end'], '2026-08-31');
    expect(endOnly['estimatedGainCents'], _fr6Gain);
  });

  test('window with no position → honest zero rows + note (no fabrication)',
      () async {
    await seedFr6();
    final tool = PerformanceRangeTool(repo, () => _fixedNow);
    // 窗口全在首笔成交前:期初/期末/净买入全零(报告「本期无持仓」同语义)。
    final json = run(await tool.execute({
      'start': '2026-01-01',
      'end': '2026-03-31',
    }));
    expect(json['beginMvCents'], 0);
    expect(json['endMvCents'], 0);
    expect(json['netBuyCents'], 0);
    expect(json['estimatedGainCents'], 0);
    expect(json['note'], contains('no position'));
  });

  test('bad-price degradation (holding without any price) → ToolError',
      () async {
    // 持仓无现价且无成交 → ffill 价 0(坏价哨兵)→ 汇编器 period=null。
    await database.referenceDao.insertSecurity(db.SecuritiesCompanion.insert(
      id: 'sec-bad',
      symbol: 'BAD',
      name: '无价证券',
      securityType: 'stock',
      exchange: '',
      currencyCode: 'CNY',
      currentPriceCents: 0,
      createdAt: DateTime.now().toUtc(),
    ));
    await database.holdingDao.insertHolding(db.HoldingsCompanion.insert(
      id: 'h-bad',
      accountId: 'acc-inv',
      securityId: 'sec-bad',
      quantity: 5,
      avgCostCents: 1000,
      version: 1,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ));
    // 窗前建仓成交 @0 价:期末持仓 qty>0 且 ffill 价 0 → 坏价哨兵 →
    // 汇编器 period=null(报告隐藏投资章节同因)。
    await database.holdingDao.insertHoldingTransaction(
        db.HoldingTransactionsCompanion.insert(
      id: 'ht-bad',
      accountId: 'acc-inv',
      securityId: 'sec-bad',
      tradeType: 1,
      quantity: 5,
      priceCents: 0,
      amountCents: 0,
      feeCents: 0,
      realizedPnlCents: 0,
      tradeDate: DateTime.utc(2025, 12, 1),
      notes: '',
      createdAt: DateTime.now().toUtc(),
    ));
    final tool = PerformanceRangeTool(repo, () => _fixedNow);
    final result = await tool.execute(const {});
    expect(result, isA<ToolError>());
  });

  test('invalid args → self-correcting ToolError (no throw)', () async {
    await seedFr6();
    final tool = PerformanceRangeTool(repo, () => _fixedNow);
    expect(await tool.execute({'start': 'yesterday'}), isA<ToolError>());
    expect(await tool.execute({'end': 'not-a-date'}), isA<ToolError>());
    expect(
        await tool.execute({'start': '2026-10-01', 'end': '2026-08-01'}),
        isA<ToolError>(),
        reason: 'start > end 自纠');
  });

  test('repository failure → ToolError, no throw', () async {
    final failing = _MockHoldingRepo();
    when(() => failing.getPortfolioPerformance(
          range: any(named: 'range'),
          accountId: any(named: 'accountId'),
          includeBenchmark: any(named: 'includeBenchmark'),
          baseCurrency: any(named: 'baseCurrency'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        )).thenAnswer((_) async => const dz.Left(UnexpectedFailure('db down')));
    final result =
        await PerformanceRangeTool(failing, () => _fixedNow).execute(const {});
    expect(result, isA<ToolError>());
  });
}
