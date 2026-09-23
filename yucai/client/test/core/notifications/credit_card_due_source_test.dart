// CreditCardDueSource 单测:有欠款才提醒、月末 clamp、跨月 overdue 候选、
// id 与还款对话框「本期不再提醒」共用 creditCardCycleEntryId。
// T7 起金额口径 = 上期账单应还(credit_card_statement.dart 共享推导;
// 账单日未设降级 = 当前总欠款 —— 原断言金额=总欠款的改为账单口径,是本票目的)。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/notifications/credit_card_due_source.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_target.dart';
import 'package:yucai_client/core/notifications/reminder_dismissal_store.dart';

void main() {
  late db.AppDatabase database;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedAccount(
    String id, {
    required int category,
    int balance = 500000,
    int? repaymentDay,
    int? billingDay,
    int status = 1,
  }) async {
    await database.into(database.accounts).insert(
          db.AccountsCompanion.insert(
            id: id,
            name: id,
            accountType: 2,
            category: category,
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
            status: status,
            version: 1,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
            creditRepaymentDay: repaymentDay == null
                ? const Value<int>.absent()
                : Value<int>(repaymentDay),
            creditBillingDay: billingDay == null
                ? const Value<int>.absent()
                : Value<int>(billingDay),
          ),
        );
  }

  /// 卡上一笔消费分录(负债 credit-正;交易头行 + 分录)。
  Future<void> seedSpend(String id, String accountId, DateTime date,
      {required int cents}) async {
    await database.into(database.transactions).insert(
          db.TransactionsCompanion.insert(
            id: id,
            transactionDate: date,
            description: 'fixture',
            version: 1,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
    await database.into(database.transactionEntries).insert(
          db.TransactionEntriesCompanion.insert(
            id: 'e-$id',
            transactionId: id,
            accountId: accountId,
            chartOfAccountCode: '',
            debitCents: 0,
            creditCents: cents,
            note: '',
          ),
        );
  }

  test('有欠款才提醒:无欠款/未设还款日/非信用卡/归档卡全部过滤', () async {
    final now = DateTime.now();
    final nextRepayDay = (now.day % 28) + 1; // 未来日,避免跨月歧义
    await seedAccount('card-in-debt', category: 2, repaymentDay: nextRepayDay);
    await seedAccount('card-zero-debt',
        category: 2, balance: 0, repaymentDay: nextRepayDay);
    await seedAccount('card-no-day', category: 2, repaymentDay: null);
    await seedAccount('savings-like', category: 1, repaymentDay: nextRepayDay);
    await seedAccount('card-archived',
        category: 2, repaymentDay: nextRepayDay, status: 2);

    final out = await CreditCardDueSource(database).unpaidDueCandidates();
    expect(out.map((e) => e.debtName), ['card-in-debt']);
    // 本卡未设账单日 → 降级口径 = 当前总欠款 500000(credit-正)。
    expect(out.single.totalCents, 500000);
    expect(out.single.id, creditCardCycleEntryId('card-in-debt', DateTime(now.year, now.month, 1)));
    // 强类型路由目标(design ADR-2):信用卡候选 → AccountTarget(卡账户 id)。
    final t = out.single.target;
    expect(t, isA<AccountTarget>());
    expect((t as AccountTarget).accountId, 'card-in-debt');
  });

  test('月末 clamp:还款日 31 在 2 月只到 28/29', () async {
    final source = CreditCardDueSource(database,
        configProvider: () => const DueReminderConfig(advanceDays: 40));
    await seedAccount('big-day', category: 2, repaymentDay: 31);
    final out = await source.unpaidDueCandidates();
    // 无论今天何日,所有候选的日期都在合法月长内。
    for (final e in out) {
      final d = e.paymentDate;
      expect(d.day, lessThanOrEqualTo(DateTime(d.year, d.month + 1, 0).day));
    }
  });

  test('还款日已过且仍欠款 → 本月 overdue 候选 + 档位判 overdue', () async {
    final now = DateTime.now();
    // 构造一个本月已过的还款日:today-3,收敛到 1..28。
    var day = now.day - 3;
    if (day < 1) day += 28;
    if (day > 28) day = 28;
    await seedAccount('passed-card', category: 2, repaymentDay: day);

    final source = CreditCardDueSource(database);
    final out = await source.unpaidDueCandidates();
    final thisMonth = out.where(
        (e) => e.id == creditCardCycleEntryId('passed-card', DateTime(now.year, now.month, 1)));
    expect(thisMonth, isNotEmpty);
    final policy = DueReminderPolicy();
    expect(policy.tierFor(DateTime.now(), thisMonth.single.paymentDate),
        DueTier.overdue);
    // 挂失该期 → 催办停(扫描器过滤),下月新周期 id 不受影响。
    final store = ReminderDismissalStore(database);
    await store.dismiss(thisMonth.single.id);
    expect((await store.dismissedEntryIds()), {thisMonth.single.id});
  });

  test('advanceDays 窗口:还款日在窗口外的卡不产生候选', () async {
    // 时钟钉死 2026-09-22:还款日 27(差 5 天)> advanceDays 3 → 窗口外无候选;
    // 还款日 25(差 3 天)恰在窗口内。
    DateTime clock() => DateTime(2026, 9, 22, 10);
    await seedAccount('far-card', category: 2, repaymentDay: 27);
    await seedAccount('near-card', category: 2, repaymentDay: 25);

    final out = await CreditCardDueSource(database, clock: clock)
        .unpaidDueCandidates();
    final ids = out.map((e) => e.debtName).toSet();
    expect(ids.contains('far-card'), isFalse);
    expect(ids.contains('near-card'), isTrue);
    expect(out.where((e) => e.debtName == 'near-card').single.id,
        creditCardCycleEntryId('near-card', DateTime(2026, 9, 1)));
  });

  test('T7 账单口径:候选金额 = 上期账单应还,本周期消费不计入', () async {
    // 时钟 2026-09-22,账单日 15 → D = 2026-09-15;还款日 25 在窗口内。
    DateTime clock() => DateTime(2026, 9, 22, 10);
    await seedAccount('statement-open',
        category: 2, repaymentDay: 25, billingDay: 15);
    // 欠款 500000 = 账单内 100000(09-10)+ 本周期 80000(09-18)+ 更早 320000。
    await seedSpend('s1', 'statement-open', DateTime(2026, 9, 10), cents: 100000);
    await seedSpend('s2', 'statement-open', DateTime(2026, 9, 18), cents: 80000);

    final out = await CreditCardDueSource(database, clock: clock)
        .unpaidDueCandidates();
    // 口径修正:金额 = 应还 500000 − 80000 = 420000,而非总欠款 500000。
    expect(out.single.totalCents, 420000);
  });

  test('T7 应还 ≤ 0 不产候选:还清上期账单后本周期消费不再催', () async {
    DateTime clock() => DateTime(2026, 9, 22, 10);
    // cycle-only:欠款 100000 全部来自本周期消费(09-18)→ 应还 0 → 不催。
    await seedAccount('cycle-only',
        category: 2, repaymentDay: 25, billingDay: 15, balance: 100000);
    await seedSpend('c1', 'cycle-only', DateTime(2026, 9, 18), cents: 100000);
    // statement-open:对照卡,应还 > 0 → 照常候选。
    await seedAccount('statement-open',
        category: 2, repaymentDay: 25, billingDay: 15);
    await seedSpend('c2', 'statement-open', DateTime(2026, 9, 10), cents: 500000);

    final out = await CreditCardDueSource(database, clock: clock)
        .unpaidDueCandidates();
    expect(out.map((e) => e.debtName), ['statement-open']);
  });

  test('T7 overdue 金额同步 = 应还(账单口径)', () async {
    // 时钟 2026-09-22,还款日 5(本月已过)→ 本月 overdue 候选;账单日 15。
    DateTime clock() => DateTime(2026, 9, 22, 10);
    await seedAccount('passed-card',
        category: 2, repaymentDay: 5, billingDay: 15);
    await seedSpend('s1', 'passed-card', DateTime(2026, 9, 10), cents: 100000);
    await seedSpend('s2', 'passed-card', DateTime(2026, 9, 18), cents: 80000);

    final out = await CreditCardDueSource(database, clock: clock)
        .unpaidDueCandidates();
    final overdue = out.where((e) =>
        e.id == creditCardCycleEntryId('passed-card', DateTime(2026, 9, 1)));
    expect(overdue, isNotEmpty);
    // overdue 候选金额与 advance 候选同一口径 = 应还 420000。
    expect(overdue.single.totalCents, 420000);
  });
}
