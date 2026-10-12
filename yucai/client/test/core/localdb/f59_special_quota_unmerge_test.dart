import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/localdb/repairs.dart';

/// F59 专项池(开关关)当日并入回退修复(f59_special_quota_unmerge_v1):
/// 专项额度现金分期(countsTowardCardLimit=false)不并卡账单(独立结算,
/// 照 e招贷 同构银行语义);F57 前移后 catchup 已于**当日**新并入的期次
/// (并入交易 created_at 落修复运行当日)按 F58 T2 机制回退:删并入交易
/// (applyEntries(−1) 镜像逆余额)+ 期次置 unpaid/paidCents=0/
/// transactionId=null。存量更早并入(已被 9/19 等真实还款覆盖)不动;
/// 开关开债与手工还款交易不动。照 f58_unmerge_overmerged_test 范式。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  Future<void> seedAccount(String id, String name, int category,
      {int balance = 0}) async {
    await db.into(db.accounts).insert(AccountsCompanion.insert(
        id: id,
        name: name,
        accountType: 2,
        category: category,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
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
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1)));
  }

  /// 种一笔挂卡卡贷 + 期次(每期 principal 250000 / fee 10000 / total 260000)
  /// 与「已并入」形态:paid 期次挂并入交易(借载体/贷卡两分录,镜像
  /// recordPayment/catchup),[txnCreated] 逐期指定并入交易 created_at
  /// (null = 该期未还)。载体/卡余额由调用方按并入后形态落定(载体 =
  /// P − ΣpaidCents,F36 不变式;卡 = Σ并入 total)。
  Future<void> seedMergedDebt({
    required String debtId,
    required String carrierId,
    required String cardId,
    required List<DateTime> dates,
    required List<DateTime?> txnCreated,
    bool countsTowardCardLimit = false,
  }) async {
    await db.into(db.debts).insert(DebtsCompanion.insert(
        id: debtId,
        accountId: carrierId,
        counterparty: '平安银行',
        interestRate: 0.1,
        amortizationMethod: 1,
        contact: '',
        contractRef: '',
        totalPrincipalCents: 250000 * dates.length,
        debtType: 1,
        subtype: 'card_loan',
        startDate: dates.first,
        dueDate: dates.last,
        version: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        collectionAccountId: Value(cardId),
        countsTowardCardLimit: Value(countsTowardCardLimit)));
    for (var i = 0; i < dates.length; i++) {
      final created = txnCreated[i];
      final txnId = created == null ? null : 'txn-$debtId-$i';
      await db.into(db.paymentScheduleEntries).insert(
          PaymentScheduleEntriesCompanion.insert(
              id: '$debtId-e$i',
              debtId: debtId,
              paymentDate: dates[i],
              principalCents: 250000,
              interestCents: 10000,
              totalCents: 260000,
              paid: created != null,
              paidCents: created == null ? 0 : 260000,
              transactionId: Value(txnId)));
      if (created != null) {
        await db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: txnId!,
            transactionDate: dates[i],
            description: '信用卡分期 平安银行',
            version: 1,
            createdAt: created,
            updatedAt: created));
        await db.into(db.transactionEntries).insert(
                TransactionEntriesCompanion.insert(
                    id: '$txnId-d',
                    transactionId: txnId,
                    accountId: carrierId,
                    chartOfAccountCode: '2001',
                    debitCents: 260000,
                    creditCents: 0,
                    note: ''));
        await db.into(db.transactionEntries).insert(
                TransactionEntriesCompanion.insert(
                    id: '$txnId-c',
                    transactionId: txnId,
                    accountId: cardId,
                    chartOfAccountCode: '2001',
                    debitCents: 0,
                    creditCents: 260000,
                    note: ''));
      }
    }
  }

  /// 开库(beforeOpen 修复链)后手动清 f59 marker,模拟「真数据在场、链内
  /// 首跑」(照 f57/f58 测试先例)。
  Future<void> resetMarker() async {
    await (db.delete(db.appMeta)
          ..where((m) => m.key.equals('f59_special_quota_unmerge_v1')))
        .go();
  }

  Future<int> balanceOf(String id) async =>
      (await (db.select(db.accounts)..where((a) => a.id.equals(id)))
              .getSingle())
          .currentBalanceCents;

  test('当日并入回退:created_at 落运行当日的并入交易删除+镜像逆余额+置未还;昨日存量不动', () async {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final yesterday = DateTime.utc(today.year, today.month, today.day - 1);
    const carrier = 'carrier-35k';
    const card = 'card-pingan';
    const debtId = 'f59-special-35k';
    // 期表:e0 = 今日-2月(9/19 前后存量并入,txn created = 昨日 → 历史覆盖,
    // 不动);e1 = 今日-1月(F57 前移后今晨 catchup 新并入,txn created = 今日
    // → 回退);e2 = 今日+1月(未还)。
    final d0 = DateTime.utc(today.year, today.month - 2, 15);
    final d1 = DateTime.utc(today.year, today.month - 1, 15);
    final d2 = DateTime.utc(today.year, today.month + 1, 15);
    // 并入后余额形态:载体 = P − 2×paid = 750,000 − 520,000(F36 不变式);
    // 卡 = 3×并入(对照债一笔 + 本债两笔)。
    await seedAccount(carrier, '平安现金分期专项载体', 7, balance: 230000);
    await seedAccount(card, '平安信用卡', 2, balance: 780000);
    await seedMergedDebt(
        debtId: debtId,
        carrierId: carrier,
        cardId: card,
        dates: [d0, d1, d2],
        txnCreated: [yesterday, today, null]);
    // 对照:开关开债同形态(并入交易同为今日)→ 不动。
    const onCarrier = 'carrier-on';
    await seedAccount(onCarrier, '占额分期载体', 7, balance: 230000);
    await seedMergedDebt(
        debtId: 'f59-on-debt',
        carrierId: onCarrier,
        cardId: card,
        dates: [d0, d1, d2],
        txnCreated: [yesterday, today, null],
        countsTowardCardLimit: true);

    await resetMarker();
    await runF59SpecialQuotaUnmerge(db);

    // e1(当日并入)回退:未还、零分额、解除交易引用;交易头行+分录已删。
    final e1 = await (db.select(db.paymentScheduleEntries)
          ..where((e) => e.id.equals('$debtId-e1')))
        .getSingle();
    expect(e1.paid, isFalse);
    expect(e1.paidCents, 0);
    expect(e1.transactionId, isNull);
    expect(
        await (db.select(db.transactions)
                ..where((t) => t.id.equals('txn-$debtId-1')))
            .get(),
        isEmpty);
    expect(
        await (db.select(db.transactionEntries)
                ..where((t) => t.transactionId.equals('txn-$debtId-1')))
            .get(),
        isEmpty);
    // e0(昨日存量并入,已被真实还款覆盖)保留:paid、交易在。
    final e0 = await (db.select(db.paymentScheduleEntries)
          ..where((e) => e.id.equals('$debtId-e0')))
        .getSingle();
    expect(e0.paid, isTrue, reason: '更早并入的历史不动(资金流已发生)');
    expect(e0.transactionId, 'txn-$debtId-0');
    expect(
        await (db.select(db.transactions)
                ..where((t) => t.id.equals('txn-$debtId-0')))
            .get(),
        isNotEmpty);
    // 开关开对照债:当日并入也不动(开关关才回退)。
    final onE1 = await (db.select(db.paymentScheduleEntries)
          ..where((e) => e.id.equals('f59-on-debt-e1')))
        .getSingle();
    expect(onE1.paid, isTrue);
    expect(onE1.transactionId, 'txn-f59-on-debt-1');

    // 余额两侧(并入分录 = 借载体/贷卡的镜像逆):专项载体欠款回升 +260,000
    // (credit-正),卡欠款回落 −260,000;开关开载体/对照并入不动。
    expect(await balanceOf(carrier), 490000,
        reason: '专项载体 230,000 + 260,000 = 490,000(欠款回升)');
    expect(await balanceOf(onCarrier), 230000, reason: '开关开载体不动');
    expect(await balanceOf(card), 520000,
        reason: '卡 780,000 − 260,000 = 520,000(仅专项当日并入回落)');
    // F36 不变式回位:载体余额 == totalPrincipal − ΣpaidCents(新)。
    final paidSum = (await (db.select(db.paymentScheduleEntries)
              ..where((e) => e.debtId.equals(debtId)))
            .get())
        .fold(0, (s, e) => s + e.paidCents);
    expect(await balanceOf(carrier), 750000 - paidSum);
  });

  test('历史覆盖与手工还款不动:全部并入 created_at 早于当日 → 零动作;当日手工还款交易亦不回退', () async {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    const carrier = 'carrier-hist';
    const card = 'card-pingan';
    const debtId = 'f59-hist-35k';
    const saving = 'acc-saving';
    final d0 = DateTime.utc(today.year, today.month - 3, 15);
    final d1 = DateTime.utc(today.year, today.month - 2, 15);
    // 两期存量并入(created 9/19 前后,均非当日)。
    await seedAccount(carrier, '平安专项载体', 7, balance: 230000);
    await seedAccount(card, '平安信用卡', 2, balance: 520000);
    await seedMergedDebt(
        debtId: debtId,
        carrierId: carrier,
        cardId: card,
        dates: [d0, d1],
        txnCreated: [DateTime.utc(2026, 9, 19), DateTime.utc(2026, 9, 19)]);
    // 当日「手工还款」交易(非并入描述):借载体/贷储蓄 —— 修复不得回退。
    await seedAccount(saving, '储蓄卡', 9, balance: 0);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: 'txn-manual',
        transactionDate: today,
        description: '还款 平安银行',
        version: 1,
        createdAt: today,
        updatedAt: today));
    await db.into(db.transactionEntries).insert(TransactionEntriesCompanion.insert(
        id: 'txn-manual-d',
        transactionId: 'txn-manual',
        accountId: carrier,
        chartOfAccountCode: '2001',
        debitCents: 260000,
        creditCents: 0,
        note: ''));
    await db.into(db.transactionEntries).insert(TransactionEntriesCompanion.insert(
        id: 'txn-manual-c',
        transactionId: 'txn-manual',
        accountId: saving,
        chartOfAccountCode: '1001',
        debitCents: 0,
        creditCents: 260000,
        note: ''));
    await (db.update(db.paymentScheduleEntries)
          ..where((e) => e.id.equals('$debtId-e0')))
        .write(const PaymentScheduleEntriesCompanion(
            transactionId: Value('txn-manual')));

    await resetMarker();
    await runF59SpecialQuotaUnmerge(db);

    // 零动作:两期仍 paid、并入交易在、余额分毫不动。
    for (final eid in ['$debtId-e0', '$debtId-e1']) {
      final e = await (db.select(db.paymentScheduleEntries)
            ..where((x) => x.id.equals(eid)))
          .getSingle();
      expect(e.paid, isTrue, reason: '存量覆盖历史不动');
      expect(e.paidCents, 260000);
    }
    // e0 现挂手工还款交易(改挂模拟当日手工还款覆盖):交易须在。
    expect(
        await (db.select(db.transactions)
                ..where((t) => t.id.equals('txn-f59-hist-35k-1')))
            .get(),
        isNotEmpty,
        reason: '昨日并入交易不动');
    expect(
        await (db.select(db.transactions)
                ..where((t) => t.id.equals('txn-manual')))
            .get(),
        isNotEmpty,
        reason: '当日手工还款(非并入描述)不回退');
    expect(await balanceOf(carrier), 230000);
    expect(await balanceOf(card), 520000);
  });

  test('幂等:marker 后二次运行零变化;重入(删 marker)不重复回退', () async {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    const carrier = 'carrier-35k';
    const card = 'card-pingan';
    const debtId = 'f59-idem-35k';
    final d0 = DateTime.utc(today.year, today.month - 1, 15);
    final d1 = DateTime.utc(today.year, today.month + 1, 15);
    await seedAccount(carrier, '平安专项载体', 7, balance: 260000);
    await seedAccount(card, '平安信用卡', 2, balance: 260000);
    await seedMergedDebt(
        debtId: debtId,
        carrierId: carrier,
        cardId: card,
        dates: [d0, d1],
        txnCreated: [today, null]);

    await resetMarker();
    await runF59SpecialQuotaUnmerge(db);
    expect(await balanceOf(carrier), 520000);
    expect(await balanceOf(card), 0);

    // 二次运行:marker 已置 → 零动作。
    await runF59SpecialQuotaUnmerge(db);
    expect(await balanceOf(carrier), 520000);
    expect(await balanceOf(card), 0);

    // 重入路径(模拟首跑中断、marker 未置):已回退期次 paid=0 → 跳过;
    // 交易已删 → 无二次余额移动。
    await resetMarker();
    await runF59SpecialQuotaUnmerge(db);
    expect(await balanceOf(carrier), 520000,
        reason: '重入不得重复镜像逆余额');
    expect(await balanceOf(card), 0);
  });
}
