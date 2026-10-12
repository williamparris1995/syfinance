import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/localdb/repairs.dart';

/// F58 过度并账回退修复(f58_unmerge_overmerged_v1):旧 catchup 按「出账日
/// ≤ 今日」并入,自由窗口(已出账、未到期)期次被提前并入。修复对平安四笔
/// (ID 清单沿 F57)paid 且挂交易的期次,凡到期日(下一期出账日;末期 =
/// 自身+1 月月钳)> now 者回退:删并入交易(applyEntries(−1) 镜像逆余额)+
/// 期次置 unpaid/paidCents=0/transactionId=null。已到期者保留。
/// 照 f57_ts4_pingan_rediate_test 范式:合成库种同 ID 债,跑修复断言。
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
  /// 与「已并入」形态:paid 期次挂交易(借载体/贷卡两分录,镜像 recordPayment)。
  /// 载体/卡余额由调用方按并入后形态落定(载体 = P − ΣpaidCents,F36 不变式;
  /// 卡 = Σ并入 total)。
  Future<void> seedMergedDebt({
    required String debtId,
    required String carrierId,
    required String cardId,
    required List<DateTime> dates,
    required List<bool> paid,
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
        collectionAccountId: Value(cardId)));
    for (var i = 0; i < dates.length; i++) {
      final txnId = paid[i] ? 'txn-$debtId-$i' : null;
      await db.into(db.paymentScheduleEntries).insert(
          PaymentScheduleEntriesCompanion.insert(
              id: '$debtId-e$i',
              debtId: debtId,
              paymentDate: dates[i],
              principalCents: 250000,
              interestCents: 10000,
              totalCents: 260000,
              paid: paid[i],
              paidCents: paid[i] ? 260000 : 0,
              transactionId: Value(txnId)));
      if (paid[i]) {
        await db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: txnId!,
            transactionDate: dates[i],
            description: '信用卡分期 平安银行',
            version: 1,
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1)));
        await db.into(db.transactionEntries).insert(TransactionEntriesCompanion.insert(
              id: '$txnId-d',
              transactionId: txnId,
              accountId: carrierId,
              chartOfAccountCode: '2001',
              debitCents: 260000,
              creditCents: 0,
              note: ''));
        await db.into(db.transactionEntries).insert(TransactionEntriesCompanion.insert(
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

  /// 开库(beforeOpen 修复链)后手动清 f58 marker,模拟「真数据在场、链内
  /// 首跑」(照 f57 测试先例)。
  Future<void> resetMarker() async {
    await (db.delete(db.appMeta)
          ..where((m) => m.key.equals('f58_unmerge_overmerged_v1')))
        .go();
  }

  Future<int> balanceOf(String id) async =>
      (await (db.select(db.accounts)..where((a) => a.id.equals(id)))
              .getSingle())
          .currentBalanceCents;

  test('过度并入回退:到期日在未来者删交易+镜像逆余额+置未还;已到期保留;余额两侧断言', () async {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    const carrier = 'carrier-25k';
    const otherCarrier = 'carrier-other';
    const card = 'card-pingan';
    const debtId = '88f3f34b-a6cb-48af-b1ec-b30c79c519ec'; // F57 清单 25k
    // 期表:e0 = 今日-2月(paid;到期 = e1 = 今日-1月,已过 → 真并入保留);
    // e1 = 今日-1月(paid;到期 = e2 = 今日+1月,未来 → 过度并入,回退);
    // e2 = 今日+1月 / e3 = 今日+2月(未还)。
    final d0 = DateTime.utc(today.year, today.month - 2, 15);
    final d1 = DateTime.utc(today.year, today.month - 1, 15);
    final d2 = DateTime.utc(today.year, today.month + 1, 15);
    final d3 = DateTime.utc(today.year, today.month + 2, 15);
    // 并入后余额形态:各载体 = P − ΣpaidCents = 1,000,000 − 520,000(F36
    // 不变式);卡 = 两债 Σ并入 total = 1,040,000(对照债共用同卡)。
    await seedAccount(carrier, '平安现金分期载体', 7, balance: 480000);
    await seedAccount(otherCarrier, '非清单对照载体', 7, balance: 480000);
    await seedAccount(card, '平安信用卡', 2, balance: 1040000);
    await seedMergedDebt(debtId: debtId, carrierId: carrier, cardId: card,
        dates: [d0, d1, d2, d3], paid: [true, true, false, false]);
    // 对照:非清单债同形态(共用卡)→ 修复不动。
    await seedMergedDebt(debtId: 'other-debt', carrierId: otherCarrier,
        cardId: card, dates: [d0, d1, d2, d3], paid: [true, true, false, false]);

    await resetMarker();
    await runF58UnmergeOvermergedCardLoans(db);

    // e1 回退:未还、零分额、解除交易引用;交易头行+分录已删(DAO 直删,
    // guest 无墓碑)。
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
    // e0 已到期(到期 = d1 = 今日-1月 ≤ 今日)→ 真并入保留。
    final e0 = await (db.select(db.paymentScheduleEntries)
          ..where((e) => e.id.equals('$debtId-e0')))
        .getSingle();
    expect(e0.paid, isTrue);
    expect(e0.transactionId, 'txn-$debtId-0');
    expect(
        await (db.select(db.transactions)
                ..where((t) => t.id.equals('txn-$debtId-0')))
            .get(),
        isNotEmpty,
        reason: '已到期的真并入交易保留');

    // 余额两侧(并入分录 = 借载体/贷卡的镜像逆):载体欠款回升 +260,000
    // (credit-正),卡欠款回落 −260,000。
    expect(await balanceOf(carrier), 740000,
        reason: '载体 480,000 + 260,000 = 740,000(欠款回升)');
    expect(await balanceOf(otherCarrier), 480000,
        reason: '非清单债载体不动');
    expect(await balanceOf(card), 780000,
        reason: '卡 1,040,000 − 260,000 = 780,000(欠款回落;对照债并入保留)');
    // F36 不变式回位:载体余额 == totalPrincipal − ΣpaidCents(新)。
    final paidSum = (await (db.select(db.paymentScheduleEntries)
              ..where((e) => e.debtId.equals(debtId)))
            .get())
        .fold(0, (s, e) => s + e.paidCents);
    expect(await balanceOf(carrier), 1000000 - paidSum);
    // 对照债期次不动:仍 paid、交易仍在。
    final other = await (db.select(db.paymentScheduleEntries)
          ..where((e) => e.id.equals('other-debt-e1')))
        .getSingle();
    expect(other.paid, isTrue);
    expect(other.transactionId, 'txn-other-debt-1');
    expect(
        await (db.select(db.transactions)
                ..where((t) => t.id.equals('txn-other-debt-1')))
            .get(),
        isNotEmpty);
  });

  test('末期规则:单期债 paid 且到期(自身+1 月)在未来 → 回退', () async {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    const carrier = 'carrier-5k';
    const card = 'card-pingan';
    const debtId = 'f47c78a1-4b14-4629-9cde-49b262fda44b'; // F57 清单 5k
    // 单期债:出账 = 今日-10 日,已并入;末期到期 = 自身+1 月 = 未来 → 回退
    //(下一期出账日不存在,走 +1 月月钳分支)。
    final d0 = today.subtract(const Duration(days: 10));
    await seedAccount(carrier, '平安现金分期载体5k', 7, balance: 0);
    await seedAccount(card, '平安信用卡', 2, balance: 260000);
    await seedMergedDebt(debtId: debtId, carrierId: carrier, cardId: card,
        dates: [d0], paid: [true]);

    await resetMarker();
    await runF58UnmergeOvermergedCardLoans(db);

    final e = await (db.select(db.paymentScheduleEntries)
          ..where((x) => x.id.equals('$debtId-e0')))
        .getSingle();
    expect(e.paid, isFalse);
    expect(e.paidCents, 0);
    expect(e.transactionId, isNull);
    expect(await balanceOf(carrier), 260000, reason: '载体欠款回升 +260,000');
    expect(await balanceOf(card), 0, reason: '卡欠款回落 −260,000');
  });

  test('幂等:marker 后二次运行零变化;重入(删 marker)亦不重复回退', () async {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    const carrier = 'carrier-91k';
    const card = 'card-pingan';
    const debtId = '244bbcea-09eb-4ca3-aa9c-9ea8953e4922'; // F57 清单 9.1k
    // e0 = 今日-1月(paid;到期 = e1 = 今日+1月,未来 → 过度并入)。
    final d0 = DateTime.utc(today.year, today.month - 1, 15);
    final d1 = DateTime.utc(today.year, today.month + 1, 15);
    await seedAccount(carrier, '平安现金分期载体91k', 7, balance: 260000);
    await seedAccount(card, '平安信用卡', 2, balance: 260000);
    await seedMergedDebt(debtId: debtId, carrierId: carrier, cardId: card,
        dates: [d0, d1], paid: [true, false]);

    await resetMarker();
    await runF58UnmergeOvermergedCardLoans(db);
    expect(await balanceOf(carrier), 520000);
    expect(await balanceOf(card), 0);

    // 二次运行:marker 已置 → 零动作。
    await runF58UnmergeOvermergedCardLoans(db);
    expect(await balanceOf(carrier), 520000);
    expect(await balanceOf(card), 0);

    // 重入路径(模拟首跑中断、marker 未置):已回退期次 paid=0 → 跳过;
    // 交易已删 → 仅解除引用,无二次余额移动。
    await resetMarker();
    await runF58UnmergeOvermergedCardLoans(db);
    expect(await balanceOf(carrier), 520000,
        reason: '重入不得重复镜像逆余额');
    expect(await balanceOf(card), 0);
  });
}
