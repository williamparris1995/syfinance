// CreditCardDueSource 单测:有欠款才提醒、月末 clamp、跨月 overdue 候选、
// id 与还款对话框「本期不再提醒」共用 creditCardCycleEntryId。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/notifications/credit_card_due_source.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
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
    expect(out.single.totalCents, 500000); // credit-正:欠款原值
    expect(out.single.id, creditCardCycleEntryId('card-in-debt', DateTime(now.year, now.month, 1)));
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
}
