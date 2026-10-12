// TDD RED → GREEN:F9-T3 债务 DS 查询能力(list 增 searchText/sortKey/sortDir)。
//
// F9 FR-4 / ADR-3:DebtLocalDataSource.list 增可选查询参数(in-memory,默认
// 零变化 —— 不带新参数时输出与既有路径逐位一致)。实现复用 domain 纯函数
// debtSearchMatches / debtCompareQuery(debt/domain/debt_query.dart),与
// 债务/债权两页前端管道同口径。
//
// 夹具:内存 drift 库 + DS.create 建 5 笔(4 笔 borrowedIn + 1 笔
// borrowedOut),其中 1 笔经 recordPayment 还清(lumpSum 单期)做「已结清」。
import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
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

    test('序列①b:信用卡分期重构(restructureOnly)→ 跳过开账双写,余额不动',
        () async {
      // 卡余额已含分期本金(贷正 +5000),建分期债 3000:双写会让欠款翻倍,
      // restructureOnly 必须跳过 —— 余额保持 5000,无任何「借入」分录。
      await accounts.insertAccount(db.AccountsCompanion.insert(
        id: 'acc-card',
        name: 'card',
        accountType: 2,
        category: 3, // creditCard
        currencyCode: 'CNY',
        initialBalanceCents: 500000,
        currentBalanceCents: 500000,
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
      final d = await debts.create(
        accountId: 'acc-card',
        counterparty: '招行信用卡分期',
        interestRate: 0.06,
        amortizationIndex: 0, // 等额本息
        startDate: DateTime.utc(2026, 9, 22),
        dueDate: DateTime.utc(2026, 12, 22),
        totalPrincipalCents: 300000,
        type: DebtType.borrowedIn,
        subtype: DebtSubtypes.creditCard,
        termPeriods: 3,
        restructureOnly: true,
      );
      final card = (await database.accountDao.getAccountById('acc-card'))!;
      expect(card.currentBalanceCents, 500000,
          reason: '分期重构不得改卡余额(否则欠款翻倍)');
      // 无开账分录:不存在任何分录涉及该卡(setUp 种子的其它借入不受影响)。
      final cardLegs = await (database.select(database.transactionEntries)
            ..where((t) => t.accountId.equals('acc-card')))
          .get();
      expect(cardLegs, isEmpty, reason: 'restructure-only create must not post');
      // 计划已生成:3 期,供期次提醒与 RecordPayment 消费。
      final detail = await debts.get(d.id);
      expect(detail.schedule, hasLength(3));
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

  // ───────────────────────── 卡贷 F48 ─────────────────────────
  // 银行现金分期口径(e招贷/万用金):期次锚挂接卡账单日,每期 = 本金/N +
  // 固定手续费;到账单日自动 recordPayment(from: 卡)并入账单,幂等 = paid。
  group('卡贷 F48(账单日锚定 + flat 手续费 + 自动并账)', () {
    late String cardId;
    late String cardLoanAccount;

    setUp(() async {
      cardId = 'acc-cc';
      await accounts.insertAccount(db.AccountsCompanion.insert(
        id: cardId,
        name: '招行信用卡',
        accountType: 2, // liability
        category: 2, // creditCard
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
        cardNumberTail: '8888',
        notes: '',
        goldProductType: '',
        status: 1,
        version: 1,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        creditBillingDay: const Value(5),
        creditRepaymentDay: const Value(23),
      ));
      cardLoanAccount = 'acc-cardloan';
      await accounts.insertAccount(db.AccountsCompanion.insert(
        id: cardLoanAccount,
        name: 'e招贷 · 卡贷',
        accountType: 2,
        category: 7, // loan
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
    });

    Future<Debt> createCardLoan({
      required DateTime start,
      int periods = 3,
      int principal = 5000000, // ¥50,000 = 5,000,000 分
      int fee = 30000, // 每期 ¥300
      int billingDay = 5,
    }) =>
        debts.create(
          accountId: cardLoanAccount,
          counterparty: 'e招贷',
          interestRate: 0.072,
          amortizationIndex: 0,
          startDate: start,
          dueDate: start, // 按期数模式由 DS 推导覆写
          totalPrincipalCents: principal,
          type: DebtType.borrowedIn,
          subtype: DebtSubtypes.cardLoan,
          sourceAccountId: cash,
          collectionAccountId: cardId,
          cycle: 2,
          termPeriods: periods,
          billingDay: billingDay,
          flatFeeCents: fee,
        );

    test('排期锚账单日:首期=起始日后首个 5 日,每期=本金/N+固定手续费,末期吸收余数',
        () async {
      final d = await createCardLoan(start: DateTime.utc(2026, 9, 10));
      final detail = await debts.get(d.id);
      expect(
          detail.schedule.map((e) => e.paymentDate).toList(),
          [DateTime.utc(2026, 10, 5), DateTime.utc(2026, 11, 5), DateTime.utc(2026, 12, 5)],
          reason: '放款 9/10 → 首期 10/5(下一账单日),此后每月 5 日');
      // 500000/3:base=166666,末期=500000-2×166666=166668;fee=30000。
      final principals =
          detail.schedule.map((e) => e.principalCents).toList();
      expect(principals[0], 1666666);
      expect(principals[1], 1666666);
      expect(principals[2], 1666668, reason: '末期吸收取整余数,Σ本金=总额');
      for (final e in detail.schedule) {
        expect(e.interestCents, 30000, reason: '银行口径手续费按全额本金每期固定');
        expect(e.totalCents, e.principalCents + 30000);
        expect(e.paid, isFalse);
      }
      // 到期日 = 末个发生日。
      expect(detail.debt.dueDate, DateTime.utc(2026, 12, 5));
      // 放款双写:借 到账现金 / 贷 卡贷负债户(放款不直接上卡;卡额度随每期并入占用)。
      final txns =
          await database.select(database.transactions).get();
      final disburse = txns
          .firstWhere((t) => t.description == '借入 e招贷 到账');
      final legs = await legsOf(disburse.id);
      expect(legs.any((e) => e.accountId == cash && e.debitCents == 5000000),
          isTrue);
      expect(
          legs.any((e) =>
              e.accountId == cardLoanAccount && e.creditCents == 5000000),
          isTrue);
      final card =
          await accounts.getAccountById(cardId);
      expect(card!.currentBalanceCents, 0,
          reason: '放款不直接计入卡余额;卡额度随每期并入逐步占用');
    });

    test('catchup(F58 到期触发):到期(下一期出账日)已到的期次自动并入,幂等且两侧余额联动', () async {
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);
      // start = 今日-35 天,账单日 = 今日日号 → 期表 ≈ [今日-1月, 今日, 今日+1月]:
      // 首期出账 = 今日-1月,到期 = 今日(下一期出账日)→ 并入;当期今日出账,
      // 到期 = 今日+1月 → 自由窗口不并(旧「出账日即并」口径已被 F58 替换)。
      final d = await createCardLoan(
          start: today.subtract(const Duration(days: 35)), billingDay: today.day);
      await debts.catchupCardLoanMerges();
      var detail = await debts.get(d.id);
      expect(detail.schedule[0].paid, isTrue,
          reason: '首期出账 = 今日-1月,到期 = 今日 → 并入');
      expect(detail.schedule[0].transactionId.isNotEmpty, isTrue);
      expect(detail.schedule[1].paid, isFalse,
          reason: '当期今日出账,到期 = 今日+1月 → 自由窗口不并');
      expect(detail.schedule[2].paid, isFalse);
      // 并入分录:借 卡贷负债户 / 贷 信用卡(账单 + 当期本息);F36 不变式:
      // 载体余额 == 总额 − ΣpaidCents(paidCents = 期次全额)。
      final card = await accounts.getAccountById(cardId);
      expect(card!.currentBalanceCents, detail.schedule[0].totalCents,
          reason: '信用卡余额(credit-正)应含到期并入期次本息');
      final carrier = await accounts.getAccountById(cardLoanAccount);
      expect(carrier!.currentBalanceCents,
          5000000 - detail.schedule[0].totalCents,
          reason: '借记载体 → 欠款同额递减,F36 不变式保持');
      // 幂等:再跑一轮无新并入、余额不变。
      await debts.catchupCardLoanMerges();
      final card2 = await accounts.getAccountById(cardId);
      expect(card2!.currentBalanceCents, detail.schedule[0].totalCents);
      final detail2 = await debts.get(d.id);
      expect(detail2.schedule[1].paid, isFalse);
    });

    test('未到账单日的期次不并入( catchup 零动作)', () async {
      final now = DateTime.now().toUtc();
      final d = await createCardLoan(
          start: DateTime.utc(now.year, now.month, now.day));
      // 今日放款,账单日 5 日且首个 5 日必在未来(或今天=5 号时首期=今日会并入,
      // 断言宽松:所有已并入期次都 ≤ 今日)。
      await debts.catchupCardLoanMerges();
      final detail = await debts.get(d.id);
      for (final e in detail.schedule) {
        if (e.paid) {
          expect(e.paymentDate.isAfter(DateTime.now().toUtc()), isFalse);
        }
      }
      final card = await accounts.getAccountById(cardId);
      final mergedTotal = detail
          .schedule
          .where((e) => e.paid)
          .fold<int>(0, (s, e) => s + e.totalCents);
      expect(card!.currentBalanceCents, mergedTotal);
    });
  });

  // ─────────────────── F58 并账时机 = 到期日(平安口径) ───────────────────
  // 银行事实:每期独立出账(paymentDate = 出账日),到期 = 下一期出账日
  // (末期 = 自身+1 月,月钳);卡待还只含已到期未还,已出账未到期 = 自由
  // 窗口。并入条件 = 到期日 ≤ 今日(now 注入,绝对日期钉死三例)。
  group('F58 并账时机=到期日(出账日不并,到期日并)', () {
    late String cardId;
    late String cardLoanAccount;

    setUp(() async {
      cardId = 'acc-cc58';
      await accounts.insertAccount(db.AccountsCompanion.insert(
        id: cardId,
        name: '平安信用卡',
        accountType: 2, // liability
        category: 2, // creditCard
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
        cardNumberTail: '8888',
        notes: '',
        goldProductType: '',
        status: 1,
        version: 1,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ));
      cardLoanAccount = 'acc-cardloan58';
      await accounts.insertAccount(db.AccountsCompanion.insert(
        id: cardLoanAccount,
        name: '平安现金分期 · F58',
        accountType: 2,
        category: 7, // loan
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
    });

    /// billingDay 5、3 期:期表 = [2026-10-05, 2026-11-05, 2026-12-05]。
    Future<Debt> createCardLoan({DateTime? start, int billingDay = 5}) =>
        debts.create(
          accountId: cardLoanAccount,
          counterparty: '平安银行',
          interestRate: 0.072,
          amortizationIndex: 0,
          startDate: start ?? DateTime.utc(2026, 9, 10),
          dueDate: DateTime.utc(2026, 9, 10), // 按期数模式由 DS 推导覆写
          totalPrincipalCents: 5000000,
          type: DebtType.borrowedIn,
          subtype: DebtSubtypes.cardLoan,
          sourceAccountId: cash,
          collectionAccountId: cardId,
          cycle: 2,
          termPeriods: 3,
          billingDay: billingDay,
          flatFeeCents: 30000,
        );

    test('到期前不并:出账日当天/次日均为自由窗口,零并入零分录', () async {
      final d = await createCardLoan(); // 期表 [10-05, 11-05, 12-05]
      final detail0 = await debts.get(d.id);
      expect(
          detail0.schedule.map((e) => e.paymentDate).toList(),
          [DateTime.utc(2026, 10, 5), DateTime.utc(2026, 11, 5),
           DateTime.utc(2026, 12, 5)]);
      // 出账日当天(10-05):到期 = 11-05 未到 → 不并。
      await debts.catchupCardLoanMerges(now: DateTime.utc(2026, 10, 5));
      var detail = await debts.get(d.id);
      expect(detail.schedule.every((e) => !e.paid), isTrue,
          reason: '出账日当天不并(旧口径此处会并入,F58 修复点)');
      expect((await accounts.getAccountById(cardId))!.currentBalanceCents, 0);
      // 次日(10-06)仍自由窗口。
      await debts.catchupCardLoanMerges(now: DateTime.utc(2026, 10, 6));
      detail = await debts.get(d.id);
      expect(detail.schedule.every((e) => !e.paid), isTrue);
      expect((await accounts.getAccountById(cardId))!.currentBalanceCents, 0);
      // 无并入分录(只有放款双写)。
      final mergeTxns = (await database.select(database.transactions).get())
          .where((t) => t.description.startsWith('信用卡分期'));
      expect(mergeTxns, isEmpty);
    });

    test('到期日并:到期(下一期出账日)当天并入恰一期,当期新出账期次不并', () async {
      final d = await createCardLoan(); // 期表 [10-05, 11-05, 12-05]
      await debts.catchupCardLoanMerges(now: DateTime.utc(2026, 11, 5));
      final detail = await debts.get(d.id);
      expect(detail.schedule[0].paid, isTrue,
          reason: '10-05 期次到期日 = 11-05(下一期出账日)→ 当天并入');
      expect(detail.schedule[0].transactionId.isNotEmpty, isTrue);
      expect(detail.schedule[1].paid, isFalse,
          reason: '11-05 期次当日出账,到期 = 12-05 → 自由窗口不并');
      expect(detail.schedule[2].paid, isFalse);
      // 分录:贷卡(账单 + 当期本息)/ 借载体(欠款 −全额;F36 不变式)。
      final card = await accounts.getAccountById(cardId);
      expect(card!.currentBalanceCents, detail.schedule[0].totalCents);
      final carrier = await accounts.getAccountById(cardLoanAccount);
      expect(carrier!.currentBalanceCents,
          5000000 - detail.schedule[0].totalCents);
    });

    test('末期到期 = 自身+1 月(月钳 31→28):到期日当天并入', () async {
      // billingDay 31:start 11-05 → 首期 11-30(钳),此后 12-31、次年 01-31。
      final d = await createCardLoan(
          start: DateTime.utc(2026, 11, 5), billingDay: 31);
      final detail0 = await debts.get(d.id);
      expect(
          detail0.schedule.map((e) => e.paymentDate).toList(),
          [DateTime.utc(2026, 11, 30), DateTime.utc(2026, 12, 31),
           DateTime.utc(2027, 1, 31)]);
      // 12-31:期0 到期(= 12-31)并入;期1 当日出账不并;末期(01-31)
      // 到期 = +1 月钳制 = 2027-02-28,未到。
      await debts.catchupCardLoanMerges(now: DateTime.utc(2026, 12, 31));
      var detail = await debts.get(d.id);
      expect(detail.schedule[0].paid, isTrue);
      expect(detail.schedule[1].paid, isFalse);
      expect(detail.schedule[2].paid, isFalse,
          reason: '末期到期 = 2027-02-28(31→28 月钳)未到 → 不并');
      // 2027-02-28 = 末期+1 月钳制日:剩余两期全部到期并入。
      await debts.catchupCardLoanMerges(now: DateTime.utc(2027, 2, 28));
      detail = await debts.get(d.id);
      expect(detail.schedule.every((e) => e.paid), isTrue,
          reason: '末期到期日当天(= 自身+1 月钳)并入');
      final card = await accounts.getAccountById(cardId);
      expect(card!.currentBalanceCents,
          detail.schedule.fold<int>(0, (s, e) => s + e.totalCents));
    });
  });

  // ───────────────────────── F57 首期锚点 ─────────────────────────
  // 并入模式卡贷首期锚点:放款次月(现状,默认)/ 放款当期(平安口径,首期 =
  // 放款日当天)。firstPeriodFromDisbursement 是**生成期参数**(经 create 透传,
  // 物化进期表日期,不持久化为债字段);不传新参的存量路径逐位不变。
  group('F57 首期锚点(当期/次月,存量零变化)', () {
    late String cardLoanAccount;

    setUp(() async {
      cardLoanAccount = 'acc-f57';
      await accounts.insertAccount(db.AccountsCompanion.insert(
        id: cardLoanAccount,
        name: '平安卡贷 · F57',
        accountType: 2, // liability
        category: 7, // loan
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
    });

    Future<Debt> createLoan({
      required DateTime start,
      int periods = 18,
      bool firstPeriodFromDisbursement = false,
      int billingDay = 0,
    }) =>
        debts.create(
          accountId: cardLoanAccount,
          counterparty: '平安现金分期',
          interestRate: 0.072,
          amortizationIndex: 0,
          startDate: start,
          dueDate: start, // 按期数模式由 DS 推导覆写
          totalPrincipalCents: 500000, // ¥5,000
          type: DebtType.borrowedIn,
          subtype: DebtSubtypes.cardLoan,
          sourceAccountId: cash,
          cycle: 2,
          termPeriods: periods,
          billingDay: billingDay,
          flatFeeCents: 900, // 每期 ¥9
          firstPeriodFromDisbursement: firstPeriodFromDisbursement,
        );

    test('当期锚点:首期 = 放款日当天,第 18 期 = 2028-01-02(FR-2)', () async {
      final d = await createLoan(
          start: DateTime.utc(2026, 8, 2), firstPeriodFromDisbursement: true);
      final detail = await debts.get(d.id);
      final dates = detail.schedule.map((e) => e.paymentDate).toList();
      expect(dates, hasLength(18));
      expect(dates.first, DateTime.utc(2026, 8, 2),
          reason: '当期口径:首期 = 放款日当天(平安)');
      // 8/2 + 17 个月(逐月同日)= 2028-01-02。spec 场景行「第 18 期 =
      // 2027-01-02」系笔误(2027-01-02 为第 6 期);首期=start + 逐月同日
      // 的 pinned 契约不变,偏离见票内报告。
      expect(dates.last, DateTime.utc(2028, 1, 2),
          reason: '8/2 + 17 个月 = 2028-01-02');
      expect(detail.debt.dueDate, DateTime.utc(2028, 1, 2),
          reason: 'due = 末个发生日(当期参随 due 推导同一生成器)');
      // 金额口径不变:每期 = 本金/N + 固定手续费,末期吸收余数。
      expect(
          detail.schedule.fold<int>(0, (s, e) => s + e.principalCents), 500000);
      for (final e in detail.schedule) {
        expect(e.interestCents, 900);
      }
    });

    test('次月锚点(缺省不传新参):首期 = 放款日 + 1 月,与现状逐位一致', () async {
      final d = await createLoan(start: DateTime.utc(2026, 8, 2));
      final detail = await debts.get(d.id);
      final dates = detail.schedule.map((e) => e.paymentDate).toList();
      expect(dates, hasLength(18));
      expect(dates.first, DateTime.utc(2026, 9, 2),
          reason: '缺省 = 次月(现状 nextAfter 语义)');
      expect(dates.last, DateTime.utc(2028, 2, 2),
          reason: '9/2 + 17 个月(与当期口径恰差 1 期月)');
      expect(detail.debt.dueDate, DateTime.utc(2028, 2, 2));
    });

    test('月末钳制:1/31 起始当期 → 首期 1/31、次期 2/28,此后引擎 pinned 链式', () async {
      final d = await createLoan(
          start: DateTime.utc(2026, 1, 31),
          periods: 3,
          firstPeriodFromDisbursement: true);
      final detail = await debts.get(d.id);
      expect(detail.schedule.map((e) => e.paymentDate).toList(), [
        DateTime.utc(2026, 1, 31),
        DateTime.utc(2026, 2, 28),
        DateTime.utc(2026, 3, 28),
      ], reason: '后续照既有逐月推进(nextAfter 链式 byDate 月末钳制,不改引擎)');
      // 对照:同起始次月路径 = 现状原样(首期即已钳至 2/28,此后同链式)。
      final legacy =
          await createLoan(start: DateTime.utc(2026, 1, 31), periods: 3);
      expect(
          (await debts.get(legacy.id))
              .schedule
              .map((e) => e.paymentDate)
              .toList(),
          [DateTime.utc(2026, 2, 28), DateTime.utc(2026, 3, 28),
           DateTime.utc(2026, 4, 28)]);
    });

    test('存量零变化:不传新参,既有账单日锚定路径(billingDay=5)逐位不变', () async {
      final d = await createLoan(
          start: DateTime.utc(2026, 9, 10), periods: 3, billingDay: 5);
      final detail = await debts.get(d.id);
      expect(detail.schedule.map((e) => e.paymentDate).toList(), [
        DateTime.utc(2026, 10, 5),
        DateTime.utc(2026, 11, 5),
        DateTime.utc(2026, 12, 5),
      ], reason: 'F48 既有断言照抄 —— 回归钉死:分叉不动现状路径');
      expect(detail.debt.dueDate, DateTime.utc(2026, 12, 5));
    });

    test('混合形态钉死:billingDay>0 × 当期 → 首期抢先取 start,后续仍按账单日锚定链',
        () async {
      // start=8/2、billingDay=12、n=3 → [8/2, 9/12, 10/12]:首期抢在账单日
      // 系列之前取放款日当天,此后回到 rule 锚定链(逐月 12 日)。该混合形状
      // 恰为平安卡(billingDay=1)银行真值形态:首期账单 = 放款日当天,
      // 后续随账单日系列 —— 表单并入路径恒 billingDay=0,本例钉死生成器对
      // 任意 rule 的抢先语义(currentPeriod 只决定 first,不动后续链)。
      final d = await createLoan(
          start: DateTime.utc(2026, 8, 2),
          periods: 3,
          billingDay: 12,
          firstPeriodFromDisbursement: true);
      final detail = await debts.get(d.id);
      expect(detail.schedule.map((e) => e.paymentDate).toList(), [
        DateTime.utc(2026, 8, 2),
        DateTime.utc(2026, 9, 12),
        DateTime.utc(2026, 10, 12),
      ]);
      expect(detail.debt.dueDate, DateTime.utc(2026, 10, 12));
    });
  });

  group('repayBill(账单制整单还款,e招贷口径)', () {
    test('多债多期合并为单笔交易,期次批量已还,余额联动', () async {
      final list = await debts.list();
      final loanDebts = list
          .where((d) => d.accountId == 'acc-loan' && !d.subtype.contains('card'))
          .toList();
      // 取两笔未结清借入债的期次(lumpSum:各 1 期)。
      final items = <({String debtId, String entryId, int totalCents})>[];
      var total = 0;
      for (final d in loanDebts.take(2)) {
        final detail = await debts.get(d.id);
        final e = detail.schedule.where((e) => !e.paid).first;
        items.add((debtId: d.id, entryId: e.id, totalCents: e.totalCents));
        total += e.totalCents;
      }
      expect(items.length, 2);
      expect(total, 900000 + 150000);

      await debts.repayBill(
        loanAccountId: 'acc-loan',
        items: [
          for (final it in items) (debtId: it.debtId, entryId: it.entryId),
        ],
        fromAccountId: cash,
        description: '账单还款 招行e招贷',
      );

      // 单笔交易:借贷款账户/贷现金,金额 = 期次合计。
      final txns = await database.customSelect(
          "SELECT COUNT(*) c FROM transactions WHERE description = '账单还款 招行e招贷'")
          .getSingle();
      expect(txns.read<int>('c'), 1, reason: '整单还款=一笔交易');
      final loanEntry = await database.customSelect(
          "SELECT debit_cents d, credit_cents c FROM transaction_entries "
          "WHERE account_id = 'acc-loan' AND transaction_id IN "
          "(SELECT id FROM transactions WHERE description = '账单还款 招行e招贷')")
          .getSingle();
      expect(loanEntry.read<int>('d'), total);
      expect(loanEntry.read<int>('c'), 0);

      // 期次全部已还并挂同一交易。
      for (final it in items) {
        final row = await database.customSelect(
            'SELECT paid, paid_cents, transaction_id FROM payment_schedule_entries WHERE id = ?',
            variables: [Variable.withString(it.entryId)]).getSingle();
        expect(row.read<bool>('paid'), isTrue);
        expect(row.read<int>('paid_cents'), it.totalCents);
        expect(row.read<String>('transaction_id'), isNotNull);
      }

      // 余额:贷款账户 credit-正口径递减,现金同额流出。
      final loan = await accounts.getAccountById('acc-loan');
      final cashRow = await accounts.getAccountById(cash);
      // 建债时放款已贷记账户(6,250,000) - settle 5,000,000 - 本单 1,050,000
      // = 200,000(credit-正,剩余未还的 d3 Bank B)。
      expect(loan!.currentBalanceCents, 200000, reason: 'credit-正:整单还款后剩未还期次');
            // cash 期初 100 万 - settle 5,000,000 - 本单 1,050,000。
      expect(cashRow!.currentBalanceCents, 100000000 - 5000000 - total);
    });

    test('已还期次拒绝;空单拒绝', () async {
      const items = <({String debtId, String entryId})>[];
      await expectLater(
          debts.repayBill(
              loanAccountId: 'acc-loan', items: items, fromAccountId: cash),
          throwsA(isA<ValidationFailure>()));
    });
  });

  // ───────── F50 卡贷额度占用债级开关(写侧) ─────────
  // create/update 透传 countsTowardCardLimit 落本地私有列,读侧经 _toEntity
  // 透出(Task A 已落);默认 true(既有调用点/旧行为不变)。
  group('F50 countsTowardCardLimit 写侧', () {
    test('create 传 false 落库,读侧透出 false;缺省 true', () async {
      final off = await debts.create(
        accountId: 'acc-loan',
        counterparty: '备用金分期',
        interestRate: 0,
        amortizationIndex: 0,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2027, 1, 1),
        totalPrincipalCents: 600000,
        type: DebtType.borrowedIn,
        subtype: 'card_loan',
        collectionAccountId: 'acc-cash',
        countsTowardCardLimit: false,
      );
      expect((await debts.get(off.id)).debt.countsTowardCardLimit, isFalse);
      // 行内私有列同步落 false(非仅 entity 层兜底)。
      final row = await database.debtDao.getDebtById(off.id);
      expect(row!.countsTowardCardLimit, isFalse);

      // 缺省(既有调用点不传)= true。
      final on = await debts.create(
        accountId: 'acc-loan',
        counterparty: '占额分期',
        interestRate: 0,
        amortizationIndex: 0,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2027, 1, 1),
        totalPrincipalCents: 600000,
        type: DebtType.borrowedIn,
        subtype: 'card_loan',
        collectionAccountId: 'acc-cash',
      );
      expect((await debts.get(on.id)).debt.countsTowardCardLimit, isTrue);
    });

    test('update 传 false 落库(编辑切换开关后保存)', () async {
      final d = await debts.create(
        accountId: 'acc-loan',
        counterparty: 'e招贷',
        interestRate: 0,
        amortizationIndex: 0,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2027, 1, 1),
        totalPrincipalCents: 600000,
        type: DebtType.borrowedIn,
        subtype: 'card_loan',
        collectionAccountId: 'acc-cash',
      );
      expect((await debts.get(d.id)).debt.countsTowardCardLimit, isTrue);
      final updated = await debts.update(
        id: d.id,
        counterparty: 'e招贷',
        interestRate: 0,
        version: d.version,
        subtype: 'card_loan',
        collectionAccountId: 'acc-cash',
        countsTowardCardLimit: false,
      );
      expect(updated.countsTowardCardLimit, isFalse);
      expect((await database.debtDao.getDebtById(d.id))!.countsTowardCardLimit,
          isFalse,
          reason: '编辑保存后本地私有列须落新值');
    });
  });

  // ───────── F49-T7 债删自动关户(FR-5,TDD) ─────────
  //
  // 语义:card_loan 债删除清账后,其载体户若 isSystem=true(并入模式载体)、
  // currentBalanceCents==0、名下无其他 debt_type=1 借入债 → 经 AccountCloser
  // port 自动置 status=关闭(AccountStatus.archived,与既有「关闭账户」同源,
  // 存库值 2);任一不满足 no-op。独立账单模式账户(isSystem=false)天然挡。
  // fee=0 使清偿数学透明:全额还清 → remaining=0 → 无清账分录,载体余额恰 0。
  group('F49-T7 债删自动关户(FR-5)', () {
    late DebtLocalDataSource ds;
    const carrier = 'acc-f49-carrier';
    const card = 'acc-f49-card';
    // AccountStatus.archived.index + 1(关闭与既有 close 路径同源)。
    const statusClosed = 2;

    setUp(() async {
      ds = DebtLocalDataSource(
        database,
        TransactionLocalDataSource(database, BalanceLocalUpdater(database)),
        closer: AccountCloserImpl(database),
      );

      Future<void> seedAccount(
        String id,
        String name, {
        required bool isSystem,
        required int initialBalanceCents,
        int? billingDay,
      }) =>
          accounts.insertAccount(db.AccountsCompanion.insert(
            id: id,
            name: name,
            accountType: 2, // liability
            category: isSystem ? 7 : 2, // loan 载体 / creditCard 独立账户
            currencyCode: 'CNY',
            initialBalanceCents: initialBalanceCents,
            currentBalanceCents: initialBalanceCents,
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
            creditBillingDay: billingDay == null
                ? const Value.absent()
                : Value(billingDay),
          ));

      // 挂接信用卡(并入模式的 collection 目标,真实账户永隐藏免疫)。
      await seedAccount(card, 'F49挂接卡',
          isSystem: false, initialBalanceCents: 0, billingDay: 5);
      // 并入模式载体户:isSystem=true。
      await seedAccount(carrier, '平安 · 卡贷',
          isSystem: true, initialBalanceCents: 0);
    });

    /// 建并入型卡贷(fee=0,全额还清后载体恰归零)并全额还清。
    Future<String> createAndRepayCardLoan({String? collectionId}) async {
      final d = await ds.create(
        accountId: carrier,
        counterparty: '平安银行',
        interestRate: 0,
        amortizationIndex: 0,
        startDate: DateTime.utc(2026, 1, 10),
        dueDate: DateTime.utc(2026, 1, 10), // 按期数模式由 DS 推导覆写
        totalPrincipalCents: 100000, // ¥1,000 = 100,000 分
        type: DebtType.borrowedIn,
        subtype: DebtSubtypes.cardLoan,
        sourceAccountId: cash,
        collectionAccountId: collectionId,
        cycle: 2,
        termPeriods: 2,
        billingDay: 5,
        flatFeeCents: 0,
      );
      final detail = await ds.get(d.id);
      for (final e in detail.schedule) {
        await ds.recordPayment(
            debtId: d.id,
            scheduleEntryId: e.id,
            fromAccountId: collectionId ?? cash);
      }
      return d.id;
    }

    test('并入型债全额清偿(载体 0)删除 → 载体户自动关闭', () async {
      final debtId = await createAndRepayCardLoan(collectionId: card);
      final before = await accounts.getAccountById(carrier);
      expect(before!.currentBalanceCents, 0,
          reason: '全额清偿后载体余额应恰为 0(前置)');

      await ds.delete(debtId);

      expect(await database.debtDao.getDebtById(debtId), isNull);
      final after = await accounts.getAccountById(carrier);
      expect(after!.status, statusClosed,
          reason: 'FR-5:并入型载体户清偿归零后应自动关闭');
      expect(after.currentBalanceCents, 0, reason: '关闭不动余额(账务零改动)');
    });

    test('载体非零(历史残留余额)→ 删除后不关', () async {
      // 载体带与债无关的历史残留余额 5,000 分:清偿后余额 = 残留 ≠ 0。
      await (database.update(database.accounts)
            ..where((a) => a.id.equals(carrier)))
          .write(const db.AccountsCompanion(
              currentBalanceCents: Value(5000)));
      final debtId = await createAndRepayCardLoan(collectionId: card);
      final before = await accounts.getAccountById(carrier);
      expect(before!.currentBalanceCents, 5000,
          reason: '残留余额不受清偿影响(前置)');

      await ds.delete(debtId);

      final after = await accounts.getAccountById(carrier);
      expect(after!.status, 1, reason: '余额非零 → 不得自动关闭');
      expect(after.currentBalanceCents, 5000, reason: '余额不受删除影响');
    });

    test('独立账单模式账户(即使清零)→ 不关(isSystem=false 天然挡)', () async {
      // 独立账单真实账户:isSystem=false(建户置位规则 FR-1 天然不置),
      // 债务无 collectionAccountId;带账单日(e招贷型标志)。
      await (database.update(database.accounts)
            ..where((a) => a.id.equals(carrier)))
          .write(const db.AccountsCompanion(
              isSystem: Value(false), creditBillingDay: Value(28)));
      final debtId = await createAndRepayCardLoan();
      final before = await accounts.getAccountById(carrier);
      expect(before!.isSystem, isFalse);
      expect(before.currentBalanceCents, 0, reason: '已清零(前置)');

      await ds.delete(debtId);

      final after = await accounts.getAccountById(carrier);
      expect(after!.status, 1,
          reason: 'FR-5:独立账单真实账户留用户处置,永不自动关闭');
    });
  });
}
