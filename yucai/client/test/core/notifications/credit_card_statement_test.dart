// CreditCardStatementDue 单测(T7 账单口径):上期账单剩余应还推导的口径钉死:
// 账单日后消费剔除、还款分录不进 Δ(剩余口径 = 账单 − 账单日后已还款)、
// clamp 0、账单日 null 降级、跨月/跨年 clamp、账单日当天消费归本期(F61 拍板 A)
// (date > D 严格)、空交易 Δ=0、时钟注入。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/repairs.dart'
    show seedGfBillingTransitionOverride;
import 'package:yucai_client/core/notifications/credit_card_statement.dart';

void main() {
  late db.AppDatabase database;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedCard(
    String id, {
    int balanceCents = 500000,
    int? billingDay,
  }) async {
    await database.into(database.accounts).insert(
          db.AccountsCompanion.insert(
            id: id,
            name: id,
            accountType: 2, // liability
            category: 2, // credit_card
            currencyCode: 'CNY',
            initialBalanceCents: 0,
            currentBalanceCents: balanceCents,
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
            creditBillingDay: billingDay == null
                ? const Value<int>.absent()
                : Value<int>(billingDay),
          ),
        );
  }

  /// 一笔分录(消费=credit 正,还款=debit 负;按负债方向在推导内解释)。
  Future<void> seedEntry(
    String id,
    String accountId,
    DateTime date, {
    int debit = 0,
    int credit = 0,
    String description = 'fixture',
  }) async {
    await database.into(database.transactions).insert(
          db.TransactionsCompanion.insert(
            id: 't-$id',
            transactionDate: date,
            description: description,
            version: 1,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
    await database.into(database.transactionEntries).insert(
          db.TransactionEntriesCompanion.insert(
            id: 'e-$id',
            transactionId: 't-$id',
            accountId: accountId,
            chartOfAccountCode: '',
            debitCents: debit,
            creditCents: credit,
            note: '',
          ),
        );
  }

  // 时钟钉死 2026-09-23:本月账单日 15 已过 → D = 2026-09-15。
  DateTime clock() => DateTime(2026, 9, 23, 10);

  test('账单日后消费剔除:应还 = 当前欠款 − 本周期消费(未来分录与他卡分录不计)', () async {
    await seedCard('c1', balanceCents: 500000, billingDay: 15);
    await seedEntry('pre', 'c1', DateTime(2026, 9, 10), credit: 100000); // 账单内
    await seedEntry('cycle', 'c1', DateTime(2026, 9, 18), credit: 80000); // 本周期
    await seedEntry('future', 'c1', DateTime(2026, 9, 24), credit: 90000); // 未来
    await seedEntry('other-card', 'other', DateTime(2026, 9, 18), credit: 70000);

    final due = await CreditCardStatementDue.compute(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 500000,
      billingDay: 15,
      clock: clock,
    );
    // Δ = 本周期消费 80000(未来/他卡不计)→ 应还 420000,而非总欠款 500000。
    expect(due, 420000);
  });

  test('还款分录不进 Δ:应还只减正向消费,还款不当消费重复扣(剩余口径)', () async {
    await seedCard('c1', balanceCents: 500000, billingDay: 15);
    await seedEntry('spend', 'c1', DateTime(2026, 9, 18), credit: 80000);
    await seedEntry('repay', 'c1', DateTime(2026, 9, 20), debit: 30000);

    final due = await CreditCardStatementDue.compute(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 500000,
      billingDay: 15,
      clock: clock,
    );
    // Δ 只含正向消费 80000 → 应还 420000(旧净额口径会得 450000,已废弃;
    // 那会把账单后已还部分加回应还)。
    expect(due, 420000);
  });

  test('部分还款后剩余口径:账单 3000、还 1000、再刷 500 → 应还 2000', () async {
    // current = statement − R + S = 3000 − 1000 + 500 = 2500;
    // 剩余应还 = statement − R = current − S = 2500 − 500 = 2000。
    await seedCard('c1', balanceCents: 250000, billingDay: 15);
    await seedEntry('repay', 'c1', DateTime(2026, 9, 18), debit: 100000);
    await seedEntry('spend', 'c1', DateTime(2026, 9, 20), credit: 50000);

    final due = await CreditCardStatementDue.compute(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 250000,
      billingDay: 15,
      clock: clock,
    );
    // 旧净额口径得 3000(账单历史原额,把已还 1000 加回)→ 错;正确 2000。
    expect(due, 200000);
  });

  test('应还 clamp 0:本周期消费超过当前欠款不产生负数', () async {
    await seedCard('c1', balanceCents: 100000, billingDay: 15);
    await seedEntry('spend', 'c1', DateTime(2026, 9, 18), credit: 300000);

    final due = await CreditCardStatementDue.compute(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 100000,
      billingDay: 15,
      clock: clock,
    );
    expect(due, 0);
  });

  test('账单日未设 → 降级 = 当前总欠款(与旧行为一致)', () async {
    await seedCard('c1', balanceCents: 500000);
    // 即使有本周期消费也无关:降级路径不查分录。
    await seedEntry('spend', 'c1', DateTime(2026, 9, 18), credit: 80000);

    final due = await CreditCardStatementDue.compute(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 500000,
      billingDay: null,
      clock: clock,
    );
    expect(due, 500000);
  });

  test('跨月 clamp:本月账单日未过 → 取上月账单日(31 在 2 月 clamp 到 28)', () async {
    // 时钟 2026-03-20,账单日 31:本月 03-31 未过 → D = 2026-02-28。
    DateTime clock() => DateTime(2026, 3, 20, 9);
    await seedCard('c1', balanceCents: 500000, billingDay: 31);
    await seedEntry('pre', 'c1', DateTime(2026, 2, 20), credit: 100000); // 账单内
    // 恰在 clamp 后的账单日 02-28 当天 → 归本期(F61 拍板 A:当天进新区间)。
    await seedEntry('on-d', 'c1', DateTime(2026, 2, 28), credit: 50000);
    await seedEntry('cycle', 'c1', DateTime(2026, 3, 5), credit: 70000); // 本周期

    final due = await CreditCardStatementDue.compute(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 500000,
      billingDay: 31,
      clock: clock,
    );
    // Δ = 70000+50000(02-28 当天属本期,拍板 A)→ 应还 380000。
    expect(due, 380000);
  });

  test('跨年:1 月账单日未过 → 取上年 12 月账单日', () async {
    DateTime clock() => DateTime(2026, 1, 10, 9);
    await seedCard('c1', balanceCents: 200000, billingDay: 20);
    await seedEntry('cycle', 'c1', DateTime(2025, 12, 25), credit: 60000);

    final due = await CreditCardStatementDue.compute(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 200000,
      billingDay: 20,
      clock: clock,
    );
    // D = 2025-12-20,Δ = 60000 → 应还 140000。
    expect(due, 140000);
  });

  test('账单日当天消费归本期:F61 拍板 A(当天进新区间)', () async {
    await seedCard('c1', balanceCents: 400000, billingDay: 15);
    await seedEntry('on-d', 'c1', DateTime(2026, 9, 15), credit: 60000);
    await seedEntry('after', 'c1', DateTime(2026, 9, 16), credit: 50000);

    final due = await CreditCardStatementDue.compute(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 400000,
      billingDay: 15,
      clock: clock,
    );
    // Δ = 60000+50000(09-15 当天属本期,拍板 A)→ 应还 290000。
    expect(due, 290000);
  });

  test('空交易(纯手工余额):Δ = 0 → 应还 = 当前欠款', () async {
    await seedCard('c1', balanceCents: 500000, billingDay: 15);

    final due = await CreditCardStatementDue.compute(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 500000,
      billingDay: 15,
      clock: clock,
    );
    expect(due, 500000);
  });

  test('只读推导:计算后余额与分录原样不动', () async {
    await seedCard('c1', balanceCents: 500000, billingDay: 15);
    await seedEntry('cycle', 'c1', DateTime(2026, 9, 18), credit: 80000);

    await CreditCardStatementDue.compute(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 500000,
      billingDay: 15,
      clock: clock,
    );

    final acc = await (database.select(database.accounts)
          ..where((t) => t.id.equals('c1')))
        .getSingle();
    expect(acc.currentBalanceCents, 500000);
    final entries = await database.select(database.transactionEntries).get();
    expect(entries, hasLength(1));
  });

  // ───── T8 breakdown():账单周期四值拆解 ─────
  //
  // 面板数据源:billingDate(D)/上期账单/上期已还 R/本期账单 S/上期剩余。
  // 口径:current = statement − R + S → statement = current − S + R;
  // remaining = max(0, current − S)(= compute 现值,委托等价另测)。

  test('breakdown 四值:账单 3000、还 1000、再刷 500 → 3000/1000/500/2000', () async {
    // current = 3000 − 1000 + 500 = 2500(250000 分)。
    await seedCard('c1', balanceCents: 250000, billingDay: 15);
    await seedEntry('repay', 'c1', DateTime(2026, 9, 18), debit: 100000);
    await seedEntry('spend', 'c1', DateTime(2026, 9, 20), credit: 50000);

    final b = await CreditCardStatementDue.breakdown(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 250000,
      billingDay: 15,
      clock: clock,
    );

    expect(b, isNotNull, reason: '账单日已设 → breakdown 非 null');
    expect(b!.billingDate, DateTime(2026, 9, 15), reason: 'D = 本月已过账单日');
    expect(b.statementCents, 300000, reason: '上期账单 = current − S + R');
    expect(b.repaidSinceCents, 100000, reason: '上期已还 = 账单日后还款绝对值和');
    expect(b.cycleNewCents, 50000, reason: '本期账单(未出账)= 账单日后消费和');
    expect(b.remainingCents, 200000, reason: '上期剩余 = max(0, current − S)');
  });

  test('breakdown 多笔混合:R/S 各自累加(账单日后两还两刷)', () async {
    await seedCard('c1', balanceCents: 260000, billingDay: 15);
    await seedEntry('repay1', 'c1', DateTime(2026, 9, 16), debit: 30000);
    await seedEntry('repay2', 'c1', DateTime(2026, 9, 20), debit: 70000);
    await seedEntry('spend1', 'c1', DateTime(2026, 9, 17), credit: 20000);
    await seedEntry('spend2', 'c1', DateTime(2026, 9, 22), credit: 60000);
    await seedEntry('pre', 'c1', DateTime(2026, 9, 10), credit: 99000); // 账单内

    final b = (await CreditCardStatementDue.breakdown(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 260000,
      billingDay: 15,
      clock: clock,
    ))!;

    expect(b.repaidSinceCents, 100000, reason: 'R = 30000 + 70000');
    expect(b.cycleNewCents, 80000, reason: 'S = 20000 + 60000(账单内不计)');
    expect(b.statementCents, 280000, reason: '上期账单 = 260000 − 80000 + 100000');
    expect(b.remainingCents, 180000, reason: '剩余 = max(0, 260000 − 80000)');
  });

  test('breakdown 不变式(未钳零):current == remaining + cycleNew 且 statement − repaid == remaining', () async {
    // 随机形状:current 334000、R 90000、S 210000(未触钳零)。
    await seedCard('c1', balanceCents: 334000, billingDay: 15);
    await seedEntry('repay', 'c1', DateTime(2026, 9, 16), debit: 90000);
    await seedEntry('spend', 'c1', DateTime(2026, 9, 20), credit: 210000);

    final b = (await CreditCardStatementDue.breakdown(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 334000,
      billingDay: 15,
      clock: clock,
    ))!;

    // 钳零前不变式(此处未钳零,remaining 即未钳值):分解后重组回 current。
    expect(b.remainingCents + b.cycleNewCents, 334000,
        reason: '不变式:current == remaining + cycleNew');
    expect(b.statementCents - b.repaidSinceCents, b.remainingCents,
        reason: '不变式:statement − repaid == remaining(剩余 = 账单 − 已还)');
  });

  test('breakdown 全还款:上期账单已还清 → 剩余 0,本期另刷独立成 S', () async {
    // statement 3000 全还 + 再刷 500 → current = 3000 − 3000 + 500 = 500。
    await seedCard('c1', balanceCents: 50000, billingDay: 15);
    await seedEntry('repay-all', 'c1', DateTime(2026, 9, 18), debit: 300000);
    await seedEntry('spend', 'c1', DateTime(2026, 9, 20), credit: 50000);

    final b = (await CreditCardStatementDue.breakdown(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 50000,
      billingDay: 15,
      clock: clock,
    ))!;

    expect(b.statementCents, 300000, reason: '账单原额还原 = current − S + R');
    expect(b.repaidSinceCents, 300000);
    expect(b.remainingCents, 0, reason: '全还 → 剩余 0(边界,不触发钳零)');
    expect(b.cycleNewCents, 50000);
  });

  test('breakdown 钳零边界:本期消费 > 欠款 → 剩余钳 0,公式其余值照推', () async {
    // current 100000、S 300000(手工调余额等异常形状)→ 未钳剩余 = −200000。
    await seedCard('c1', balanceCents: 100000, billingDay: 15);
    await seedEntry('spend', 'c1', DateTime(2026, 9, 18), credit: 300000);

    final b = (await CreditCardStatementDue.breakdown(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 100000,
      billingDay: 15,
      clock: clock,
    ))!;

    expect(b.remainingCents, 0, reason: '剩余钳 0(与 compute clamp 同口径)');
    expect(b.cycleNewCents, 300000);
    expect(b.repaidSinceCents, 0);
    // 上期账单按公式直出(此形状下可为负,纯推导不钳;展示层罕见形状)。
    expect(b.statementCents, -200000);
    // 钳零后不变式不再成立(正是边界):remaining + cycleNew != current。
    expect(b.remainingCents + b.cycleNewCents, isNot(100000));
  });

  test('breakdown 空交易:纯手工余额 → 四值退化(账单=剩余=current,R=S=0)', () async {
    await seedCard('c1', balanceCents: 500000, billingDay: 15);

    final b = (await CreditCardStatementDue.breakdown(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 500000,
      billingDay: 15,
      clock: clock,
    ))!;

    expect(b.billingDate, DateTime(2026, 9, 15));
    expect(b.statementCents, 500000);
    expect(b.repaidSinceCents, 0);
    expect(b.cycleNewCents, 0);
    expect(b.remainingCents, 500000);
  });

  test('breakdown 账单日未设 → null(降级路径:无周期可分)', () async {
    await seedCard('c1', balanceCents: 500000);

    final b = await CreditCardStatementDue.breakdown(
      db: database,
      accountId: 'c1',
      accountType: 2,
      currentBalanceCents: 500000,
      billingDay: null,
      clock: clock,
    );

    expect(b, isNull, reason: '账单日未设 → breakdown null(compute 降级 current)');
  });

  test('compute 委托等价:compute() == breakdown().remainingCents(含钳零)', () async {
    // 形状一:常规(250000 − S 50000 = 200000)。
    await seedCard('c1', balanceCents: 250000, billingDay: 15);
    await seedEntry('repay', 'c1', DateTime(2026, 9, 18), debit: 100000);
    await seedEntry('spend', 'c1', DateTime(2026, 9, 20), credit: 50000);
    final due1 = await CreditCardStatementDue.compute(
      db: database, accountId: 'c1', accountType: 2,
      currentBalanceCents: 250000, billingDay: 15, clock: clock,
    );
    final b1 = await CreditCardStatementDue.breakdown(
      db: database, accountId: 'c1', accountType: 2,
      currentBalanceCents: 250000, billingDay: 15, clock: clock,
    );
    expect(due1, b1!.remainingCents);

    // 形状二:钳零(S > current)。
    await seedCard('c2', balanceCents: 100000, billingDay: 15);
    await seedEntry('spend2', 'c2', DateTime(2026, 9, 18), credit: 300000);
    final due2 = await CreditCardStatementDue.compute(
      db: database, accountId: 'c2', accountType: 2,
      currentBalanceCents: 100000, billingDay: 15, clock: clock,
    );
    final b2 = await CreditCardStatementDue.breakdown(
      db: database, accountId: 'c2', accountType: 2,
      currentBalanceCents: 100000, billingDay: 15, clock: clock,
    );
    expect(due2, b2!.remainingCents);
    expect(due2, 0);

    // 形状三:账单日未设 → compute 降级 current,breakdown null。
    await seedCard('c3', balanceCents: 500000);
    final due3 = await CreditCardStatementDue.compute(
      db: database, accountId: 'c3', accountType: 2,
      currentBalanceCents: 500000, billingDay: null, clock: clock,
    );
    final b3 = await CreditCardStatementDue.breakdown(
      db: database, accountId: 'c3', accountType: 2,
      currentBalanceCents: 500000, billingDay: null, clock: clock,
    );
    expect(due3, 500000);
    expect(b3, isNull);
  });

  test('退款净额口径:描述含「退款」的负项冲减本期消费,不虚增已还', () async {
    await seedCard('c1', balanceCents: 53500, billingDay: 15);
    await seedEntry('spend', 'c1', DateTime(2026, 9, 18), credit: 80000);
    await seedEntry('refund', 'c1', DateTime(2026, 9, 20),
        debit: 2650, description: '武汉协和医院(挂号费退款)');
    await seedEntry('repay', 'c1', DateTime(2026, 9, 21),
        debit: 24000, description: '信用卡还款 广发银行(通联)');

    final b = await CreditCardStatementDue.breakdown(
      db: database, accountId: 'c1', accountType: 2,
      currentBalanceCents: 53500, billingDay: 15, clock: clock,
    );
    // 本期 = 消费 80000 − 退款 2650 = 77350(净额,银行口径);
    // 已还只含还款 24000,退款不混入。
    expect(b!.cycleNewCents, 77350);
    expect(b.repaidSinceCents, 24000);
    expect(b.remainingCents, 53500 - 77350 < 0 ? 0 : 53500 - 77350);
    expect(b.statementCents, 53500 - 77350 + 24000);
  });

  // ───── 账单日变更过渡覆盖(2026-10-20 广发 19→6 定案) ─────
  group('过渡覆盖', () {
    Future<void> seedOverride(String accountId,
        {required DateTime start, required DateTime next}) async {
      await database.into(database.cardBillingCycleOverrides).insert(
            db.CardBillingCycleOverridesCompanion.insert(
              accountId: accountId,
              cycleStart: start,
              nextBillingDate: next,
            ),
          );
    }

    test('命中:当期 = [cycleStart, nextBillingDate),上期账单已还清 → 应还 0',
        () async {
      await seedCard('gf', balanceCents: 300000, billingDay: 6);
      // 广发实证形状:9 月账单([cycleStart 前消费 50000)已由 9/19 还款结清;
      // 9/19 起为新周期(拍板 A:起点当天归本周期)。余额 = 50000+300000−50000。
      await seedEntry('pre', 'gf', DateTime(2026, 9, 10), credit: 50000);
      await seedEntry('repay', 'gf', DateTime(2026, 9, 19), debit: 50000);
      await seedEntry('s1', 'gf', DateTime(2026, 9, 20), credit: 200000);
      await seedEntry('s2', 'gf', DateTime(2026, 10, 19), credit: 100000);
      await seedOverride('gf',
          start: DateTime.utc(2026, 9, 19), next: DateTime.utc(2026, 11, 6));

      final b = await CreditCardStatementDue.breakdown(
        db: database, accountId: 'gf', accountType: 2,
        currentBalanceCents: 300000, billingDay: 6,
        clock: () => DateTime(2026, 10, 20, 10),
      );
      expect(b!.billingDate, DateTime(2026, 9, 19),
          reason: '过渡窗口起点 = 上一张真实账单日,非固定日 10/06');
      expect(b.cycleNewCents, 300000, reason: '本期 = 9/19 起全部消费');
      expect(b.repaidSinceCents, 50000, reason: '9/19 还款(起点当天)归 R');
      expect(b.statementCents, 50000, reason: '还原 = 已还清的 9 月账单原额');
      expect(b.remainingCents, 0, reason: '过渡期无上期账单应还(银行同口径)');
    });

    test('过期:今天 ≥ nextBillingDate → 回落固定日推导', () async {
      await seedCard('gf', balanceCents: 70000, billingDay: 6);
      await seedEntry('pre', 'gf', DateTime(2026, 11, 3), credit: 20000);
      await seedEntry('s1', 'gf', DateTime(2026, 11, 8), credit: 50000);
      await seedOverride('gf',
          start: DateTime.utc(2026, 9, 19), next: DateTime.utc(2026, 11, 6));

      final b = await CreditCardStatementDue.breakdown(
        db: database, accountId: 'gf', accountType: 2,
        currentBalanceCents: 70000, billingDay: 6,
        clock: () => DateTime(2026, 11, 10, 10),
      );
      expect(b!.billingDate, DateTime(2026, 11, 6),
          reason: '11/6 账单已出,周期回落固定日(账单日 6)');
      expect(b.remainingCents, 20000,
          reason: '11/6 前消费属上期账单,之后为本期(S=50000)');
    });
  });

  test('repair:广发卡播种过渡覆盖(9/19→11/6),非广发卡与幂等', () async {
    await seedCard('gf-x', billingDay: 6);
    await (database.update(database.accounts)
          ..where((t) => t.id.equals('gf-x')))
        .write(const db.AccountsCompanion(name: Value('广发银行信用卡')));
    await seedCard('pa-x', billingDay: 1);
    await (database.update(database.accounts)
          ..where((t) => t.id.equals('pa-x')))
        .write(const db.AccountsCompanion(name: Value('平安银行信用卡')));

    // beforeOpen 已随建库跑过一轮(marker 已置但当时无卡)——清 marker
    // 模拟「有卡后重播」(生产:用户库首开即有卡,一步到位)。
    await (database.delete(database.appMeta)
          ..where((t) => t.key.equals('gf_billing_transition_v1')))
        .go();
    await seedGfBillingTransitionOverride(database);
    await seedGfBillingTransitionOverride(database); // 幂等重放

    final rows = await database.select(database.cardBillingCycleOverrides).get();
    expect(rows.length, 1);
    expect(rows.single.accountId, 'gf-x');
    expect(DateTime(rows.single.cycleStart.year, rows.single.cycleStart.month,
        rows.single.cycleStart.day), DateTime(2026, 9, 19));
    expect(
        DateTime(rows.single.nextBillingDate.year,
            rows.single.nextBillingDate.month, rows.single.nextBillingDate.day),
        DateTime(2026, 11, 6));
  });
}
