// F64-T3 口径逐分断言(NFR-1):参数化全工具 —— 同一测试库种子 →
// 工具输出 vs 同库直查(drift 原始行独立重算)逐分相等。
//
// 直查口径(Never import 工具实现的算法,测试内独立重算):
// - networth:assets = Σ type1 账户余额;liabilities = Σ borrowedIn 债
//   (totalPrincipal − Σ期次 paidCents)(NetWorthLocalDataSource 同算法);
// - accounts:分组小计 = Σ 可见户(type≠isSystem)余额;卡占用 = Σ
//   unpaid 且 paymentDate > today(UTC 日界)期次本金(F50/F58 口径);
// - debts:剩余 = Σ unpaid 期次本金(期表口径)。
// 夹具期次 interest=0 → networth 负债与 debts 剩余同数,可作跨工具链校验
// (利息口径差为已知接受差异,见 _toEntity 注释)。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/assistant/data/tools/accounts_list_tool.dart';
import 'package:yucai_client/assistant/data/tools/debts_list_tool.dart';
import 'package:yucai_client/assistant/data/tools/networth_snapshot_tool.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/assistant/domain/networth_port.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/assistant/domain/base_currency_port.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/data/debt_remote_ds.dart';
import 'package:yucai_client/debt/data/debt_repository_impl.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart'
    show NetWorthLocalDataSource;
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

class _MockAccountRemote extends Mock implements AccountRemoteDataSource {}

class _MockDebtRemote extends Mock implements DebtRemoteDataSource {}

class _FakeBaseCurrency implements BaseCurrencySource {
  @override
  Future<String> getBaseCurrency() async => 'CNY';
}

/// DI 组合根同款适配:NetWorthSnapshotSource port → NetWorthLocalDataSource
/// (assistant 生产代码不 import holding/data;组合根/测试负责接线)。
class _NetWorthSourceAdapter implements NetWorthSnapshotSource {
  _NetWorthSourceAdapter(this._ds);
  final NetWorthLocalDataSource _ds;

  @override
  Future<NetWorthView> fetch({required String baseCurrency}) =>
      _ds.getNetWorth(baseCurrency: baseCurrency);
}

final _fixedNow = DateTime.utc(2026, 10, 23, 4);

