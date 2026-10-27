import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';

/// 还贷类交易的「本金/利息/优惠/贴息」分腿摘要(2026-10-26 分腿口径;
/// v15 增银行利率优惠与政策贴息分列)。
///
/// 数据侧(debt_local_ds.recordPayment/repayBill)把还款借方拆为
/// 「债务户(本金)+ 贷款利息(利息)」,贴息作收入腿;本 helper 供
/// **各交易行渲染处复用**(交易记录页桌面行/移动卡、账户详情紧凑行),
/// 口径单源 —— 历史教训:曾有共享行组件与页面私有行并存且分叉,
/// 功能加在一处漏另一处(分腿摘要首版即漏),死组件已退役
/// (txn_row.dart 2026-10-26 删除)。
///
/// 识别 = 利息腿(note「利息」或账户为「贷款利息」费用户)与贴息腿
/// (note「财政贴息*」或「财政贴息」收入户);本金 = 借方合计 − 利息。
/// 无分腿(普通交易)返回 null,调用方不渲染摘要行。
({int principal, int interest, int discount, int subsidy})? txnSplitOf(
    Transaction txn, Account? Function(String accountId) accountOf) {
  var interest = 0;
  var subsidy = 0;
  var discount = 0;
  for (final e in txn.entries) {
    final acct = accountOf(e.accountId);
    final isInterest = e.debitCents > 0 &&
        (e.note == '利息' ||
            (acct?.accountType == AccountType.expense &&
                acct?.name == '贷款利息'));
    final isSubsidy = e.creditCents > 0 &&
        (e.note.startsWith('财政贴息') ||
            (acct?.accountType == AccountType.income &&
                acct?.name == '财政贴息'));
    final isDiscount = e.creditCents > 0 &&
        (e.note.startsWith('贷款利息优惠') ||
            (acct?.accountType == AccountType.income &&
                acct?.name == '贷款利息优惠'));
    if (isInterest) interest += e.debitCents;
    if (isSubsidy) subsidy += e.creditCents;
    if (isDiscount) discount += e.creditCents;
  }
  if (interest <= 0 && subsidy <= 0 && discount <= 0) return null;
  final debitSum = txn.entries.fold<int>(0, (a, e) => a + e.debitCents);
  return (
    principal: debitSum - interest,
    interest: interest,
    discount: discount,
    subsidy: subsidy
  );
}

/// 摘要文案:「本金 ¥x · 利息 ¥y · 优惠 ¥z · 贴息 ¥w」(零值段省略;
/// 本金恒显)。优惠 = 银行利率券,贴息 = 政策性补贴,分列。
String txnSplitLabel(
    ({int principal, int interest, int discount, int subsidy}) s,
    String symbol) {
  String fmt(int cents) {
    final abs = cents.abs();
    return '$symbol${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
  }

  final parts = ['本金 ${fmt(s.principal)}'];
  if (s.interest > 0) parts.add('利息 ${fmt(s.interest)}');
  if (s.discount > 0) parts.add('优惠 ${fmt(s.discount)}');
  if (s.subsidy > 0) parts.add('贴息 ${fmt(s.subsidy)}');
  return parts.join(' · ');
}
