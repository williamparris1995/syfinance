import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/localdb/repairs.dart';

/// 卡贷并账双发去重(card_loan_double_merge_dedup_v1,2026-11-05):catchup
/// 并发双跑 → 同(描述, 日期)各落一笔「信用卡分期 X」,期表后写者胜出,先落
/// 的一笔成无人挂接的重复账(平安 11-02 实案:43c17a20 / a4587d41 相隔
/// 18ms)。修复保留期表挂接的正主,删未挂接孤儿并按 BalanceLocalUpdater
/// 方向规则逐分录增量逆余额。照 f58_unmerge_overmerged_test 范式合成库钉。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  Future<void> seedAccount(String id, String name, int type, int category,
      {int balance = 0}) async {
    await db.into(db.accounts).insert(AccountsCompanion.insert(
        id: id,
        name: name,
        accountType: type,
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

  /// 种一笔同(描述, 日期)并账交易(三腿镜像 11-02 实案:借载体本金
  /// 25487 / 借贷款利息 6476 / 贷卡 31963)。
  Future<void> seedMergeTxn(String id, String carrier, String interest,
      String card, DateTime createdAt) async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: id,
        transactionDate: DateTime.utc(2026, 11, 2),
        description: '信用卡分期 平安银行',
        version: 1,
        createdAt: createdAt,
        updatedAt: createdAt));
    for (final (acc, d, c) in [
      (carrier, 25487, 0),
      (interest, 6476, 0),
      (card, 0, 31963),
    ]) {
      await db.into(db.transactionEntries).insert(
          TransactionEntriesCompanion.insert(
              id: '$id-e-$acc',
              transactionId: id,
              accountId: acc,
              chartOfAccountCode: '',
              debitCents: d,
              creditCents: c,
              note: ''));
    }
  }

  /// 开库(beforeOpen 修复链)后手动清 marker,模拟「真数据在场、链内
  /// 首跑」(照 f58 测试先例)。
  Future<void> resetMarker() async {
    await (db.delete(db.appMeta)
          ..where((m) => m.key.equals('card_loan_double_merge_dedup_v1')))
        .go();
  }

  test('孤儿删除 + 三账户余额各回退一份;正主保留;marker 幂等', () async {
    // 三账户:type 2 载体/卡,type 5 费用利息。余额 = 双发后(两份已联动)。
    const carrier = 'acc-carrier';
    const interest = 'acc-interest';
    const card = 'acc-card';
    // 开账 1,000,000,双发各冲本金 25,487 → 949,026;
    // 利息费用双份 2×6,476 = 12,952;卡欠款双份 2×31,963 = 63,926。
    await seedAccount(carrier, '平安现金分期', 2, 7, balance: 949026);
    await seedAccount(interest, '贷款利息', 5, 12, balance: 12952);
    await seedAccount(card, '平安银行信用卡', 2, 2, balance: 63926);

    // 债 + 期次:11-02 期 paid,挂 linked 交易(双发后写者胜出形态)。
    await db.into(db.debts).insert(DebtsCompanion.insert(
        id: 'debt1',
        accountId: carrier,
        counterparty: '平安银行',
        interestRate: 0.088,
        amortizationMethod: 1,
        startDate: DateTime.utc(2026, 8, 2),
        dueDate: DateTime.utc(2028, 1, 2),
        totalPrincipalCents: 1000000,
        debtType: 1,
        subtype: 'card_loan',
        contact: '',
        contractRef: '',
        collectionAccountId: const Value(card),
        version: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1)));
    await db.into(db.paymentScheduleEntries).insert(
            PaymentScheduleEntriesCompanion.insert(
                id: 'entry-1102',
                debtId: 'debt1',
                paymentDate: DateTime.utc(2026, 11, 2),
                principalCents: 25487,
                interestCents: 6476,
                totalCents: 31963,
                paid: true,
                paidCents: 31963,
                transactionId: const Value('txn-linked')));

    // 双发实案形态:同一(描述, 日期)两笔,期表挂后写者(正主),
    // 先落的一笔成孤儿(created 相隔 18ms)。
    await seedMergeTxn(
        'txn-linked', carrier, interest, card, DateTime.utc(2026, 11, 2, 2, 4, 51, 189));
    await seedMergeTxn(
        'txn-orphan', carrier, interest, card, DateTime.utc(2026, 11, 2, 2, 4, 51, 171));

    // 干扰项①:放款交易(「信用卡分期放款」)不进扫描(空格锚定);
    // 干扰项②:另一日期单笔未挂接并账(历史重构批次形态)→ 单笔不动。
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: 'txn-disburse',
        transactionDate: DateTime.utc(2026, 8, 2),
        description: '信用卡分期放款 平安银行',
        version: 1,
        createdAt: DateTime.utc(2026, 9, 30),
        updatedAt: DateTime.utc(2026, 9, 30)));
    await db.into(db.transactionEntries).insert(
        TransactionEntriesCompanion.insert(
            id: 'txn-disburse-e1',
            transactionId: 'txn-disburse',
            accountId: card,
            chartOfAccountCode: '',
            debitCents: 0,
            creditCents: 1000000,
            note: ''));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: 'txn-solo-1002',
        transactionDate: DateTime.utc(2026, 10, 2),
        description: '信用卡分期 平安银行',
        version: 1,
        createdAt: DateTime.utc(2026, 9, 30),
        updatedAt: DateTime.utc(2026, 9, 30)));
    await db.into(db.transactionEntries).insert(
        TransactionEntriesCompanion.insert(
            id: 'txn-solo-1002-e1',
            transactionId: 'txn-solo-1002',
            accountId: card,
            chartOfAccountCode: '',
            debitCents: 0,
            creditCents: 31963,
            note: ''));

    await resetMarker();
    await dedupCardLoanDoubleMerges(db);

    // 孤儿(含分录)删除;正主/放款/单笔保留;期表挂接不变。
    final txnIds = (await db.select(db.transactions).get()).map((t) => t.id).toSet();
    expect(txnIds, {'txn-linked', 'txn-disburse', 'txn-solo-1002'});
    final entryRows = await db.select(db.transactionEntries).get();
    expect(entryRows.where((e) => e.transactionId == 'txn-orphan'), isEmpty);
    final schedule = await db.select(db.paymentScheduleEntries).getSingle();
    expect(schedule.transactionId, 'txn-linked');

    // 余额各回退一份(增量逆应用):载体 +25,487;利息 −6,476;卡 −31,963。
    Future<int> bal(String id) async => (await (db.select(db.accounts)
            ..where((a) => a.id.equals(id)))
        .getSingle())
        .currentBalanceCents;
    expect(await bal(carrier), 949026 + 25487);
    expect(await bal(interest), 12952 - 6476);
    expect(await bal(card), 63926 - 31963);

    // marker 已置;重跑幂等(无新删除、余额不再动)。
    final marker = await (db.select(db.appMeta)
          ..where((m) => m.key.equals('card_loan_double_merge_dedup_v1')))
        .getSingleOrNull();
    expect(marker, isNotNull);
    await dedupCardLoanDoubleMerges(db);
    expect((await db.select(db.transactions).get()).length, 3);
    expect(await bal(carrier), 949026 + 25487);
  });

  test('无重复(仅单笔挂接)→ 零动作,marker 照置', () async {
    await seedAccount('acc-c2', '载体2', 2, 7, balance: 100);
    await seedAccount('acc-card2', '卡2', 2, 2, balance: 100);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: 'txn-only',
        transactionDate: DateTime.utc(2026, 11, 2),
        description: '信用卡分期 平安银行',
        version: 1,
        createdAt: DateTime.utc(2026, 11, 2),
        updatedAt: DateTime.utc(2026, 11, 2)));
    await db.into(db.transactionEntries).insert(
        TransactionEntriesCompanion.insert(
            id: 'txn-only-e1',
            transactionId: 'txn-only',
            accountId: 'acc-card2',
            chartOfAccountCode: '',
            debitCents: 0,
            creditCents: 31963,
            note: ''));

    await resetMarker();
    await dedupCardLoanDoubleMerges(db);

    expect((await db.select(db.transactions).get()).length, 1);
    expect(
        (await (db.select(db.accounts)..where((a) => a.id.equals('acc-card2')))
                .getSingle())
            .currentBalanceCents,
        100,
        reason: '单笔不动,余额零改动');
    final marker = await (db.select(db.appMeta)
          ..where((m) => m.key.equals('card_loan_double_merge_dedup_v1')))
        .getSingleOrNull();
    expect(marker, isNotNull);
  });
}
