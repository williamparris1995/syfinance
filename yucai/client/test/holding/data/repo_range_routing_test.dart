// T2(F43 R16 sprint-1)—— 区间绩效强制本地路由(T3 评审 Important 落点)。
//
// FR-2 三态一致的接口约束:rangeStart/rangeEnd 显式给出时,绑定在线也必须
// 走本地 DS(holding.proto 无区间字段,直达 server 会丢参数破坏三态一致);
// 既有无区间调用行为零改(护栏:无参 → 原路由,即绑定在线走 server)。
// 真实 drift 内存库 + 真实 HoldingLocalDataSource(与 holding_perf_range_
// passthrough_test 同款 FR-6 oracle 种子),remote 用 mock 标记值区分来源。
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/data/goal_view_ds.dart';
import 'package:yucai_client/holding/data/holding_remote_ds.dart';
import 'package:yucai_client/holding/data/holding_repository_impl.dart';
import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

class _MockRemote extends Mock implements HoldingRemoteDataSource {}

class _MockGoalViewDs extends Mock implements GoalViewDataSource {}

void main() {
  late db.AppDatabase database;
  late HoldingLocalDataSource holding;
  late _MockRemote remote;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    final txns = TransactionLocalDataSource(
      database,
      BalanceLocalUpdater(database),
    );
    holding = HoldingLocalDataSource(database, txns);
    remote = _MockRemote();
  });

  tearDown(() => database.close());

  Future<String> seedAccount(String name) async {
    final id = 'acc-$name';
    await database.accountDao.insertAccount(
      db.AccountsCompanion.insert(
        id: id,
        name: name,
        accountType: 1,
        category: 2,
        currencyCode: 'CNY',
        initialBalanceCents: 1000000,
        currentBalanceCents: 1000000,
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
    return id;
  }

  /// FR-6 oracle(与 holding_perf_range_passthrough_test 同款):
  /// 窗口 [08-01, 08-31] → 期初 42,770 / 期末 45,770 / 净买入 2,000 /
  /// 估算收益 1,000。
  Future<void> seedFr6Trades(String inv, String cash, String sec) async {
    await holding.buy(
      accountId: inv,
      securityId: sec,
      fromAccountId: cash,
      quantity: 10,
      priceCents: 4277,
      tradeDate: '2026-07-01',
    );
    await holding.buy(
      accountId: inv,
      securityId: sec,
      fromAccountId: cash,
      quantity: 10,
      priceCents: 4777,
      tradeDate: '2026-08-02',
    );
    await holding.sell(
      accountId: inv,
      securityId: sec,
      fromAccountId: cash,
      quantity: 10,
      priceCents: 4577,
      tradeDate: '2026-08-15',
    );
  }

  /// 绑定在线(非 guest 且 online 缺省 true → DataRoute.boundRemote)。
  HoldingRepositoryImpl boundOnlineRepo() {
    final tracker = SessionModeTracker()..isGuest = false;
    return HoldingRepositoryImpl(remote, holding, tracker, _MockGoalViewDs());
  }

  Future<PortfolioPerformance> remoteAnswer() async =>
      const PortfolioPerformance(
        realizedCents: 7,
        unrealizedCents: 7,
        totalCents: 7,
        benchmarkName: 'REMOTE-ORACLE',
      );

  test('绑定在线 + 显式区间 → 强制本地路由,不触 remote(FR-2)', () async {
    final repo = boundOnlineRepo();
    final cash = await seedAccount('cash');
    final inv = await seedAccount('inv');
    final sec = (await holding.createSecurity(
      symbol: 'RRT',
      name: 'RRT',
      type: SecurityType.stock,
      currency: 'CNY',
    )).id;
    await seedFr6Trades(inv, cash, sec);

    final result = await repo.getPortfolioPerformance(
      range: 'MONTH',
      rangeStart: DateTime(2026, 8, 1),
      rangeEnd: DateTime(2026, 8, 31),
    );
    expect(result.isRight(), isTrue);
    result.fold((_) => fail('expected Right'), (p) {
      // 本地引擎的区间分解在场(server 响应无 period,来源即本地)。
      expect(p.period, isNotNull);
      expect(p.period!.beginMvCents, 42770);
      expect(p.period!.endMvCents, 45770);
      expect(p.period!.netBuyCents, 2000);
      expect(p.period!.estimatedGainCents, 1000);
      expect(p.benchmarkName, isNot('REMOTE-ORACLE'));
    });
    verifyNever(
      () => remote.getPortfolioPerformance(
        range: any(named: 'range'),
        accountId: any(named: 'accountId'),
        includeBenchmark: any(named: 'includeBenchmark'),
        baseCurrency: any(named: 'baseCurrency'),
      ),
    );
  });

  test('护栏:绑定在线 + 无区间参数 → 原路由不变(直达 server)', () async {
    final repo = boundOnlineRepo();
    when(
      () => remote.getPortfolioPerformance(
        range: any(named: 'range'),
        accountId: any(named: 'accountId'),
        includeBenchmark: any(named: 'includeBenchmark'),
        baseCurrency: any(named: 'baseCurrency'),
      ),
    ).thenAnswer((_) => remoteAnswer());

    final result = await repo.getPortfolioPerformance(range: 'MONTH');
    expect(result.isRight(), isTrue);
    result.fold((_) => fail('expected Right'), (p) {
      // server 权威值(标记字段),且无区间分解。
      expect(p.benchmarkName, 'REMOTE-ORACLE');
      expect(p.period, isNull);
    });
    verify(
      () => remote.getPortfolioPerformance(
        range: 'MONTH',
        accountId: any(named: 'accountId'),
        includeBenchmark: any(named: 'includeBenchmark'),
        baseCurrency: any(named: 'baseCurrency'),
      ),
    ).called(1);
  });

  test('护栏:仅 rangeStart 半参同样强制本地(proto 区间字段整体缺失)', () async {
    final repo = boundOnlineRepo();
    final cash = await seedAccount('cash3');
    final inv = await seedAccount('inv3');
    final sec = (await holding.createSecurity(
      symbol: 'RRT3',
      name: 'RRT3',
      type: SecurityType.stock,
      currency: 'CNY',
    )).id;
    await seedFr6Trades(inv, cash, sec);

    // 半参(仅 rangeStart)不会产 period(assembler 语义),但路由必须已
    // 强制本地 —— 以「remote 零调用」钉死,值断言只看是否本地口径。
    final result = await repo.getPortfolioPerformance(
      range: 'MONTH',
      rangeStart: DateTime(2026, 8, 1),
    );
    expect(result.isRight(), isTrue);
    expect(
      result.fold((l) => null, (p) => p.benchmarkName),
      isNot('REMOTE-ORACLE'),
    );
    verifyNever(
      () => remote.getPortfolioPerformance(
        range: any(named: 'range'),
        accountId: any(named: 'accountId'),
        includeBenchmark: any(named: 'includeBenchmark'),
        baseCurrency: any(named: 'baseCurrency'),
      ),
    );
  });
}
