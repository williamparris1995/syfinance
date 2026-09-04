// F10 T2(2026-09-04):镜像协调 pending 保护(spec FR-3,design ADR-3)。
// - refreshModule 的 delete-all 排除 pending;rebuild 遇同 id(持仓按
//   account+security 对)pending 行跳过,保本地内容与存在性(单设备语义:
//   server 行 = pending 前镜像,跳过安全);
// - pending 行的子表数据(交易分录/债务期次/持仓台账/证券引用/标签联表)
//   随头行保留;
// - 在线全 synced 场景行为逐位不变(delete 条件对 synced 行等价 delete-all)。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dartz/dartz.dart' as dz;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db
    hide Account, Holding, Security, Transaction;
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

final getIt = GetIt.instance;

class _MockAccountRepo extends Mock implements AccountRepository {}
class _MockTxnRepo extends Mock implements TransactionRepository {}
class _MockDebtRepo extends Mock implements DebtRepository {}
class _MockHoldingRepo extends Mock implements HoldingRepository {}
class _MockTagRepo extends Mock implements TagRepository {}

final _serverAccount = Account(
  id: 'a1',
  name: 'Server',
  accountType: AccountType.asset,
  category: AccountCategory.savings,
  currencyCode: 'CNY',
  initialBalanceCents: 0,
  currentBalanceCents: 999,
  ownership: Ownership.personal,
  status: AccountStatus.active,
  version: 7,
  createdAt: DateTime.utc(2026, 8, 23),
);

