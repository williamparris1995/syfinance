import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/drift_due_source.dart';

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
          debtType: 0,
          subtype: '',
          contact: '',
          contractRef: '',
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
