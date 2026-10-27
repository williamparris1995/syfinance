import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart' show TxnFlavour;

/// 交易行底层计算单源(2026-10-26 统一)。
///
/// 转账判定 / 收支类型推断 / 账户格解析此前在三处行渲染各有一份手写
/// 副本(交易页桌面行、移动卡、账户详情紧凑行),细节互有出入且口径
/// 漂移风险高(分腿摘要曾因此漏加一处)。本模块为唯一实现;widget 层
/// 只做展示映射(名称/颜色/布局),不再自持判定逻辑。
///
/// 与 domain [inferFlavour] 的关系:后者无账户元信息,「2 entries +
/// balanced → transfer」会把收支误判为转账;数据层分组仍用它,行渲染
/// 一律用本模块的账户类型感知版本。

/// 转账判定:恰好两条 entry 且两端账户都是 asset;无账户元信息时退化
/// 为「两条且平衡」(与历史口径逐位一致)。
bool txnIsTransfer(Transaction txn, Account? Function(String) accountOf) {
  if (txn.entries.length != 2) return false;
  final e0 = accountOf(txn.entries[0].accountId);
  final e1 = accountOf(txn.entries[1].accountId);
  if (e0 == null || e1 == null) return txn.isBalanced;
  return e0.accountType == AccountType.asset &&
      e1.accountType == AccountType.asset;
}

/// 收支类型推断(账户类型感知):transfer 优先;否则含 expense →
/// expense,含 income → income,否则 compound。
TxnFlavour txnFlavourOf(Transaction txn, Account? Function(String) accountOf) {
  if (txnIsTransfer(txn, accountOf)) return TxnFlavour.transfer;
  for (final e in txn.entries) {
    final t = accountOf(e.accountId)?.accountType;
    if (t == AccountType.expense) return TxnFlavour.expense;
    if (t == AccountType.income) return TxnFlavour.income;
  }
  return TxnFlavour.compound;
}

/// 账户格解析结果(账户 id/对象;名称映射留给调用方)。
class TxnAccountCell {
  const TxnAccountCell._({
    required this.isTransfer,
    this.fromAccountId = '',
    this.toAccountId = '',
    this.primaryAccountId = '',
    this.primaryAccount,
    this.categoryAccount,
  });

  /// 转账:转出(贷方)/转入(借方)账户 id。
  final String fromAccountId;
  final String toAccountId;

  /// 非转账:主账户(asset 优先,退化首条)与分类账户(对侧首个账户,
  /// **任意类型** —— account-as-category 模型下 expense/income 是分类;
  /// liability(如卡贷载体)也入此槽,F49 要求行内显示载体名;着色由
  /// chip 按账户类型自理)。
  final String primaryAccountId;
  final Account? primaryAccount;
  final Account? categoryAccount;

  final bool isTransfer;
}

/// 账户格解析:转账 → from/to;非转账 → 主账户 + 分类账户。
TxnAccountCell txnAccountCellOf(
    Transaction txn, Account? Function(String) accountOf) {
  final transfer = txnIsTransfer(txn, accountOf);
  if (transfer) {
    final fromEntry = txn.entries.firstWhere(
      (e) => e.creditCents > 0,
      orElse: () => txn.entries.first,
    );
    final toEntry = txn.entries.firstWhere(
      (e) => e.debitCents > 0,
      orElse: () => txn.entries.last,
    );
    return TxnAccountCell._(
      isTransfer: true,
      fromAccountId: fromEntry.accountId,
      toAccountId: toEntry.accountId,
    );
  }
  Account? assetAccount;
  Account? otherAccount;
  String? assetId;
  for (final e in txn.entries) {
    final a = accountOf(e.accountId);
    if (a == null) continue;
    if (a.accountType == AccountType.asset && assetAccount == null) {
      assetAccount = a;
      assetId = e.accountId;
    } else {
      otherAccount ??= a;
    }
  }
  // 分类 = 对侧首个非主账户(任意类型;转账恒 null,调用方隐藏 chip)。
  final primaryId = assetId ??
      (txn.entries.isNotEmpty ? txn.entries.first.accountId : '');
  return TxnAccountCell._(
    isTransfer: false,
    primaryAccountId: primaryId,
    primaryAccount: assetAccount ?? accountOf(primaryId),
    categoryAccount: otherAccount,
  );
}
