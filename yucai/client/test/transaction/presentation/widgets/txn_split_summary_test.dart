// 分腿摘要 helper 纯函数测试(2026-10-26 分腿口径)。
// 历史注记:此前存在共享 TxnRow 组件与交易页私有行两套渲染,前者生产
// 零使用(死组件)已退役;本 helper 为各交易行复用的口径单源。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/presentation/widgets/txn_split_summary.dart';

Account _acct(String id, String name, AccountType t) => Account(
      id: id,
      name: name,
      accountType: t,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Transaction _txn(List<TransactionEntry> entries) => Transaction(
      id: 't1',
      transactionDate: DateTime(2026, 10, 24),
      description: '还款',
      entries: entries,
    );

void main() {
  final accounts = <String, Account>{
    'loan': _acct('loan', '平安现金分期', AccountType.liability),
    'int': _acct('int', '贷款利息', AccountType.expense),
    'disc': _acct('disc', '贷款利息优惠', AccountType.income),
    'sub': _acct('sub', '财政贴息', AccountType.income),
    'sav': _acct('sav', '工商银行储蓄卡', AccountType.asset),
  };
  Account? accountOf(String id) => accounts[id];

  test('本金/利息识别(note 口径):本金 = 借方合计 − 利息', () {
    final s = txnSplitOf(
      _txn([
        TransactionEntry(accountId: 'loan', debitCents: 107472, creditCents: 0),
        TransactionEntry(
            accountId: 'int', debitCents: 646, creditCents: 0, note: '利息'),
        TransactionEntry(accountId: 'x', debitCents: 0, creditCents: 108118),
      ]),
      (id) => null, // accounts 缺失 → 仅 note 识别仍成立
    );
    expect(s, isNotNull);
    expect(s!.principal, 107472);
    expect(s.interest, 646);
    expect(s.subsidy, 0);
  });

  test('账户口径识别(无 note):贷款利息费用户 + 财政贴息收入户', () {
    final s = txnSplitOf(
      _txn([
        TransactionEntry(accountId: 'loan', debitCents: 84193, creditCents: 0),
        TransactionEntry(accountId: 'int', debitCents: 747, creditCents: 0),
        TransactionEntry(accountId: 'sav', debitCents: 0, creditCents: 84729),
        TransactionEntry(accountId: 'sub', debitCents: 0, creditCents: 211),
      ]),
      accountOf,
    );
    expect(s!.principal, 84193);
    expect(s.interest, 747);
    expect(s.subsidy, 211);
  });

  test('普通两腿交易(转账/收支)→ null,不误显', () {
    final s = txnSplitOf(
      _txn([
        TransactionEntry(accountId: 'sav', debitCents: 0, creditCents: 5000),
        TransactionEntry(accountId: 'loan', debitCents: 5000, creditCents: 0),
      ]),
      accountOf,
    );
    expect(s, isNull);
  });

  test('银行利率优惠腿识别(贷款利息优惠收入户,与贴息分列)', () {
    final s = txnSplitOf(
      _txn([
        TransactionEntry(accountId: 'loan', debitCents: 107518, creditCents: 0),
        TransactionEntry(accountId: 'int', debitCents: 3721, creditCents: 0),
        TransactionEntry(accountId: 'sav', debitCents: 0, creditCents: 108173),
        TransactionEntry(accountId: 'disc', debitCents: 0, creditCents: 3066),
      ]),
      accountOf,
    );
    expect(s!.principal, 107518);
    expect(s.interest, 3721);
    expect(s.discount, 3066);
    expect(s.subsidy, 0);
    expect(txnSplitLabel(s, '¥'), '本金 ¥1075.18 · 利息 ¥37.21 · 优惠 ¥30.66');
  });

  test('label 文案:零值段省略,格式无千分位', () {
    expect(
        txnSplitLabel((principal: 107472, interest: 646, discount: 0, subsidy: 0), '¥'),
        '本金 ¥1074.72 · 利息 ¥6.46');
    expect(
        txnSplitLabel((principal: 84193, interest: 747, discount: 0, subsidy: 211), '¥'),
        '本金 ¥841.93 · 利息 ¥7.47 · 贴息 ¥2.11');
  });
}
