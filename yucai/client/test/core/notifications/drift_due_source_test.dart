import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/drift_due_source.dart';
import 'package:yucai_client/core/notifications/due_target.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedDebtWithEntries(
    String debtId, {
    required List<(DateTime, int, bool)> rows,
    String subtype = '',
    int debtType = 0,
    String? collectionAccountId,
  }) async {
    await db.into(db.debts).insert(DebtsCompanion.insert(
          id: debtId,
          accountId: 'acc',
          counterparty: debtId == 'd1' ? '房贷' : '车贷',
          interestRate: 0.05,
          amortizationMethod: 1,
          startDate: DateTime(2026, 1, 1),
          dueDate: DateTime(2027, 1, 1),
          totalPrincipalCents: 1000000,
          debtType: debtType,
          subtype: subtype,
          contact: '',
          contractRef: '',
          collectionAccountId: Value(collectionAccountId),
          version: 1,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ));
    for (final (i, e) in rows.indexed) {
      await db.into(db.paymentScheduleEntries).insert(
            PaymentScheduleEntriesCompanion.insert(
              id: '$debtId-e$i',
              debtId: debtId,
              paymentDate: e.$1,
              principalCents: e.$2,
              interestCents: 0,
              totalCents: e.$2,
              paidCents: 0,
              paid: e.$3,
            ),
          );
    }
  }

  test('source:窗口内未付期次含债务名;已付/窗口外过滤', () async {
    // 相对真实今天播种(unpaidDueCandidates 用真实时钟,固定日期会随日历
    // 漂移误报 —— 2026-09-17 曾因 9/20 滑入窗口而炸)。
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    await seedDebtWithEntries('d1', rows: [
      (today.add(const Duration(days: 2)), 100000, false), // t3 窗口内
      (today.subtract(const Duration(days: 4)), 200000, false), // 逾期
      (today.add(const Duration(days: 5)), 300000, false), // 窗口外(>today+3)
      (today, 400000, true), // 已付
    ]);
    final source = DriftDueSource(db, windowDays: 3);
    final out = await source.unpaidDueCandidates();
    expect(out.length, 2);
    expect(out.map((e) => e.debtName), everyElement('房贷'));
    expect(out.map((e) => e.totalCents), containsAll([100000, 200000]));
    // 强类型路由目标(design ADR-2):期次候选 → DebtTarget(join 债务 id)。
    for (final e in out) {
      final t = e.target;
      expect(t, isA<DebtTarget>());
      expect((t as DebtTarget).debtId, 'd1');
    }
  });

  test('source:挂卡随卡还 card_loan 期次不产候选;未挂卡/空串/普通债照常',
      () async {
    // 2026-10-20 报障回归:挂卡 card_loan 的期供由 catchupCardLoanMerges
    // 自动并账进信用卡记录,还款提醒由卡侧 CreditCardDueSource 按账单应还
    // 覆盖;期次侧再催(尤其出账未到期的自由窗口被误判逾期)是残留。
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final rows = <(DateTime, int, bool)>[
      (today.subtract(const Duration(days: 5)), 100000, false), // 自由窗口(误报源)
      (today.add(const Duration(days: 2)), 110000, false), // 到期前 advance 档
    ];
    // 挂卡随卡还(平安/广发现金分期):整体排除。
    await seedDebtWithEntries('d-linked', rows: rows,
        subtype: 'card_loan', debtType: 1, collectionAccountId: 'card1');
    // 未挂卡 card_loan(e招贷独立授信,已解挂):期次催办照旧。
    await seedDebtWithEntries('d-unlinked', rows: rows,
        subtype: 'card_loan', debtType: 1);
    // 挂接为空串(防御:'' = 无挂接的另一种存储形态):照常催。
    await seedDebtWithEntries('d-empty-str', rows: rows,
        subtype: 'card_loan', debtType: 1, collectionAccountId: '');
    // 普通借入债(subtype 非card_loan):不受排除影响。
    await seedDebtWithEntries('d-normal', rows: rows,
        subtype: 'cash_installment', debtType: 1, collectionAccountId: 'card1');
    final out = await DriftDueSource(db, windowDays: 3).unpaidDueCandidates();
    expect(out.map((e) => e.id).toSet(), {
      for (final d in ['d-unlinked', 'd-empty-str', 'd-normal'])
        for (final suffix in ['-e0', '-e1']) '$d$suffix',
    });
  });

  test('log store:markSent 后 wasSent 真;跨桶/跨档互不影响', () async {
    final store = DriftReminderLogStore(db);
    const tokenA = '602311';
    const tokenB = '602312';
    expect(await store.wasSent('e1', DueTier.advance, tokenA), isFalse);
    await store.markSent('e1', DueTier.advance, tokenA);
    expect(await store.wasSent('e1', DueTier.advance, tokenA), isTrue);
    // 同桶同档重复 mark 幂等
    await store.markSent('e1', DueTier.advance, tokenA);
    // 跨档:advance 与 overdue 各自独立
    expect(await store.wasSent('e1', DueTier.overdue, tokenA), isFalse);
    // 跨桶:下一桶再发(催办节奏)
    expect(await store.wasSent('e1', DueTier.advance, tokenB), isFalse);
    // 旧版 yyyy-MM-dd 日粒度行与桶 token 不共键(迁移兼容)
    await store.markSent('e1', DueTier.advance, '2026-08-29');
    expect(await store.wasSent('e1', DueTier.advance, '2026-08-29'), isTrue);
    expect(await store.wasSent('e1', DueTier.advance, tokenA), isTrue);
  });
}
