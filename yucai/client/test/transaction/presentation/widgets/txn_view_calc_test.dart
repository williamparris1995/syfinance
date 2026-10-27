// txn_view_calc 单源计算测试(2026-10-26 统一):转账判定/收支类型/
// 账户格解析。此前三处行渲染各持副本,现以本模块为唯一实现。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/widgets/txn_view_calc.dart';

Account _acct(String id, String name, AccountType t) => Account(
      id: id,
      name: name,
      accountType: t,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Transaction _txn(List<TransactionEntry> entries) => Transaction(
      id: 't1',
      transactionDate: DateTime(2026, 10, 24),
      description: 'x',
      entries: entries,
    );

void main() {
  final accounts = <String, Account>{
    'sav1': _acct('sav1', '工商银行', AccountType.asset),
    'sav2': _acct('sav2', '支付宝', AccountType.asset),
    'food': _acct('food', '餐饮', AccountType.expense),
    'salary': _acct('salary', '工资', AccountType.income),
    'loan': _acct('loan', '融e借', AccountType.liability),
    'int': _acct('int', '贷款利息', AccountType.expense),
  };
  Account? accountOf(String id) => accounts[id];

  test('转账:两 asset → transfer;from=贷方,to=借方', () {
    final t = _txn([
      TransactionEntry(accountId: 'sav1', debitCents: 0, creditCents: 500),
      TransactionEntry(accountId: 'sav2', debitCents: 500, creditCents: 0),
    ]);
    expect(txnIsTransfer(t, accountOf), isTrue);
    expect(txnFlavourOf(t, accountOf), TxnFlavour.transfer);
    final c = txnAccountCellOf(t, accountOf);
    expect(c.isTransfer, isTrue);
    expect(c.fromAccountId, 'sav1');
    expect(c.toAccountId, 'sav2');
  });

  test('收支(两腿平衡,但含 expense/income)不误判为转账', () {
    final expense = _txn([
      TransactionEntry(accountId: 'food', debitCents: 300, creditCents: 0),
      TransactionEntry(accountId: 'sav1', debitCents: 0, creditCents: 300),
    ]);
    expect(txnIsTransfer(expense, accountOf), isFalse,
        reason: 'domain inferFlavour 会误判 transfer,本单源不得');
    expect(txnFlavourOf(expense, accountOf), TxnFlavour.expense);
    final c = txnAccountCellOf(expense, accountOf);
    expect(c.primaryAccountId, 'sav1', reason: 'asset 为主账户');
    expect(c.categoryAccount?.id, 'food');
    expect(c.categoryAccount?.id, 'food');

    final income = _txn([
      TransactionEntry(accountId: 'sav1', debitCents: 800, creditCents: 0),
      TransactionEntry(accountId: 'salary', debitCents: 0, creditCents: 800),
    ]);
    expect(txnFlavourOf(income, accountOf), TxnFlavour.income);
  });

  test('账户元信息缺失/非 asset×2 的退化口径(历史逐位一致)', () {
    final t = _txn([
      TransactionEntry(accountId: 'x1', debitCents: 500, creditCents: 0),
      TransactionEntry(accountId: 'x2', debitCents: 0, creditCents: 500),
    ]);
    // 两侧都解析不到 → 退化「两条且平衡」= 转账。
    expect(txnIsTransfer(t, (id) => null), isTrue);
    expect(txnIsTransfer(t, accountOf), isTrue,
        reason: 'x1/x2 未登记 → accountOf 也返回 null → 同退化');
    // 能解析且任一端非 asset(储蓄卡→餐饮的支出)→ 非转账。
    final known = _txn([
      TransactionEntry(accountId: 'sav1', debitCents: 0, creditCents: 300),
      TransactionEntry(accountId: 'food', debitCents: 300, creditCents: 0),
    ]);
    expect(txnIsTransfer(known, accountOf), isFalse);
  });

  test('多腿(还贷分腿 3+1 条):compound,主账户=asset,对侧含 liability', () {
    final t = _txn([
      TransactionEntry(accountId: 'loan', debitCents: 84193, creditCents: 0),
      TransactionEntry(accountId: 'int', debitCents: 747, creditCents: 0),
      TransactionEntry(accountId: 'sav1', debitCents: 0, creditCents: 84729),
      TransactionEntry(accountId: 'sub', debitCents: 0, creditCents: 211),
    ]);
    expect(txnFlavourOf(t, accountOf), TxnFlavour.expense,
        reason: '含贷款利息 expense 腿');
    final c = txnAccountCellOf(t, accountOf);
    expect(c.isTransfer, isFalse);
    expect(c.primaryAccountId, 'sav1');
    // 分类槽 = 对侧首个非主账户,任意类型(F49:载体名可见;此例为
    // liability 载体 loan,chip 中性色)。
    expect(c.categoryAccount?.id, 'loan');
  });
}