void main() {
  late db.AppDatabase database;

  setUp(() => database = db.AppDatabase(NativeDatabase.memory()));
  tearDown(() async {
    await database.close();
    getIt.reset();
  });

  Future<void> insertAccount(String id,
      {String syncState = SyncState.synced, String name = 'local'}) async {
    await database.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: id,
      name: name,
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
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
      syncState: Value(syncState),
    ));
  }

  group('account 模块', () {
    test('pending 行 refresh 后内容/存在性不变;synced 行照常 rebuild', () async {
      // 本地:一行 pending(离线建)+ 一行 synced stale。
      await insertAccount('local-pending', syncState: SyncState.pending);
      await insertAccount('stale', name: 'old');
      // server:同名 id 旧镜像 + 新行。
      final repo = _MockAccountRepo();
      when(() => repo.list()).thenAnswer((_) async => dz.Right([
            _serverAccount, // 新行(server-only)
            _serverAccount.copyWith(id: 'local-pending', name: 'ServerOld'),
          ]));
      getIt.registerSingleton<AccountRepository>(repo);

      await BoundMirror(database).refreshModule(MirrorModule.account);

      final rows = await database.accountDao.getAllAccounts();
      expect(rows, hasLength(2));
      final byId = {for (final r in rows) r.id: r};
      // pending:本地行保住,server 旧镜像未覆盖(跳过 rebuild)。
      expect(byId['local-pending']!.name, 'local');
      expect(byId['local-pending']!.syncState, SyncState.pending);
      // stale 被清、server 新行重建为 synced 镜像。
      expect(byId['a1']!.name, 'Server');
      expect(byId['a1']!.syncState, SyncState.synced);
      expect(byId.containsKey('stale'), isFalse);
    });

    test('在线全 synced:refresh 结果与 delete-all+rebuild 等价(逐位不变)',
        () async {
      await insertAccount('stale1', name: 'old1');
      await insertAccount('stale2', name: 'old2');
      final repo = _MockAccountRepo();
      when(() => repo.list()).thenAnswer((_) async => dz.Right([_serverAccount]));
      getIt.registerSingleton<AccountRepository>(repo);

      await BoundMirror(database).refreshModule(MirrorModule.account);

      // 等价断言:本地行集 == server 行集(旧行全清、镜像行写入)。
      final rows = await database.accountDao.getAllAccounts();
      expect(rows.map((r) => r.id), [_serverAccount.id]);
      expect(rows.single.name, 'Server');
      expect(rows.single.currentBalanceCents, 999);
    });
  });

  group('transaction 模块', () {
    test('pending 交易 + 分录 refresh 后保留;synced 交易按 server 重建',
        () async {
      final now = DateTime.utc(2026, 9, 4);
      Future<void> seedTxn(String id, String state) async {
        await database.transactionDao
            .insertTransaction(db.TransactionsCompanion.insert(
          id: id,
          transactionDate: now,
          description: 'd-$id',
          version: 1,
          createdAt: now,
          updatedAt: now,
          syncState: Value(state),
        ));
        await database.transactionDao.insertEntry(
            db.TransactionEntriesCompanion.insert(
          id: 'e-$id',
          transactionId: id,
          accountId: 'acc',
          chartOfAccountCode: '',
          debitCents: 100,
          creditCents: 0,
          note: '',
        ));
      }

      await seedTxn('txn-pending', SyncState.pending);
      await seedTxn('txn-stale', SyncState.synced);

      registerFallbackValue(const ListTransactionsParams());
      final repo = _MockTxnRepo();
      when(() => repo.list(any())).thenAnswer((_) async => dz.Right(
            ListTransactionsResult(
              transactions: [
                Transaction(
                  id: 'txn-pending',
                  transactionDate: now,
                  description: 'ServerOld',
                  version: 1,
                  entries: const [],
                ),
                Transaction(
                  id: 'txn-server',
                  transactionDate: now,
                  description: 'from-server',
                  entries: const [
                    TransactionEntry(
                        id: 'e-server-1',
                        accountId: 'acc',
                        debitCents: 5,
                        creditCents: 0),
                    TransactionEntry(
                        id: 'e-server-2',
                        accountId: 'acc',
                        debitCents: 0,
                        creditCents: 5),
                  ],
                ),
              ],
            ),
          ));
      getIt.registerSingleton<TransactionRepository>(repo);

      await BoundMirror(database).refreshModule(MirrorModule.transaction);

      final heads = await database.transactionDao.getAllTransactions();
      expect(heads.map((t) => t.id),
          unorderedEquals(['txn-pending', 'txn-server']));
      final byId = {for (final t in heads) t.id: t};
      // pending:本地描述保住、分录保留。
      expect(byId['txn-pending']!.description, 'd-txn-pending');
      expect(byId['txn-pending']!.syncState, SyncState.pending);
      expect(
          await database.transactionDao
              .watchEntriesByTransaction('txn-pending').first,
          hasLength(1));
      // server 行重建(带分录);stale 行清除。
      expect(byId['txn-server']!.description, 'from-server');
      expect(
          await database.transactionDao
              .watchEntriesByTransaction('txn-server').first,
          hasLength(2));
      expect(byId.containsKey('txn-stale'), isFalse);
    });
  });

  group('debt 模块', () {
    test('pending 债务 + 期次 refresh 后保留(还款事实不丢)', () async {
      final now = DateTime.utc(2026, 9, 4);
      await database.debtDao.insertDebt(db.DebtsCompanion.insert(
        id: 'd-pending',
        accountId: 'acc',
        counterparty: 'bank',
        interestRate: 0,
        amortizationMethod: 3,
        startDate: now,
        dueDate: now,
        totalPrincipalCents: 1000,
        debtType: 1,
        subtype: '',
        contact: '',
        contractRef: '',
        version: 1,
        createdAt: now,
        updatedAt: now,
        syncState: const Value(SyncState.pending),
      ));
      await database.debtDao.insertScheduleEntry(
          db.PaymentScheduleEntriesCompanion.insert(
        id: 's1',
        debtId: 'd-pending',
        paymentDate: now,
        principalCents: 1000,
        interestCents: 0,
        totalCents: 1000,
        paidCents: 1000,
        paid: true,
        transactionId: const Value('t1'),
      ));

      final debt = Debt(
        id: 'd-pending',
        accountId: 'acc',
        counterparty: 'bank',
        interestRate: 0,
        amortization: AmortizationMethod.lumpSum,
        startDate: now,
        dueDate: now,
        totalPrincipalCents: 1000,
        remainingPrincipalCents: 1000,
        version: 1,
        createdAt: now,
        updatedAt: now,
      );
      final repo = _MockDebtRepo();
      when(() => repo.list()).thenAnswer(
          (_) async => dz.Right([debt]));
      when(() => repo.get('d-pending')).thenAnswer((_) async => dz.Right(
            DebtDetail(debt: debt, schedule: const []),
          ));
      getIt.registerSingleton<DebtRepository>(repo);

      await BoundMirror(database).refreshModule(MirrorModule.debt);

      final row = await database.debtDao.getDebtById('d-pending');
      expect(row!.syncState, SyncState.pending);
      final schedule =
          await database.debtDao.watchScheduleByDebt('d-pending').first;
      expect(schedule, hasLength(1));
      expect(schedule.single.paid, isTrue);
    });
  });

  group('holding 模块', () {
    test('pending 持仓 + 台账 + 引用证券 refresh 后保留;synced 照常重建',
        () async {
      final now = DateTime.utc(2026, 9, 4);
      await database.holdingDao.insertHolding(db.HoldingsCompanion.insert(
        id: 'h-pending',
        accountId: 'inv',
        securityId: 'sec-off',
        quantity: 10,
        avgCostCents: 100,
        version: 1,
        createdAt: now,
        updatedAt: now,
        syncState: const Value(SyncState.pending),
      ));
      await database.holdingDao.insertHoldingTransaction(
          db.HoldingTransactionsCompanion.insert(
        id: 'trade-off',
        accountId: 'inv',
        securityId: 'sec-off',
        tradeType: 1,
        quantity: 10,
        priceCents: 100,
        amountCents: 1000,
        feeCents: 0,
        realizedPnlCents: 0,
        tradeDate: now,
        notes: '',
        createdAt: now,
      ));
      await database.holdingDao.insertHolding(db.HoldingsCompanion.insert(
        id: 'h-stale',
        accountId: 'inv',
        securityId: 'sec-old',
        quantity: 1,
        avgCostCents: 1,
        version: 1,
        createdAt: now,
        updatedAt: now,
      ));
      await database.referenceDao.insertSecurity(db.SecuritiesCompanion.insert(
        id: 'sec-off',
        symbol: 'OFF',
        name: '离线建仓证券',
        securityType: 'stock',
        exchange: '',
        currencyCode: 'CNY',
        currentPriceCents: 0,
        createdAt: now,
      ));

      Holding serverHoldingRow(String id, String securityId) => Holding(
            id: id,
            accountId: 'inv',
            securityId: securityId,
            securityName: 'S',
            securitySymbol: 'SRV',
            quantity: 5,
            avgCostCents: 2,
            marketValueCents: 10,
            unrealizedPnlCents: 0,
            version: 1,
          );
      final repo = _MockHoldingRepo();
      when(() => repo.listHoldings()).thenAnswer((_) async => dz.Right([
            serverHoldingRow('h-server', 'sec-server'),
            // 同 (account, security) 的 server 旧行镜像:pending 跳过重建,
            // 否则会出现重复持仓行。
            serverHoldingRow('h-server-legacy', 'sec-off'),
          ]));
      when(() => repo.listHoldingTransactions())
          .thenAnswer((_) async => const dz.Right(<HoldingTransaction>[]));
      when(() => repo.listSecurities()).thenAnswer((_) async => const dz.Right([
            Security(
              id: 'sec-server',
              symbol: 'SRV',
              name: 'ServerSec',
              securityType: SecurityType.stock,
              currency: 'CNY',
              currentPriceCents: 0,
            ),
          ]));
      getIt.registerSingleton<HoldingRepository>(repo);

      await BoundMirror(database).refreshModule(MirrorModule.holding);

      final holdings = await database.holdingDao.watchAllHoldings().first;
      // pending 持仓保住(同 account+security 的 server 旧行不重建,防重复行)。
      expect(holdings.map((h) => h.id), containsAll(['h-pending', 'h-server']));
      expect(holdings, hasLength(2));
      final byId = {for (final h in holdings) h.id: h};
      expect(byId['h-pending']!.syncState, SyncState.pending);
      // 离线台账保留 + server 证券重建 + pending 引用的离线证券保留。
      final trades =
          await database.holdingDao.getAllHoldingTransactions();
      expect(trades.map((t) => t.id), ['trade-off']);
      final securities = await database.referenceDao.getAllSecurities();
      expect(securities.map((s) => s.id),
          containsAll(['sec-off', 'sec-server']));
      expect(securities, hasLength(2));
    });

    test('重叠①:pending 持仓引用 server 已有证券 → refresh 成功且证券保留(fix round 1)',
        () async {
      final now = DateTime.utc(2026, 9, 4);
      // 离线对「server 已有证券」加仓:pending 持仓引用 sec-srv。
      await database.holdingDao.insertHolding(db.HoldingsCompanion.insert(
        id: 'h-pending',
        accountId: 'inv',
        securityId: 'sec-srv',
        quantity: 10,
        avgCostCents: 100,
        version: 1,
        createdAt: now,
        updatedAt: now,
        syncState: const Value(SyncState.pending),
      ));
      await database.holdingDao.insertHolding(db.HoldingsCompanion.insert(
        id: 'h-stale',
        accountId: 'inv',
        securityId: 'sec-old',
        quantity: 1,
        avgCostCents: 1,
        version: 1,
        createdAt: now,
        updatedAt: now,
      ));
      // 本地已有 sec-srv 行(上一轮镜像写入,保留集);server 列表同样含它。
      await database.referenceDao.insertSecurity(db.SecuritiesCompanion.insert(
        id: 'sec-srv',
        symbol: 'SRV',
        name: '上一轮镜像行',
        securityType: 'stock',
        exchange: '',
        currencyCode: 'CNY',
        currentPriceCents: 0,
        createdAt: now,
      ));

      final repo = _MockHoldingRepo();
      when(() => repo.listHoldings())
          .thenAnswer((_) async => const dz.Right([
                Holding(
                  id: 'h-server',
                  accountId: 'inv',
                  securityId: 'sec-other',
                  securityName: 'S',
                  securitySymbol: 'O',
                  quantity: 5,
                  avgCostCents: 2,
                  marketValueCents: 10,
                  unrealizedPnlCents: 0,
                  version: 1,
                ),
              ]));
      when(() => repo.listHoldingTransactions())
          .thenAnswer((_) async => const dz.Right(<HoldingTransaction>[]));
      when(() => repo.listSecurities()).thenAnswer((_) async => const dz.Right([
            // 与保留集重叠:裸 insert 会撞 securities.id UNIQUE → 整事务回滚。
            Security(
              id: 'sec-srv',
              symbol: 'SRV',
              name: 'ServerSec权威行',
              securityType: SecurityType.stock,
              currency: 'CNY',
              currentPriceCents: 0,
            ),
            Security(
              id: 'sec-other',
              symbol: 'O',
              name: 'Other',
              securityType: SecurityType.stock,
              currency: 'CNY',
              currentPriceCents: 0,
            ),
          ]));
      getIt.registerSingleton<HoldingRepository>(repo);

      await BoundMirror(database).refreshModule(MirrorModule.holding);

      // refresh 成功:server 持仓行确实重建(UNIQUE 回滚时整事务作废,
      // h-stale 会残留、h-server 缺失)。
      final holdings = await database.holdingDao.watchAllHoldings().first;
      expect(holdings.map((h) => h.id), unorderedEquals(['h-pending', 'h-server']));
      // 重叠证券保留,且 server 内容权威(upsert 覆盖本地旧行)。
      final securities = await database.referenceDao.getAllSecurities();
      expect(securities.map((s) => s.id),
          unorderedEquals(['sec-srv', 'sec-other']));
      expect(
          securities.singleWhere((s) => s.id == 'sec-srv').name, 'ServerSec权威行');
    });

    test('重叠②:pending pair 含已镜像 server 台账行 → refresh 成功无 UNIQUE(fix round 1)',
        () async {
      final now = DateTime.utc(2026, 9, 4);
      await database.holdingDao.insertHolding(db.HoldingsCompanion.insert(
        id: 'h-pending',
        accountId: 'inv',
        securityId: 'sec-x',
        quantity: 10,
        avgCostCents: 100,
        version: 1,
        createdAt: now,
        updatedAt: now,
        syncState: const Value(SyncState.pending),
      ));
      await database.holdingDao.insertHolding(db.HoldingsCompanion.insert(
        id: 'h-stale',
        accountId: 'inv',
        securityId: 'sec-old',
        quantity: 1,
        avgCostCents: 1,
        version: 1,
        createdAt: now,
        updatedAt: now,
      ));
      Future<void> seedTrade(String id, String securityId) async {
        await database.holdingDao.insertHoldingTransaction(
            db.HoldingTransactionsCompanion.insert(
          id: id,
          accountId: 'inv',
          securityId: securityId,
          tradeType: 1,
          quantity: 10,
          priceCents: 100,
          amountCents: 1000,
          feeCents: 0,
          realizedPnlCents: 0,
          tradeDate: now,
          notes: '',
          createdAt: now,
        ));
      }

      // 保留集内既有上一轮镜像的 server 台账行 t1,也有离线 uuid 行。
      await seedTrade('t1', 'sec-x');
      await seedTrade('trade-off', 'sec-x');

      final repo = _MockHoldingRepo();
      when(() => repo.listHoldings())
          .thenAnswer((_) async => const dz.Right([
                Holding(
                  id: 'h-server',
                  accountId: 'inv',
                  securityId: 'sec-other',
                  securityName: 'S',
                  securitySymbol: 'O',
                  quantity: 5,
                  avgCostCents: 2,
                  marketValueCents: 10,
                  unrealizedPnlCents: 0,
                  version: 1,
                ),
              ]));
      HoldingTransaction serverTrade(String id) => HoldingTransaction(
            id: id,
            accountId: 'inv',
            securityId: 'sec-x',
            tradeType: TradeType.buy,
            quantity: 10,
            priceCents: 100,
            amountCents: 1000,
            feeCents: 0,
            tradeDate: '2026-09-01',
            notes: 'server-$id',
          );
      when(() => repo.listHoldingTransactions()).thenAnswer(
          (_) async => dz.Right([serverTrade('t1'), serverTrade('t2')]));
      when(() => repo.listSecurities())
          .thenAnswer((_) async => const dz.Right(<Security>[]));
      getIt.registerSingleton<HoldingRepository>(repo);

      await BoundMirror(database).refreshModule(MirrorModule.holding);

      // refresh 成功:server 持仓行确实重建(UNIQUE 回滚时整事务作废,
      // h-stale 残留、h-server 缺失)。
      final holdings = await database.holdingDao.watchAllHoldings().first;
      expect(holdings.map((h) => h.id), unorderedEquals(['h-pending', 'h-server']));
      // 台账合集:server 行(t1 权威覆盖 + t2 重建)+ 离线 uuid 行保留。
      final trades = await database.holdingDao.getAllHoldingTransactions();
      expect(trades.map((t) => t.id),
          unorderedEquals(['t1', 't2', 'trade-off']));
      expect(trades.singleWhere((t) => t.id == 't1').notes, 'server-t1');
    });

    test('在线全 synced:refresh 结果与 delete-all+rebuild 等价(逐位不变)',
        () async {
      final now = DateTime.utc(2026, 9, 4);
      await database.holdingDao.insertHolding(db.HoldingsCompanion.insert(
        id: 'h-stale',
        accountId: 'inv',
        securityId: 'sec-old',
        quantity: 1,
        avgCostCents: 1,
        version: 1,
        createdAt: now,
        updatedAt: now,
      ));
      await database.holdingDao.insertHoldingTransaction(
          db.HoldingTransactionsCompanion.insert(
        id: 't-stale',
        accountId: 'inv',
        securityId: 'sec-old',
        tradeType: 1,
        quantity: 1,
        priceCents: 1,
        amountCents: 1,
        feeCents: 0,
        realizedPnlCents: 0,
        tradeDate: now,
        notes: '',
        createdAt: now,
      ));
      await database.referenceDao.insertSecurity(db.SecuritiesCompanion.insert(
        id: 'sec-old',
        symbol: 'OLD',
        name: 'old',
        securityType: 'stock',
        exchange: '',
        currencyCode: 'CNY',
        currentPriceCents: 0,
        createdAt: now,
      ));

      final repo = _MockHoldingRepo();
      when(() => repo.listHoldings())
          .thenAnswer((_) async => const dz.Right([
                Holding(
                  id: 'h-server',
                  accountId: 'inv',
                  securityId: 'sec-server',
                  securityName: 'S',
                  securitySymbol: 'SRV',
                  quantity: 5,
                  avgCostCents: 2,
                  marketValueCents: 10,
                  unrealizedPnlCents: 0,
                  version: 1,
                ),
              ]));
      when(() => repo.listHoldingTransactions())
          .thenAnswer((_) async => const dz.Right([
                HoldingTransaction(
                  id: 't-server',
                  accountId: 'inv',
                  securityId: 'sec-server',
                  tradeType: TradeType.buy,
                  quantity: 5,
                  priceCents: 2,
                  amountCents: 10,
                  feeCents: 0,
                  tradeDate: '2026-09-01',
                ),
              ]));
      when(() => repo.listSecurities()).thenAnswer((_) async => const dz.Right([
            Security(
              id: 'sec-server',
              symbol: 'SRV',
              name: 'ServerSec',
              securityType: SecurityType.stock,
              currency: 'CNY',
              currentPriceCents: 0,
            ),
          ]));
      getIt.registerSingleton<HoldingRepository>(repo);

      await BoundMirror(database).refreshModule(MirrorModule.holding);

      // 等价断言:本地行集 == server 集(旧行全清、镜像行写入)。
      expect((await database.holdingDao.watchAllHoldings().first)
          .map((h) => h.id), ['h-server']);
      expect((await database.holdingDao.getAllHoldingTransactions())
          .map((t) => t.id), ['t-server']);
      expect((await database.referenceDao.getAllSecurities())
          .map((s) => s.id), ['sec-server']);
    });
  });

  group('tag 模块', () {
    test('pending 标签 + 其本地联表 refresh 后保留;synced 标签照常重建',
        () async {
      final now = DateTime.utc(2026, 9, 4);
      await database.tagDao.insertTag(db.TagsCompanion.insert(
        id: 'tag-pending',
        name: '离线标签',
        color: '#000000',
        version: 1,
        createdAt: now,
        updatedAt: now,
        syncState: const Value(SyncState.pending),
      ));
      await database.tagDao.insertTag(db.TagsCompanion.insert(
        id: 'tag-stale',
        name: 'old',
        color: '#000000',
        version: 1,
        createdAt: now,
        updatedAt: now,
      ));
      // pending 标签 ↔ 既有交易的本地联表(local-only 数据)。
      await database.transactionDao.insertTransaction(
          db.TransactionsCompanion.insert(
        id: 't-1',
        transactionDate: now,
        description: 'x',
        version: 1,
        createdAt: now,
        updatedAt: now,
      ));
      await database.tagDao.insertTransactionTag(
          db.TransactionTagsCompanion.insert(
              transactionId: 't-1', tagId: 'tag-pending'));

      final repo = _MockTagRepo();
      when(() => repo.list()).thenAnswer((_) async => const dz.Right(
          [Tag(id: 'tag-server', name: 'server', color: '#FFFFFF', version: 1)]));
      getIt.registerSingleton<TagRepository>(repo);

      await BoundMirror(database).refreshModule(MirrorModule.tag);

      final tags = await database.tagDao.watchAllTags().first;
      expect(tags.map((t) => t.id),
          unorderedEquals(['tag-pending', 'tag-server']));
      final tagById = {for (final t in tags) t.id: t};
      expect(tagById['tag-pending']!.syncState, SyncState.pending);
      // pending 标签的本地联表保留(联表不在备份契约,仅本地语义)。
      expect(await database.tagDao.watchTagIdsForTransaction('t-1').first,
          ['tag-pending']);
    });
  });
}
