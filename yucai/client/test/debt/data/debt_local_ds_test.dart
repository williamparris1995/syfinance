// TDD RED → GREEN:F9-T3 债务 DS 查询能力(list 增 searchText/sortKey/sortDir)。
//
// F9 FR-4 / ADR-3:DebtLocalDataSource.list 增可选查询参数(in-memory,默认
// 零变化 —— 不带新参数时输出与既有路径逐位一致)。实现复用 domain 纯函数
// debtSearchMatches / debtCompareQuery(debt/domain/debt_query.dart),与
// 债务/债权两页前端管道同口径。
//
// 夹具:内存 drift 库 + DS.create 建 5 笔(4 笔 borrowedIn + 1 笔
// borrowedOut),其中 1 笔经 recordPayment 还清(lumpSum 单期)做「已结清」。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:yucai_client/core/error/failures.dart';
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

// ───────── 周期规则(类 Google Calendar)用例 ─────────

  group('recurrence rule', () {
    test('create 每周 4 期 → 期次日期按周分布,due 取末位', () async {
      final d = await debts.create(
        accountId: 'acc-loan',
        counterparty: '周供贷',
        interestRate: 0.12,
        amortizationIndex: 0, // annuity
        startDate: DateTime.utc(2026, 1, 5), // 周一
        dueDate: DateTime.utc(2026, 1, 5), // term 模式忽略
        totalPrincipalCents: 400000,
        type: DebtType.borrowedIn,
        cycle: 1, // weekly
        weekdayMask: 1, // 周一
        termPeriods: 4,
      );
      final detail = await debts.get(d.id);
      expect(detail.schedule, hasLength(4));
      expect(
        detail.schedule
            .map((e) => e.paymentDate.toIso8601String().substring(0, 10)),
        ['2026-01-12', '2026-01-19', '2026-01-26', '2026-02-02'],
      );
      expect(d.dueDate.toIso8601String().substring(0, 10), '2026-02-02');
      final principal =
          detail.schedule.fold(0, (a, e) => a + e.principalCents);
      expect(principal, 400000);
    });

    test('markEntryPaid 产生结转分录,债务账户余额同步下降', () async {
      final d = await debts.create(
        accountId: 'acc-loan',
        counterparty: '历史贷',
        interestRate: 0,
        amortizationIndex: 1,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2026, 4, 1),
        totalPrincipalCents: 300000,
        type: DebtType.borrowedIn,
        sourceAccountId: 'acc-cash', // 到账 → 债务户入账
      );
      final before = await database.accountDao.getAccountById('acc-loan');
      final detail = await debts.get(d.id);

      final got = await debts.markEntryPaid(
        debtId: d.id,
        entryId: detail.schedule.first.id,
      );
      expect(got.paid, isTrue);
      expect(got.transactionId, ''); // 不关联真实记账交易

      // 结转分录存在(描述 + 两腿平衡)。
      final txns = await database.select(database.transactions).get();
      final settle = txns
          .firstWhere((t) => t.description == '标记已还 历史贷');
      // 债务账户余额下降(负债减少)。
      final after = await database.accountDao.getAccountById('acc-loan');
      expect(after!.currentBalanceCents,
          before!.currentBalanceCents - detail.schedule.first.totalCents);
      // 期次冻结。
      final afterDetail = await debts.get(d.id);
      expect(afterDetail.schedule.first.paid, isTrue);
    });

    test('setPaymentDate 单期改日 + 冻结/撞日拒绝', () async {
      final d = await debts.create(
        accountId: 'acc-loan',
        counterparty: '改日贷',
        interestRate: 0,
        amortizationIndex: 1,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2026, 4, 1),
        totalPrincipalCents: 400000,
        type: DebtType.borrowedIn,
      );
      final detail = await debts.get(d.id);
      final entry = detail.schedule[1]; // 2026-02-01

      // 正常改日:02-01 → 02-10。
      final got = await debts.setPaymentDate(
        debtId: d.id,
        entryId: entry.id,
        paymentDate: DateTime.utc(2026, 2, 10),
      );
      expect(got.paymentDate.toIso8601String().substring(0, 10), '2026-02-10');
      final after = await debts.get(d.id);
      expect(after.schedule[1].paymentDate.toIso8601String().substring(0, 10),
          '2026-02-10');

      // 冻结:第 1 期已还 → 拒绝。
      await (database.update(database.paymentScheduleEntries)
            ..where((t) => t.id.equals(detail.schedule[0].id)))
          .write(db.PaymentScheduleEntriesCompanion(paid: const Value(true)));
      expect(
        () => debts.setPaymentDate(
            debtId: d.id,
            entryId: detail.schedule[0].id,
            paymentDate: DateTime.utc(2026, 3, 15)),
        throwsA(isA<ServerFailure>()),
      );

      // 撞日:改到第 2 期已占用的 02-10 → 拒绝。
      expect(
        () => debts.setPaymentDate(
            debtId: d.id,
            entryId: detail.schedule[2].id,
            paymentDate: DateTime.utc(2026, 2, 10)),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('recordPayment 描述包含对手方名称(非 Closure 残渣)', () async {
      final d = await debts.create(
        accountId: 'acc-loan',
        counterparty: '招商银行',
        interestRate: 0,
        amortizationIndex: 1,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2026, 4, 1),
        totalPrincipalCents: 300000,
        type: DebtType.borrowedIn,
      );
      final detail = await debts.get(d.id);
      final got = await debts.recordPayment(
        debtId: d.id,
        scheduleEntryId: detail.schedule.first.id,
        fromAccountId: 'acc-cash',
      );
      expect(got.id, isNotEmpty);
      final txns = await database.select(database.transactions).get();
      final desc = txns
          .firstWhere((t) => t.id == got.transactionId)
          .description;
      expect(desc, '还款 招商银行');
      expect(desc.contains('Closure'), isFalse);
    });

    test('update 规则变化 → 已还期次冻结,未来按剩余本金重排', () async {
      final d = await debts.create(
        accountId: 'acc-loan',
        counterparty: '月供贷',
        interestRate: 0,
        amortizationIndex: 1, // equalPrincipal
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2026, 7, 1),
        totalPrincipalCents: 600000,
        type: DebtType.borrowedIn,
      );
      final created = await debts.get(d.id);
      expect(created.schedule, hasLength(6)); // legacy 月差期数

      // 冻结前两期(直接落 paid 标记,模拟已还款)。
      for (var i = 0; i < 2; i++) {
        await (database.update(database.paymentScheduleEntries)
              ..where((t) => t.id.equals(created.schedule[i].id)))
            .write(db.PaymentScheduleEntriesCompanion(
          paid: const Value(true),
          paidCents: Value(created.schedule[i].totalCents),
          transactionId: const Value('txn-frozen'),
        ));
      }

      await debts.update(
        id: d.id,
        counterparty: '月供贷',
        interestRate: 0,
        version: d.version,
        cycle: 1, // 改为每周
        weekdayMask: 1, // 周一
        termPeriods: 3, // 剩余 3 期
      );

      final detail = await debts.get(d.id);
      // 冻结两期原样保留(日期不变、paid 保持)。
      final frozen = detail.schedule.take(2).toList();
      expect(frozen[0].paymentDate.toIso8601String().substring(0, 10),
          '2026-02-01');
      expect(frozen[0].paid, isTrue);
      // 未来 3 期:锚点 2026-03-01 之后的首个周一是 03-02;剩余本金 40 万。
      final future = detail.schedule.skip(2).toList();
      expect(future, hasLength(3));
      expect(future[0].paymentDate.toIso8601String().substring(0, 10),
          '2026-03-02');
      final futurePrincipal = future.fold(0, (a, e) => a + e.principalCents);
      expect(futurePrincipal, 400000);
    });
  });

  // ───────── F33-T4:update 链透传 subtype(空串 = 不修改) ─────────

  group('F33-T4 update subtype', () {
    test('非空 subtype 变更行内列;空串不修改(守卫在 DS 层)', () async {
      final d = await debts.create(
        accountId: 'acc-loan',
        counterparty: '子类型贷',
        interestRate: 0,
        amortizationIndex: 1,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2026, 4, 1),
        totalPrincipalCents: 300000,
        type: DebtType.borrowedIn,
        subtype: 'mortgage',
      );

      // 非空 → 行内 subtype 变更。
      final changed = await debts.update(
        id: d.id,
        counterparty: '子类型贷',
        interestRate: 0,
        version: d.version,
        subtype: 'credit_card',
      );
      expect(changed.subtype, 'credit_card');
      final row = await database.debtDao.getDebtById(d.id);
      expect(row!.subtype, 'credit_card');

      // 空串 → 不修改(保持 credit_card,不清洗为 '')。
      final kept = await debts.update(
        id: d.id,
        counterparty: '子类型贷',
        interestRate: 0,
        version: changed.version,
        subtype: '',
      );
      expect(kept.subtype, 'credit_card');
    });
  });

  // ───────── F36-T1 负债记账不变式(北极星,TDD) ─────────
  //
  // 不变式:任意操作序列后,负债账户 currentBalanceCents ==
  // −Σ(该户名下 borrowedIn 债 remaining)(显示口径:欠款为负)。
  // 本系统存储口径为「负债贷正」(BalanceLocalUpdater 镜像 server
  // ApplyEntryDelta:liability → credit − debit),故真实余额断言取
  // 贷正号:balance == Σ remaining,remaining =
  // totalPrincipalCents − Σ(entry.paidCents)(与 _toEntity 同式)。
  // 助手经真实记账管道(BalanceLocalUpdater)后读 accounts 表断言。

  Future<int> paidSumOf(String debtId) async {
    final schedule = await database.debtDao.getScheduleByDebt(debtId);
    return schedule.fold<int>(0, (a, e) => a + e.paidCents);
  }

  Future<void> expectLiabilityInvariant() async {
    final rows = await database.debtDao.watchAllDebts().first;
    final remainingByAccount = <String, int>{};
    for (final r in rows) {
      if (r.debtType != DebtType.borrowedIn.index + 1) continue;
      final remaining = r.totalPrincipalCents - await paidSumOf(r.id);
      remainingByAccount.update(r.accountId, (v) => v + remaining,
          ifAbsent: () => remaining);
    }
    for (final e in remainingByAccount.entries) {
      final acc = await database.accountDao.getAccountById(e.key);
      expect(acc, isNotNull, reason: 'liability account ${e.key} missing');
      // 贷正存储口径:欠款 = +Σremaining(显示口径 −Σremaining 的镜像)。
      expect(acc!.currentBalanceCents, e.value,
          reason: 'INVARIANT VIOLATED [account=${acc.name} id=${acc.id}] '
              'balance=${acc.currentBalanceCents} '
              'expected=+Σremaining=${e.value} '
              '(display convention: -${e.value})');
    }
  }

  /// 系统权益户「历史还款结转」(type=3 equity,幂等兜底户)。
  Future<db.Account> settlementAccount() async {
    final all = await database.select(database.accounts).get();
    return all
        .firstWhere((a) => a.name == '历史还款结转' && a.accountType == 3);
  }

  Future<List<db.TransactionEntry>> legsOf(String txnId) =>
      (database.select(database.transactionEntries)
            ..where((t) => t.transactionId.equals(txnId)))
          .get();

  group('F36-T1 负债分录缺口(不变式 TDD)', () {
    test('序列①:无到账创建 → 借权益/贷负债入账,不变式成立', () async {
      final loanBefore =
          (await database.accountDao.getAccountById('acc-loan'))!;
      // 权益户相对值(setUp 的无到账种子已先产生结转余额)。
      final settlementEarly = await settlementAccount();
      final equityBefore =
          (await database.accountDao.getAccountById(settlementEarly.id))!;
      final d = await debts.create(
        accountId: 'acc-loan',
        counterparty: '无到账贷',
        interestRate: 0,
        amortizationIndex: 2,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2027, 1, 1),
        totalPrincipalCents: 250000,
        type: DebtType.borrowedIn,
        // sourceAccountId 缺省 = 缺口场景(ADR-4:债「从历史而来」)。
      );
      expect(d.id, isNotEmpty);

      // 北极星不变式(先断言 → RED 时输出余额 vs −Σremaining)。
      await expectLiabilityInvariant();

      // 权益结转分录存在:借 权益 +P / 贷 债务户 +P。
      final settlement = await settlementAccount();
      final txns = await database.select(database.transactions).get();
      final post = txns
          .firstWhere((t) => t.description == '借入 无到账贷(无到账)');
      final legs = await legsOf(post.id);
      expect(
          legs.any((e) =>
              e.accountId == settlement.id && e.debitCents == 250000),
          isTrue,
          reason: 'equity leg missing: debit settlement +P');
      expect(
          legs.any(
              (e) => e.accountId == 'acc-loan' && e.creditCents == 250000),
          isTrue,
          reason: 'liability leg missing: credit debt +P');

      // 余额联动(贷正存储口径):债务户 +P,权益户 −P(相对值)。
      final loanAfter =
          (await database.accountDao.getAccountById('acc-loan'))!;
      expect(loanAfter.currentBalanceCents,
          loanBefore.currentBalanceCents + 250000);
      final equity =
          await database.accountDao.getAccountById(settlement.id);
      expect(equity!.currentBalanceCents,
          equityBefore.currentBalanceCents - 250000);
    });

    test('序列②:创建(有到账)→ 还一期 → 改总额 ±Δ 调整分录,不变式成立',
        () async {
      final d = await debts.create(
        accountId: 'acc-loan',
        counterparty: '改额贷',
        interestRate: 0,
        amortizationIndex: 1, // equalPrincipal 6 期
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2026, 7, 1),
        totalPrincipalCents: 1000000,
        type: DebtType.borrowedIn,
        sourceAccountId: 'acc-cash', // 有到账 → 借 到账/贷 负债(既有行为)
      );
      final detail = await debts.get(d.id);
      await debts.recordPayment(
        debtId: d.id,
        scheduleEntryId: detail.schedule.first.id,
        fromAccountId: 'acc-cash',
      );

      // 改总额 Δ=+5,000,000 → 同事务调整分录:贷 负债 Δ / 借 权益 Δ。
      final grown = await debts.update(
        id: d.id,
        counterparty: '改额贷',
        interestRate: 0,
        version: d.version,
        totalPrincipalCents: 6000000,
      );
      expect(grown.totalPrincipalCents, 6000000);
      final settlement = await settlementAccount();
      var txns = await database.select(database.transactions).get();
      final growPosts =
          txns.where((t) => t.description == '调整本金 改额贷').toList();
      expect(growPosts, hasLength(1));
      final growLegs = await legsOf(growPosts.single.id);
      expect(
          growLegs.any(
              (e) => e.accountId == 'acc-loan' && e.creditCents == 5000000),
          isTrue,
          reason: 'Δ>0 must credit debt account');
      expect(
          growLegs.any((e) =>
              e.accountId == settlement.id && e.debitCents == 5000000),
          isTrue,
          reason: 'Δ>0 must debit settlement equity');
      await expectLiabilityInvariant();

      // 改总额 Δ=−2,000,000 → 反向调整分录:借 负债 |Δ| / 贷 权益 |Δ|。
      final shrunk = await debts.update(
        id: d.id,
        counterparty: '改额贷',
        interestRate: 0,
        version: grown.version,
        totalPrincipalCents: 4000000,
      );
      expect(shrunk.totalPrincipalCents, 4000000);
      txns = await database.select(database.transactions).get();
      final shrinkPosts =
          txns.where((t) => t.description == '调整本金 改额贷').toList();
      expect(shrinkPosts, hasLength(2));
      final shrinkLegs = await legsOf(shrinkPosts[1].id);
      expect(
          shrinkLegs.any(
              (e) => e.accountId == 'acc-loan' && e.debitCents == 2000000),
          isTrue,
          reason: 'Δ<0 must debit debt account');
      expect(
          shrinkLegs.any((e) =>
              e.accountId == settlement.id && e.creditCents == 2000000),
          isTrue,
          reason: 'Δ<0 must credit settlement equity');
      await expectLiabilityInvariant();
    });

    test('序列③:部分还款后删除 → 清账分录,历史现金流不动,不变式成立',
        () async {
      final d = await debts.create(
        accountId: 'acc-loan',
        counterparty: '删债贷',
        interestRate: 0,
        amortizationIndex: 1,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2026, 7, 1),
        totalPrincipalCents: 600000,
        type: DebtType.borrowedIn,
      );
      final detail = await debts.get(d.id);
      final payTxnId = (await debts.recordPayment(
        debtId: d.id,
        scheduleEntryId: detail.schedule.first.id,
        fromAccountId: 'acc-cash',
      ))
          .transactionId;

      await debts.delete(d.id);
      expect(await database.debtDao.getDebtById(d.id), isNull);

      // 北极星不变式(删除后其余债不受影响)。
      await expectLiabilityInvariant();

      // 清账分录:借 债务户 剩余(600,000−100,000)/ 贷 权益。
      final settlement = await settlementAccount();
      final txns = await database.select(database.transactions).get();
      final clear =
          txns.firstWhere((t) => t.description == '删除清账 删债贷');
      final legs = await legsOf(clear.id);
      expect(
          legs.any(
              (e) => e.accountId == 'acc-loan' && e.debitCents == 500000),
          isTrue,
          reason: 'clearing debit leg missing: debit debt remaining');
      expect(
          legs.any((e) =>
              e.accountId == settlement.id && e.creditCents == 500000),
          isTrue,
          reason: 'clearing credit leg missing: credit settlement');

      // 历史现金流分录不冲回(还款交易仍在)。
      expect(txns.any((t) => t.id == payTxnId), isTrue,
          reason: 'historical cashflow entries must survive delete');
    });

    test('剩余为 0 删除 → 无清账分录', () async {
      // setUp 里 Settled Bank 已全额还清(rate 0 → remaining = 0)。
      final settled = (await debts.list(searchText: 'Settled Bank')).single;
      final before = await database.select(database.transactions).get();
      await debts.delete(settled.id);
      final after = await database.select(database.transactions).get();
      expect(after.length, before.length,
          reason: 'fully-paid delete must not post a clearing entry');
    });

    test('borrowedOut 删除维持现状(无清账分录,应收余额不动)', () async {
      final out = await debts.create(
        accountId: 'acc-recv',
        counterparty: '删债权',
        interestRate: 0,
        amortizationIndex: 2,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2027, 1, 1),
        totalPrincipalCents: 300000,
        type: DebtType.borrowedOut,
        sourceAccountId: 'acc-cash',
      );
      final recvBefore =
          (await database.accountDao.getAccountById('acc-recv'))!;

      await debts.delete(out.id);

      final recvAfter =
          (await database.accountDao.getAccountById('acc-recv'))!;
      expect(recvAfter.currentBalanceCents, recvBefore.currentBalanceCents);
      final txns = await database.select(database.transactions).get();
      expect(txns.where((t) => t.description == '删除清账 删债权'), isEmpty);
    });

    test('含息全额还清后删除(remaining<0)→ 反向清账,不变式成立', () async {
      final d = await debts.create(
        accountId: 'acc-loan',
        counterparty: '含息贷',
        interestRate: 0.12,
        amortizationIndex: 2, // lumpSum 单期
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2027, 1, 1),
        totalPrincipalCents: 200000,
        type: DebtType.borrowedIn,
      );
      final entry = (await database.debtDao.getScheduleByDebt(d.id)).single;
      expect(entry.totalCents, 224000); // 本金 200,000 + 利息 24,000
      await debts.recordPayment(
          debtId: d.id, scheduleEntryId: entry.id, fromAccountId: 'acc-cash');

      // 删除前不变式已成立(含息超还 → 账户贷差 = 利息)。
      await expectLiabilityInvariant();

      await debts.delete(d.id);
      expect(await database.debtDao.getDebtById(d.id), isNull);

      // 反向清账:贷 债务户 |remaining|=24,000 / 借 权益 24,000。
      final settlement = await settlementAccount();
      final txns = await database.select(database.transactions).get();
      final clear =
          txns.firstWhere((t) => t.description == '删除清账 含息贷');
      final legs = await legsOf(clear.id);
      expect(
          legs.any(
              (e) => e.accountId == 'acc-loan' && e.creditCents == 24000),
          isTrue,
          reason: 'negative-remaining must credit the debt account');
      expect(
          legs.any((e) =>
              e.accountId == settlement.id && e.debitCents == 24000),
          isTrue,
          reason: 'negative-remaining must debit settlement');
      await expectLiabilityInvariant();
    });
  });
}
