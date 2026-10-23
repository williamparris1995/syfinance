// F64-T3 TDD RED → GREEN:debts_list 只读工具(FR-2/NFR-2,ADR-8 策略 A)。
//
// 真库夹具:内存 drift 库 + DAO 直插(普通债/挂卡 card_loan/已结清/借出),
// 经**真实** DebtRepositoryImpl(guest 路由)供数 —— 工具与债务列表页同源
// (NFR-1)。ADR-8 断言组:种子库 → DebtLocalDataSource → 行映射(_toEntity)
// → Debt entity 的 nextPaymentDate / nextPaymentAmountCents /
// nextPaymentDueDate 三字段实填(card_loan 到期日 = 下一期出账日推导)。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dartz/dartz.dart' as dz;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/assistant/data/tools/debts_list_tool.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/data/debt_remote_ds.dart';
import 'package:yucai_client/debt/data/debt_repository_impl.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

class _MockDebtRemote extends Mock implements DebtRemoteDataSource {}

class _MockDebtRepo extends Mock implements DebtRepository {}

/// 测试时钟(逾期判定的「今天」,本地日界纯日期比较)。
final _fixedNow = DateTime(2026, 10, 23, 12);

void main() {
  late db.AppDatabase database;
  late DebtLocalDataSource localDs;
  late DebtRepositoryImpl repo;
  late DebtsListTool tool;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    localDs = DebtLocalDataSource(
        database, TransactionLocalDataSource(database, BalanceLocalUpdater(database)));
    repo = DebtRepositoryImpl(_MockDebtRemote(), localDs,
        SessionModeTracker()..isGuest = true);

    Future<void> seedDebt(
      String id,
      String counterparty, {
      String subtype = DebtSubtypes.creditLoan,
      int debtType = 1, // 1 = borrowedIn
      String? collectionAccountId,
    }) =>
        database.debtDao.insertDebt(db.DebtsCompanion.insert(
          id: id,
          accountId: 'acc-any',
          counterparty: counterparty,
          interestRate: 0.5,
          amortizationMethod: 1,
          startDate: DateTime.utc(2026, 8, 1),
          dueDate: DateTime.utc(2027, 8, 1),
          totalPrincipalCents: 210000,
          debtType: debtType,
          subtype: subtype,
          contact: '',
          contractRef: '',
          collectionAccountId: Value(collectionAccountId),
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

    // d1 普通借入债:下一期 2026-09-01(已过)→ overdue=true。
    await seedDebt('d1', 'Bank A');
    await seedEntry('d1', 'd1e1', DateTime.utc(2026, 9, 1), 100000);
    await seedEntry('d1', 'd1e2', DateTime.utc(2026, 12, 1), 110000);

    // d2 挂卡 card_loan:下一期出账 2026-11-01、到期 = 下期出账 2026-12-01
    // → 自由窗口,overdue=false(F58/F61 口径)。
    await seedDebt('d2', '平安银行',
        subtype: DebtSubtypes.cardLoan, collectionAccountId: 'acc-card');
    await seedEntry('d2', 'd2e1', DateTime.utc(2026, 11, 1), 120000);
    await seedEntry('d2', 'd2e2', DateTime.utc(2026, 12, 1), 130000);

    // d3 已结清(期次全付)→ 过滤出局。
    await seedDebt('d3', 'Settled Bank');
    await seedEntry('d3', 'd3e1', DateTime.utc(2026, 8, 1), 210000, paid: true);

    // d4 借出(borrowedOut)→ list(borrowedIn) 不含。
    await seedDebt('d4', 'Colleague', debtType: 2);
    await seedEntry('d4', 'd4e1', DateTime.utc(2026, 11, 1), 50000);

    tool = DebtsListTool(repo, () => _fixedNow);
  });

  tearDown(() => database.close());

  group('debts_list filtering & fields', () {
    test('unsettled borrowedIn only; settled and lent-out excluded', () async {
      final json = (await tool.execute(const {}) as ToolData).json;
      final debts = (json['debts'] as List).cast<Map<String, Object?>>();
      final parties = debts.map((d) => d['counterparty']).toSet();
      expect(parties, {'Bank A', '平安银行'}, reason: '已结清/借出不出结果');
      expect(json['totalCount'], 2);
    });

    test('per-debt fields cent-exact vs same-db schedule sums', () async {
      final json = (await tool.execute(const {}) as ToolData).json;
      final debts = (json['debts'] as List).cast<Map<String, Object?>>();

      final d1 = debts.singleWhere((d) => d['counterparty'] == 'Bank A');
      // 独立手算:未还期次本金 100000 + 110000。
      expect(d1['remainingPrincipalCents'], 210000);
      expect(d1['remainingPrincipalYuan'], '2,100.00');
      expect(d1['nextPaymentAmountCents'], 100000);
      expect(d1['nextPaymentDueDate'], '2026-09-01T00:00:00.000Z');
      expect(d1['overdue'], isTrue, reason: '下期 2026-09-01 < 今天 2026-10-23');

      final d2 = debts.singleWhere((d) => d['counterparty'] == '平安银行');
      expect(d2['remainingPrincipalCents'], 250000);
      expect(d2['nextPaymentAmountCents'], 120000);
      // card_loan 到期日 = 下一期出账日(F61),自由窗口不逾期。
      expect(d2['nextPaymentDueDate'], '2026-12-01T00:00:00.000Z');
      expect(d2['overdue'], isFalse);
    });

    test('summary: count + total remaining, dual caliber', () async {
      final json = (await tool.execute(const {}) as ToolData).json;
      final summary = json['summary'] as Map<String, Object?>;
      expect(summary['count'], 2);
      expect(summary['totalRemainingCents'], 210000 + 250000);
      expect(summary['totalRemainingYuan'], '4,600.00');
    });

    test('credit-positive invariant: every remaining principal > 0', () async {
      final json = (await tool.execute(const {}) as ToolData).json;
      final debts = (json['debts'] as List).cast<Map<String, Object?>>();
      for (final d in debts) {
        expect(d['remainingPrincipalCents'] as int, greaterThan(0),
            reason: '${d['counterparty']} 欠款必须为正(spec FR-2 场景)');
      }
    });

    test('due-date compare is date-only: same-day next payment not overdue',
        () async {
      // 重新播种:下一期 = 「今天」(2026-10-23,UTC 日界即当天)→ 不逾期。
      await database.debtDao.insertDebt(db.DebtsCompanion.insert(
        id: 'd5',
        accountId: 'acc-any',
        counterparty: 'DueToday Bank',
        interestRate: 0.5,
        amortizationMethod: 1,
        startDate: DateTime.utc(2026, 8, 1),
        dueDate: DateTime.utc(2027, 8, 1),
        totalPrincipalCents: 50000,
        debtType: 1,
        subtype: DebtSubtypes.creditLoan,
        contact: '',
        contractRef: '',
        version: 1,
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
      ));
      await database.debtDao.insertScheduleEntry(
          db.PaymentScheduleEntriesCompanion.insert(
        id: 'd5e1',
        debtId: 'd5',
        paymentDate: DateTime.utc(2026, 10, 23),
        principalCents: 50000,
        interestCents: 0,
        totalCents: 50000,
        paidCents: 0,
        paid: false,
      ));

      final json = (await tool.execute(const {}) as ToolData).json;
      final debts = (json['debts'] as List).cast<Map<String, Object?>>();
      final d5 = debts.singleWhere((d) => d['counterparty'] == 'DueToday Bank');
      expect(d5['overdue'], isFalse, reason: '纯日期比较:到期日==今天不算逾期');
    });
  });

  group('debts_list pagination (NFR-2)', () {
    test('page_size=1 → first page + total_count + hasMore', () async {
      final json = (await tool.execute({'page_size': 1}) as ToolData).json;
      expect((json['debts'] as List), hasLength(1));
      expect(json['totalCount'], 2);
      expect(json['page'], 1);
      expect(json['pageSize'], 1);
      expect(json['hasMore'], isTrue);
      expect(json['summary'], isNotNull, reason: '汇总不受分页影响(全量口径)');
    });

    test('page beyond range → empty page, summary intact', () async {
      final json = (await tool.execute({'page': 5}) as ToolData).json;
      expect((json['debts'] as List), isEmpty);
      expect(json['hasMore'], isFalse);
      expect((json['summary'] as Map<String, Object?>)['count'], 2);
    });

    test('lenient pagination coercion (page 0 / size 999 / string "2")',
        () async {
      final j = (await tool.execute({'page': 0, 'page_size': 999}) as ToolData)
          .json;
      expect(j['page'], 1);
      expect(j['pageSize'], 50);

      final j2 =
          (await tool.execute({'page': '2', 'page_size': '2'}) as ToolData).json;
      expect(j2['page'], 2);
      expect(j2['pageSize'], 2);
      expect((j2['debts'] as List), isEmpty);
    });
  });

  group('debts_list failure path', () {
    test('repository failure → ToolError, no throw', () async {
      final mock = _MockDebtRepo();
      when(() => mock.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dz.Left(UnexpectedFailure('db down')));
      final result =
          await DebtsListTool(mock, () => _fixedNow).execute(const {});
      expect(result, isA<ToolError>());
    });
  });

  group('ADR-8 strategy A: local mapper fills nextPayment* from real DB', () {
    test('entity carries nextPaymentDate/AmountCents/DueDate (card_loan '
        'derived, plain debt fallback null)', () async {
      final debts = await localDs.list(typeFilter: DebtType.borrowedIn);
      final byId = {for (final d in debts) d.id: d};

      // d2(card_loan):三字段实填;到期日 = 下期出账日 2026-12-01。
      final d2 = byId['d2']!;
      expect(d2.nextPaymentDate, DateTime.utc(2026, 11, 1));
      expect(d2.nextPaymentAmountCents, 120000);
      expect(d2.nextPaymentDueDate, DateTime.utc(2026, 12, 1),
          reason: 'ADR-8:card_loan nextPaymentDueDate 由期表推导实填');

      // d1(普通债):日期/金额实填,到期日按设计为 null(消费方回落
      // nextPaymentDate 自身 —— 工具侧已按回落口径输出)。
      final d1 = byId['d1']!;
      expect(d1.nextPaymentDate, DateTime.utc(2026, 9, 1));
      expect(d1.nextPaymentAmountCents, 100000);
      expect(d1.nextPaymentDueDate, isNull);

      // 期表口径剩余本金(d2 = 120000+130000)。
      expect(d2.remainingPrincipalCents, 250000);
    });
  });
}
