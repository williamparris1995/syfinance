// T3(F43 R16 sprint-1)—— 区间参数透传:repo → local ds → assembler。
// 真实 drift 内存库 + 真实 ds.buy/sell 落库(与 holding_repository_impl_test
// 同款范式),验证 FR-6 显式 [start,end] 窗口穿过整条链路锚定正确。
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/account_dao.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/data/goal_view_ds.dart';
import 'package:yucai_client/holding/data/holding_remote_ds.dart';
import 'package:yucai_client/holding/data/holding_repository_impl.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

class _MockRemote extends Mock implements HoldingRemoteDataSource {}
class _MockGoalViewDs extends Mock implements GoalViewDataSource {}

void main() {
  late db.AppDatabase database;
  late HoldingLocalDataSource holding;
  late TransactionLocalDataSource txns;
  late AccountDao accounts;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    txns = TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    holding = HoldingLocalDataSource(database, txns);
    accounts = database.accountDao;
  });

  tearDown(() => database.close());

  Future<String> seedAccount(String name, int type, {int balance = 1000000}) async {
    final id = 'acc-$name';
    await accounts.insertAccount(db.AccountsCompanion.insert(
      id: id,
      name: name,
      accountType: type,
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

  /// FR-6 场景(与 assembler 区间用例同款 oracle,cents 口径):
  /// 期初 42,770 → 期末 45,770,净买入 2,000 → 估算收益 1,000。
  Future<void> seedFr6Trades(String inv, String cash, String sec) async {
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

  test('DS:getPortfolioPerformance 显式区间 → period 锚定 [start, end]', () async {
    final cash = await seedAccount('cash', 1);
    final inv = await seedAccount('inv', 1);
    final sec =
        (await holding.createSecurity(symbol: 'FR6', name: 'FR6', type: SecurityType.stock, currency: 'CNY')).id;
    await seedFr6Trades(inv, cash, sec);

    final p = await holding.getPortfolioPerformance(
      rangeStart: DateTime(2026, 8, 1),
      rangeEnd: DateTime(2026, 8, 31),
    );
    expect(p.period, isNotNull);
    expect(p.period!.beginMvCents, 42770);
    expect(p.period!.endMvCents, 45770);
    expect(p.period!.netBuyCents, 2000);
    expect(p.period!.estimatedGainCents, 1000);

    // 缺省调用(旧形态,range 字符串):period 恒 null,行为不变。
    final p2 = await holding.getPortfolioPerformance(range: 'MONTH');
    expect(p2.period, isNull);
  });

  test('Repo(guest 本地路由):显式区间参数透传到本地引擎', () async {
    final remote = _MockRemote();
    final goalViewDs = _MockGoalViewDs();
    final tracker = SessionModeTracker()..isGuest = true;
    final repo = HoldingRepositoryImpl(
        remote, holding, tracker, goalViewDs);

    final cash = await seedAccount('cash2', 1);
    final inv = await seedAccount('inv2', 1);
    final sec =
        (await holding.createSecurity(symbol: 'FR6R', name: 'FR6R', type: SecurityType.stock, currency: 'CNY')).id;
    await seedFr6Trades(inv, cash, sec);

    final result = await repo.getPortfolioPerformance(
      range: 'MONTH',
      rangeStart: DateTime(2026, 8, 1),
      rangeEnd: DateTime(2026, 8, 31),
    );
    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('expected Right'),
      (p) {
        expect(p.period, isNotNull);
        expect(p.period!.estimatedGainCents, 1000);
        expect(p.period!.netBuyCents, 2000);
      },
    );
    verifyNever(() => remote.getPortfolioPerformance(
        range: any(named: 'range'),
        accountId: any(named: 'accountId'),
        includeBenchmark: any(named: 'includeBenchmark'),
        baseCurrency: any(named: 'baseCurrency')));
  });
}