void main() {
  late db.AppDatabase database;
  late NetWorthSnapshotTool networthTool;
  late AccountsListTool accountsTool;
  late DebtsListTool debtsTool;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    final tracker = SessionModeTracker()..isGuest = true;
    final accountsRepo = AccountRepositoryImpl(
      _MockAccountRemote(),
      AccountLocalDataSource(database),
      tracker,
    );
    final debtsRepo = DebtRepositoryImpl(
      _MockDebtRemote(),
      DebtLocalDataSource(
          database, TransactionLocalDataSource(database, BalanceLocalUpdater(database))),
      tracker,
    );
    networthTool = NetWorthSnapshotTool(
        _NetWorthSourceAdapter(NetWorthLocalDataSource(database)),
        _FakeBaseCurrency());
    accountsTool = AccountsListTool(accountsRepo, debtsRepo, () => _fixedNow);
    debtsTool = DebtsListTool(debtsRepo, () => _fixedNow);

    // ── 共享种子 ──
    await database.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: 'acc-cash',
      name: '现金',
      accountType: 1,
      category: 1,
      currencyCode: 'CNY',
      initialBalanceCents: 1234567,
      currentBalanceCents: 1234567,
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
    await database.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: 'acc-card',
      name: '招行信用卡',
      accountType: 2,
      category: 2,
      currencyCode: 'CNY',
      initialBalanceCents: 500500,
      currentBalanceCents: 500500,
      ownership: 1,
      icon: '',
      color: '',
      chartCode: '',
      isSystem: false,
      sortOrder: 1,
      institution: '',
      cardNumberTail: '',
      notes: '',
      goldProductType: '',
      status: 1,
      version: 1,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      creditLimitCents: const Value(5000000),
    ));
    // 载体户:净资产/负债计入,accounts_list 出局。
    await database.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: 'acc-carrier',
      name: '平安卡贷载体',
      accountType: 2,
      category: 6,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: 1,
      icon: '',
      color: '',
      chartCode: '',
      isSystem: true,
      sortOrder: 2,
      institution: '',
      cardNumberTail: '',
      notes: '',
      goldProductType: '',
      status: 1,
      version: 1,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ));

    Future<void> seedDebt(String id,
        {required int total,
        required int debtType,
        required String subtype,
        String? collectionAccountId}) =>
        database.debtDao.insertDebt(db.DebtsCompanion.insert(
          id: id,
          accountId: 'acc-carrier',
          counterparty: 'cp-$id',
          interestRate: 0.5,
          amortizationMethod: 1,
          startDate: DateTime.utc(2026, 8, 1),
          dueDate: DateTime.utc(2027, 8, 1),
          totalPrincipalCents: total,
          debtType: debtType,
          subtype: subtype,
          contact: '',
          contractRef: '',
          collectionAccountId: Value(collectionAccountId),
          version: 1,
          createdAt: DateTime.utc(2026, 8, 1),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));

    Future<void> seedEntry(String debtId, String id, DateTime date,
            int principal, {bool paid = false}) =>
        database.debtDao.insertScheduleEntry(
            db.PaymentScheduleEntriesCompanion.insert(
          id: id,
          debtId: debtId,
          paymentDate: date,
          principalCents: principal,
          interestCents: 0,
          totalCents: principal,
          paidCents: paid ? principal : 0,
          paid: paid,
        ));

    // d1 挂卡卡贷:total = Σ期次本金(460000)。
    await seedDebt('d1',
        total: 460000,
        debtType: 1,
        subtype: DebtSubtypes.cardLoan,
        collectionAccountId: 'acc-card');
    await seedEntry('d1', 'e1', DateTime.utc(2026, 8, 1), 100000, paid: true);
    await seedEntry('d1', 'e2', DateTime.utc(2026, 9, 1), 110000);
    await seedEntry('d1', 'e3', DateTime.utc(2026, 11, 1), 120000);
    await seedEntry('d1', 'e4', DateTime.utc(2026, 12, 1), 130000);

    // d2 已结清普通债;total = 期次合计(净贡献 0)。
    await seedDebt('d2',
        total: 200000, debtType: 1, subtype: DebtSubtypes.creditLoan);
    await seedEntry('d2', 'e5', DateTime.utc(2026, 8, 1), 200000, paid: true);

    // d3 借出:净资产与 debts_list 均不计。
    await seedDebt('d3',
        total: 50000, debtType: 2, subtype: DebtSubtypes.creditLoan);
    await seedEntry('d3', 'e6', DateTime.utc(2026, 11, 1), 50000);
  });

  tearDown(() => database.close());

  test(
      'parameterized: every tool cent-exact vs same-db direct recomputation',
      () async {
    // ── 同库直查(drift 原始行,独立重算)──
    final accountRows = await database.accountDao.getAllAccounts();
    final debtRows = await database.debtDao.watchAllDebts().first;

    final directAssets = accountRows
        .where((r) => r.accountType == 1)
        .fold(0, (s, r) => s + r.currentBalanceCents);
    var directLiabilities = 0;
    final directDebtRemainingById = <String, int>{};
    for (final d in debtRows) {
      final schedule = await database.debtDao.getScheduleByDebt(d.id);
      if (d.debtType == 1) {
        final paid = schedule.fold(0, (s, e) => s + e.paidCents);
        directLiabilities += d.totalPrincipalCents - paid;
        directDebtRemainingById[d.id] =
            schedule.where((e) => !e.paid).fold(0, (s, e) => s + e.principalCents);
      }
    }
    final todayStart = DateTime.utc(2026, 10, 23);
    final directOccupation = (await database.debtDao.getScheduleByDebt('d1'))
        .where((e) => !e.paid && e.paymentDate.isAfter(todayStart))
        .fold(0, (s, e) => s + e.principalCents);

    // ── networth_snapshot ──
    final nw = (await networthTool.execute(const {}) as ToolData).json;
    expect(nw['totalAssetsCents'], directAssets, reason: 'networth assets');
    expect(nw['totalLiabilitiesCents'], directLiabilities,
        reason: 'networth liabilities');
    expect(nw['netWorthCents'], directAssets - directLiabilities,
        reason: 'networth = assets - liabilities');
    expect(nw['currency'], 'CNY');

    // ── accounts_list ──
    final al = (await accountsTool.execute(const {}) as ToolData).json;
    final visibleRows = accountRows.where((r) => !r.isSystem).toList();
    expect(al['totalCount'], visibleRows.length,
        reason: '载体户不计 total_count');
    for (final type in [1, 2]) {
      final direct = visibleRows
          .where((r) => r.accountType == type)
          .fold(0, (s, r) => s + r.currentBalanceCents);
      final groupType = type == 1 ? 'asset' : 'liability';
      final groups = (al['groups'] as List).cast<Map<String, Object?>>();
      expect(
          groups.firstWhere((g) => g['type'] == groupType)['subtotalCents'],
          direct,
          reason: 'accounts group subtotal ($groupType)');
    }
    final cardItem = (al['accounts'] as List)
        .cast<Map<String, Object?>>()
        .singleWhere((a) => a['name'] == '招行信用卡');
    expect(cardItem['usedCents'], 500500 + directOccupation,
        reason: '卡已用 = 欠款 + F50 未出账占用');
    expect(cardItem['availableCents'], 5000000 - 500500 - directOccupation,
        reason: '卡可用 = 限额 − 已用');

    // ── debts_list ──
    final dl = (await debtsTool.execute(const {}) as ToolData).json;
    final debtItems = (dl['debts'] as List).cast<Map<String, Object?>>();
    // 未结清 = d1(d2 已结清、d3 借出出局);逐分比对剩余本金。
    expect(debtItems, hasLength(1));
    expect(debtItems.single['remainingPrincipalCents'],
        directDebtRemainingById['d1'],
        reason: 'debts remaining = Σ unpaid principal (schedule caliber)');
    expect(debtItems.single['nextPaymentAmountCents'], 110000,
        reason: '下期 = 最早未还期次 e2');
    expect((dl['summary'] as Map)['totalRemainingCents'],
        directDebtRemainingById.values.fold(0, (a, b) => a + b),
        reason: '汇总 Σ剩余');

    // ── 跨工具链(夹具 interest=0,两口径同数)──
    expect(nw['totalLiabilitiesCents'],
        (dl['summary'] as Map)['totalRemainingCents'],
        reason: 'networth 负债与 debts 剩余在本夹具下逐分相等');
  });

  test('carrier account invisible in accounts_list on the shared fixture',
      () async {
    final al = (await accountsTool.execute(const {}) as ToolData).json;
    final names = (al['accounts'] as List)
        .cast<Map<String, Object?>>()
        .map((a) => a['name'])
        .toSet();
    expect(names.contains('平安卡贷载体'), isFalse,
        reason: '载体户不可见(spec FR-2 场景)');
    expect(al['totalCount'], 2);
  });
}
