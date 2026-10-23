// F64-T3 TDD RED → GREEN:accounts_list 只读工具(FR-2/NFR-2,载体户口径)。
//
// 真库夹具:内存 drift 库 + DAO 直插(账户含 isSystem 载体户/信用卡;债务含
// 挂卡 card_loan 期表),经**真实** AccountRepositoryImpl / DebtRepositoryImpl
// (guest 路由)供数 —— 工具读的就是 UI 同一条本地读路径(NFR-1)。
// 占用口径 = debt/domain/debt_query.cardLoanOccupationCents(F50/F58 未出账
// 口径,accounts_page 同款);期望值由测试**独立手算**(不调用工具实现)。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dartz/dartz.dart' as dz;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/assistant/data/tools/accounts_list_tool.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/data/debt_remote_ds.dart';
import 'package:yucai_client/debt/data/debt_repository_impl.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

class _MockAccountRemote extends Mock implements AccountRemoteDataSource {}

class _MockDebtRemote extends Mock implements DebtRemoteDataSource {}

/// 测试时钟(占用口径「未出账」分界,UTC 日界)。
final _fixedNow = DateTime.utc(2026, 10, 23, 4); // 2026-10-23(UTC)

void main() {
  late db.AppDatabase database;
  late AccountRepository accountsRepo;
  late DebtRepository debtsRepo;
  late AccountsListTool tool;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    final tracker = SessionModeTracker()..isGuest = true;
    accountsRepo = AccountRepositoryImpl(
      _MockAccountRemote(),
      AccountLocalDataSource(database),
      tracker,
    );
    debtsRepo = DebtRepositoryImpl(
      _MockDebtRemote(),
      DebtLocalDataSource(
          database, TransactionLocalDataSource(database, BalanceLocalUpdater(database))),
      tracker,
    );

    // ── 账户种子(DAO 直插;enum int = index+1)──
    Future<void> seedAccount(
      String id,
      String name, {
      required int type,
      required int category,
      required int balance,
      int limitCents = 0,
      bool isSystem = false,
    }) =>
        database.accountDao.insertAccount(db.AccountsCompanion.insert(
          id: id,
          name: name,
          accountType: type,
          category: category,
          currencyCode: 'CNY',
          initialBalanceCents: balance,
          currentBalanceCents: balance,
          ownership: 1,
          icon: '',
          color: '',
          chartCode: '',
          isSystem: isSystem,
          sortOrder: 0,
          institution: '',
          cardNumberTail: '',
          notes: '',
          goldProductType: '',
          status: 1,
          version: 1,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
          creditLimitCents: Value(limitCents),
        ));

    await seedAccount('acc-cash', '现金', type: 1, category: 1, balance: 1234567);
    await seedAccount('acc-card', '招行信用卡',
        type: 2, category: 2, balance: 500500, limitCents: 5000000);
    // F49 载体户:isSystem=true —— 展示/助手出局,净资产照计。
    await seedAccount('acc-carrier', '平安卡贷载体',
        type: 2, category: 6, balance: 250000, isSystem: true);

    // ── 债务种子(挂卡 card_loan × 2 + 普通债)──
    Future<void> seedDebt(
      String id, {
      String subtype = DebtSubtypes.cardLoan,
      String? collectionAccountId,
      bool countsTowardCardLimit = true,
    }) =>
        database.debtDao.insertDebt(db.DebtsCompanion.insert(
          id: id,
          accountId: 'acc-carrier',
          counterparty: 'counterparty-$id',
          interestRate: 0.5,
          amortizationMethod: 1,
          startDate: DateTime.utc(2026, 8, 1),
          dueDate: DateTime.utc(2027, 8, 1),
          totalPrincipalCents: 600000,
          debtType: 1,
          subtype: subtype,
          contact: '',
          contractRef: '',
          collectionAccountId: Value(collectionAccountId),
          countsTowardCardLimit: Value(countsTowardCardLimit),
          version: 1,
          createdAt: DateTime.utc(2026, 8, 1),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));

    Future<void> seedEntry(
      String debtId,
      String id,
      DateTime date,
      int principal, {
      bool paid = false,
    }) =>
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

    await seedDebt('d-card1', collectionAccountId: 'acc-card');
    // d-card1 期表:已还过去 + 已出账未还(不占)+ 两期未出账(占)。
    await seedEntry('d-card1', 'e1', DateTime.utc(2026, 8, 1), 100000, paid: true);
    await seedEntry('d-card1', 'e2', DateTime.utc(2026, 9, 1), 110000);
    await seedEntry('d-card1', 'e3', DateTime.utc(2026, 11, 1), 120000);
    await seedEntry('d-card1', 'e4', DateTime.utc(2026, 12, 1), 130000);

    // 开关关的挂卡卡贷:F50 债级开关置关 → 不占额度。
    await seedDebt('d-card2',
        collectionAccountId: 'acc-card', countsTowardCardLimit: false);
    await seedEntry('d-card2', 'e5', DateTime.utc(2026, 11, 1), 99000);

    tool = AccountsListTool(accountsRepo, debtsRepo, () => _fixedNow);
  });

  tearDown(() => database.close());

  group('accounts_list visibility & summary', () {
    test('carrier account excluded from items and total_count', () async {
      final result = await tool.execute(const {});
      final json = (result as ToolData).json;
      final accounts = (json['accounts'] as List).cast<Map<String, Object>>();

      expect(json['totalCount'], 2, reason: '载体户不计 total_count');
      final names = accounts.map((a) => a['name']).toSet();
      expect(names, {'现金', '招行信用卡'}, reason: '载体户不在结果(spec FR-2 场景)');
      // 载体户的卡贷余额也不得混进分组小计(分组只算可见户)。
      final groups = (json['groups'] as List).cast<Map<String, Object>>();
      final liability = groups.singleWhere((g) => g['type'] == 'liability');
      expect(liability['count'], 1);
      expect(liability['subtotalCents'], 500500);
    });

    test('groups subtotals match same-db direct sums, cent-exact', () async {
      final json = (await tool.execute(const {}) as ToolData).json;
      // 同库直查:drift 原行按 accountType 求和(isSystem 户被排除 —— 与
      // AccountVisibility 同判据的独立重算)。
      final rows = await database.accountDao.getAllAccounts();
      final expectAsset = rows
          .where((r) => !r.isSystem && r.accountType == 1)
          .fold(0, (s, r) => s + r.currentBalanceCents);
      final expectLiability = rows
          .where((r) => !r.isSystem && r.accountType == 2)
          .fold(0, (s, r) => s + r.currentBalanceCents);

      final groups = (json['groups'] as List).cast<Map<String, Object>>();
      expect(groups.firstWhere((g) => g['type'] == 'asset')['subtotalCents'],
          expectAsset);
      expect(groups.firstWhere((g) => g['type'] == 'liability')['subtotalCents'],
          expectLiability);
      expect(groups.firstWhere((g) => g['type'] == 'asset')['subtotalYuan'],
          '12,345.67');
      expect(groups.firstWhere((g) => g['type'] == 'liability')['subtotalYuan'],
          '5,005.00');
    });
  });

  group('accounts_list credit card occupation (F50 口径)', () {
    test('used = card debt + unbilled occupation of attached card loans',
        () async {
      final json = (await tool.execute(const {}) as ToolData).json;
      final accounts = (json['accounts'] as List).cast<Map<String, Object>>();
      final card =
          accounts.singleWhere((a) => a['name'] == '招行信用卡');

      // 独立手算:e3+e4(d-card1,开关开,未出账)= 120000+130000;
      // e5 属开关关的 d-card2 → 不计;e2 已出账 → 不计;e1 已还 → 不计。
      const expectedOccupation = 120000 + 130000;
      expect(card['usedCents'], 500500 + expectedOccupation);
      expect(card['usedYuan'], '7,505.00');
      expect(card['availableCents'], 5000000 - 500500 - expectedOccupation);
      expect(card['availableYuan'], '42,495.00');
      expect(card['limitCents'], 5000000);
      // 评审 fixlist L3:limitCents 配对 limitYuan(金额字段双口径)。
      expect(card['limitYuan'], '50,000.00');

      // 非信用卡户无卡字段。
      final cash = accounts.singleWhere((a) => a['name'] == '现金');
      expect(cash.containsKey('usedCents'), isFalse);
    });
  });

  group('accounts_list kind filter', () {
    test('kind=asset narrows items/groups/totalCount', () async {
      final json = (await tool.execute({'kind': 'asset'}) as ToolData).json;
      final accounts = (json['accounts'] as List).cast<Map<String, Object>>();
      expect(json['totalCount'], 1);
      expect(accounts, hasLength(1));
      expect(accounts.single['name'], '现金');
      final groups = (json['groups'] as List).cast<Map<String, Object>>();
      expect(groups, hasLength(1));
      expect(groups.single['type'], 'asset');
    });

    test('invalid kind → self-correcting ToolError listing legal values',
        () async {
      final result = await tool.execute({'kind': 'credit'});
      expect(result, isA<ToolError>());
      final msg = (result as ToolError).message;
      expect(msg, contains('credit'));
      for (final legal in [
        'asset',
        'liability',
        'equity',
        'income',
        'expense'
      ]) {
        expect(msg, contains(legal));
      }
    });

    test('kind case/whitespace tolerated (lenient)', () async {
      final json =
          (await tool.execute({'kind': ' Asset '}) as ToolData).json;
      expect(json['totalCount'], 1);
    });
  });

  group('accounts_list pagination (lenient, NFR-2)', () {
    test('page beyond range → empty items, totalCount intact, hasMore=false',
        () async {
      final json = (await tool.execute({'page': 9}) as ToolData).json;
      expect((json['accounts'] as List), isEmpty);
      expect(json['totalCount'], 2);
      expect(json['hasMore'], isFalse);
    });

    test('page_size=1 → single item + hasMore=true + page echo', () async {
      final json = (await tool.execute({'page_size': 1}) as ToolData).json;
      final accounts = (json['accounts'] as List).cast<Map<String, Object>>();
      expect(accounts, hasLength(1));
      expect(json['totalCount'], 2);
      expect(json['page'], 1);
      expect(json['pageSize'], 1);
      expect(json['hasMore'], isTrue);
    });

    test('lenient coercion: page 0 → 1, page_size 999 → 50, "2" → 2',
        () async {
      final j0 = (await tool.execute({'page': 0, 'page_size': 999}) as ToolData)
          .json;
      expect(j0['page'], 1);
      expect(j0['pageSize'], 50);

      final j1 = (await tool.execute({'page': '2', 'page_size': '2'}) as ToolData)
          .json;
      expect(j1['page'], 2);
      expect(j1['pageSize'], 2);
      expect(j1['totalCount'], 2);
      expect((j1['accounts'] as List), isEmpty); // 第 2 页×每页 2 = 越界
      expect(j1['hasMore'], isFalse);
    });

    test('zero-result kind (equity) → empty but well-formed', () async {
      final json = (await tool.execute({'kind': 'equity'}) as ToolData).json;
      expect(json['totalCount'], 0);
      expect((json['accounts'] as List), isEmpty);
      expect((json['groups'] as List), isEmpty);
      expect(json['hasMore'], isFalse);
    });
  });

  group('accounts_list review fixlist guards', () {
    test('M2: legalKinds alignment guard vs AccountType values (drift = red)',
        () async {
      // parametersSchema 的 const enum 需要编译期常量,legalKinds 只能是
      // AccountType 值域的硬编码副本 —— 本守卫钉死两者逐项一致,枚举
      // 增删/改名而副本未跟随时即红。
      expect(AccountsListTool.legalKinds,
          [for (final t in AccountType.values) t.name]);
    });

    test('L2: debt list fetched once per execute across cards', () async {
      final accounts = _MockAccountRepo();
      Account card(String id, String name) => Account(
            id: id,
            name: name,
            accountType: AccountType.liability,
            category: AccountCategory.creditCard,
            currencyCode: 'CNY',
            initialBalanceCents: 0,
            currentBalanceCents: 100000,
            ownership: Ownership.personal,
            status: AccountStatus.active,
            creditLimitCents: 500000,
          );
      when(() => accounts.list()).thenAnswer(
          (_) async => dz.Right([card('c1', 'card one'), card('c2', 'card two')]));

      Debt cardLoan(String id, String cardId) => Debt(
            id: id,
            accountId: 'acc-any',
            counterparty: 'cp-$id',
            interestRate: 0,
            amortization: AmortizationMethod.equalPrincipalInterest,
            startDate: DateTime.utc(2026, 1, 1),
            dueDate: DateTime.utc(2027, 1, 1),
            totalPrincipalCents: 100000,
            remainingPrincipalCents: 100000,
            version: 1,
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
            subtype: DebtSubtypes.cardLoan,
            collectionAccountId: cardId,
          );
      final debts = _MockDebtRepo();
      when(() => debts.list(typeFilter: any(named: 'typeFilter'))).thenAnswer(
          (_) async => dz.Right([cardLoan('d1', 'c1'), cardLoan('d2', 'c2')]));
      when(() => debts.get(any())).thenAnswer((inv) async => dz.Right(DebtDetail(
          debt: cardLoan(inv.positionalArguments[0] as String, 'c1'),
          schedule: [
            PaymentEntry(
              id: 'e-${inv.positionalArguments[0]}',
              paymentDate: DateTime.utc(2026, 12, 1), // 未出账(> fixedNow)
              principalCents: 50000,
              interestCents: 0,
              totalCents: 50000,
              paid: false,
              paidCents: 0,
              transactionId: '',
            )
          ])));

      final json = (await AccountsListTool(accounts, debts, () => _fixedNow)
              .execute(const {}) as ToolData)
          .json;
      final items = (json['accounts'] as List).cast<Map<String, Object?>>();
      expect(items, hasLength(2));
      // 两卡占用均生效(每卡一笔挂卡未出账期次 50000)。
      for (final item in items) {
        expect(item['usedCents'], 100000 + 50000, reason: '${item['name']}');
      }
      // L2 核心:整页只拉一次借入债列表(不逐卡重拉);期表逐债 get。
      verify(() => debts.list(typeFilter: any(named: 'typeFilter')))
          .called(1);
      verify(() => debts.get(any())).called(2);
    });
  });

  group('accounts_list failure path', () {
    test('repository failure → ToolError, no throw', () async {
      final repo = _MockAccountRepo();
      when(() => repo.list())
          .thenAnswer((_) async => const dz.Left(UnexpectedFailure('db down')));
      final failing = AccountsListTool(repo, debtsRepo, () => _fixedNow);
      final result = await failing.execute(const {});
      expect(result, isA<ToolError>());
    });
  });
}

class _MockAccountRepo extends Mock implements AccountRepository {}

class _MockDebtRepo extends Mock implements DebtRepository {}
