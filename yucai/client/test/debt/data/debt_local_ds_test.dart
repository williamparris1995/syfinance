// TDD RED → GREEN:F9-T3 债务 DS 查询能力(list 增 searchText/sortKey/sortDir)。
//
// F9 FR-4 / ADR-3:DebtLocalDataSource.list 增可选查询参数(in-memory,默认
// 零变化 —— 不带新参数时输出与既有路径逐位一致)。实现复用 domain 纯函数
// debtSearchMatches / debtCompareQuery(debt/domain/debt_query.dart),与
// 债务/债权两页前端管道同口径。
//
// 夹具:内存 drift 库 + DS.create 建 5 笔(4 笔 borrowedIn + 1 笔
// borrowedOut),其中 1 笔经 recordPayment 还清(lumpSum 单期)做「已结清」。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/account_dao.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/domain/debt_query.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

void main() {
  late db.AppDatabase database;
  late DebtLocalDataSource debts;
  late AccountDao accounts;
  String cash = '';

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    final txns =
        TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    debts = DebtLocalDataSource(database, txns);
    accounts = database.accountDao;

    Future<String> seedAccount(String name, int type, int balance) async {
      final id = 'acc-$name';
      await accounts.insertAccount(db.AccountsCompanion.insert(
        id: id,
        name: name,
        accountType: type,
        category: type == 2 ? 9 : 1, // liability→otherLiability;asset→savings
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

    cash = await seedAccount('cash', 1, 100000000); // ¥100 万
    final loan = await seedAccount('loan', 2, 0);
    final recv = await seedAccount('recv', 1, 0);

    Future<Debt> seed(
      String counterparty,
      int total,
      DateTime due, {
      DebtType type = DebtType.borrowedIn,
    }) =>
        debts.create(
          accountId: type == DebtType.borrowedIn ? loan : recv,
          counterparty: counterparty,
          interestRate: 0,
          amortizationIndex: 2, // lumpSum:单期 @dueDate,便于全额还清
          startDate: DateTime.utc(2026, 1, 1),
          dueDate: due,
          totalPrincipalCents: total,
          type: type,
        );

    await seed('Bank A', 900000, DateTime.utc(2027, 1, 1)); // d1 大
    await seed('招商银行', 150000, DateTime.utc(2028, 6, 1)); // d2 中
    await seed('Bank B', 200000, DateTime.utc(2026, 10, 1)); // d3 小
    // settled:到期最早但已结清(验证默认序沉底)。
    final s = await seed('Settled Bank', 5000000, DateTime.utc(2025, 1, 1));
    final entry = (await database.debtDao.getScheduleByDebt(s.id)).single;
    await debts.recordPayment(
        debtId: s.id, scheduleEntryId: entry.id, fromAccountId: cash);
    // 债权方向(borrowedOut):验证 typeFilter 与查询参数正交。
    await seed('朋友', 300000, DateTime.utc(2027, 5, 1),
        type: DebtType.borrowedOut);
  });

  tearDown(() => database.close());

  List<String> ids(List<Debt> list) => list.map((d) => d.counterparty).toList();

  group('F9-T3 默认路径(NFR-2 零变化)', () {
    test('不带新参数:全部返回,保持 DAO 行序(与既有路径逐位一致)', () async {
      final legacy = await debts.list();
      final again = await debts.list(typeFilter: null);
      expect(legacy, hasLength(5));
      expect(ids(again), ids(legacy));
      // 行序 = 插入序(Settled Bank 已还清但不沉底 —— 排序仅在新参数显式
      // 传入时应用,默认路径零变化)。
      expect(ids(legacy), ['Bank A', '招商银行', 'Bank B', 'Settled Bank', '朋友']);
    });
  });

  group('F9-T3 searchText(counterparty contains 忽略大小写)', () {
    test('英文小写查询命中大写对手方', () async {
      final r = await debts.list(searchText: 'bank a');
      expect(ids(r), ['Bank A']);
    });

    test('中文片段命中', () async {
      final r = await debts.list(searchText: '招商');
      expect(ids(r), ['招商银行']);
    });

    test('未命中空集;空白不过滤', () async {
      expect(ids(await debts.list(searchText: 'zzz')), isEmpty);
      expect(await debts.list(searchText: '  '), hasLength(5));
    });
  });

  group('F9-T3 sortKey/sortDir 四态', () {
    // borrowedIn 子集(默认序 = 未结清在前 + 到期升序)。
    Future<List<Debt>> borrowedIn(
            {DebtSortKey? key, DebtSortDir? dir}) =>
        debts.list(
            typeFilter: DebtType.borrowedIn, sortKey: key, sortDir: dir);

    test('金额降序:totalPrincipalCents 大→小(已结清不分组)', () async {
      final r = await borrowedIn(
          key: DebtSortKey.amount, dir: DebtSortDir.desc);
      expect(ids(r), ['Settled Bank', 'Bank A', 'Bank B', '招商银行']);
    });

    test('金额升序:小→大', () async {
      final r = await borrowedIn(key: DebtSortKey.amount, dir: DebtSortDir.asc);
      expect(ids(r), ['招商银行', 'Bank B', 'Bank A', 'Settled Bank']);
    });

    test('到期日降序:晚→早', () async {
      final r =
          await borrowedIn(key: DebtSortKey.dueDate, dir: DebtSortDir.desc);
      expect(ids(r), ['招商银行', 'Bank A', 'Bank B', 'Settled Bank']);
    });

    test('到期日升序(默认序):未结清在前 + 到期升序,已结清沉底', () async {
      final sorted =
          await borrowedIn(key: DebtSortKey.dueDate, dir: DebtSortDir.asc);
      expect(ids(sorted), ['Bank B', 'Bank A', '招商银行', 'Settled Bank']);
    });
  });

  group('F9-T3 组合:typeFilter × searchText × sort', () {
    test('债权方向 + 搜索 + 金额排序正交叠加', () async {
      // 再补一笔债权,使「金额降序」有区分度。
      await debts.create(
        accountId: 'acc-recv',
        counterparty: 'Zhang San',
        interestRate: 0,
        amortizationIndex: 2,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2027, 5, 1),
        totalPrincipalCents: 800000,
        type: DebtType.borrowedOut,
      );
      final r = await debts.list(
        typeFilter: DebtType.borrowedOut,
        sortKey: DebtSortKey.amount,
        sortDir: DebtSortDir.desc,
      );
      expect(ids(r), ['Zhang San', '朋友']);
      // 搜索再收窄。
      final r2 = await debts.list(
        typeFilter: DebtType.borrowedOut,
        searchText: 'zhang',
        sortKey: DebtSortKey.amount,
        sortDir: DebtSortDir.desc,
      );
      expect(ids(r2), ['Zhang San']);
    });
  });
}
