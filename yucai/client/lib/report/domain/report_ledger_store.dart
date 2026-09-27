/// F43 财务报告 —— 账本数据源 port(ADR-2,report domain 自有)。
///
/// 汇编层不 import 任何其他模块的 data 层(三态路由会走 remote 破坏
/// FR-2 纯本地),改经本 port 读原始行,adapter(report/data)直读
/// core/localdb DAO(core=共享基建,非任何模块私有)——T2 实现,
/// 本票只定契约。
///
/// 纯 Dart:零 flutter/drift/proto import。
library;

/// 账户原始行(汇编所需最小集)。
///
/// [type] 为会计类型 contract int:1 asset / 2 liability / 3 equity /
/// 4 income / 5 expense(与本地库 Accounts.accountType 同值)。
/// [category] 为账类代码串(取 AccountCategory 枚举名:'savings'/
/// 'creditCard'/'investment'/'fixedDeposit'/'goldFx'/'realEstate'/
/// 'loan'/'otherAsset'/'otherLiability'/'storedValue';本地库存的是
/// proto 枚举 int,adapter 负责换算)——现金流分类以 'savings' 判现金。
class AccountRow {
  const AccountRow({
    required this.id,
    required this.type,
    required this.category,
    required this.initialBalanceCents,
    required this.currencyCode,
  });

  /// 账户 id。
  final String id;

  /// 会计类型(1..5,见类注释)。
  final int type;

  /// 账类代码(见类注释;旧数据可能缺失 → null)。
  final String? category;

  /// 期初建账余额(int cents)。
  final int initialBalanceCents;

  /// 币种 ISO 代码(如 'CNY')。
  final String currencyCode;
}

/// 分录原始行(汇编所需最小集)。
///
/// 对手方表达:一条双录分录有借贷两条目,现金流分类需要「现金科目
/// 条目 + 对手条目」配对——本行携带 [transactionId],BalanceReplay /
/// CashFlowClassifier 按 transactionId 分组配对借贷双方(设计如此;
/// 不在行上冗余 counterparty* 字段,以能表达分类矩阵为准)。
/// [accountType]/[category] 为本条目所属账户的会计类型/账类
/// (denormalized,分类与 delta 方向判定免查表)。
class LedgerEntryRow {
  const LedgerEntryRow({
    required this.transactionId,
    required this.accountId,
    required this.accountType,
    required this.category,
    required this.date,
    required this.debitCents,
    required this.creditCents,
  });

  /// 所属交易 id(对手配对键;= 本地库 TransactionEntries.transactionId)。
  final String transactionId;

  /// 入账账户 id。
  final String accountId;

  /// 入账账户会计类型(1..5)。
  final int accountType;

  /// 入账账户账类代码(同 [AccountRow.category])。
  final String? category;

  /// 记账日期(= 所属交易 transactionDate,本地时区)。
  final DateTime date;

  /// 借方金额(int cents)。
  final int debitCents;

  /// 贷方金额(int cents)。
  final int creditCents;
}

/// 账本数据源 port:全量原始行读取(回放/汇编的唯数入口)。
///
/// T1 定 T1..T3 汇编路径所需最小方法;持仓/预算等原始行读取由后续
/// 票按需追加(adapter 单点隔离 drift 表结构变化,见 design 风险表)。
abstract class ReportLedgerStore {
  /// 全部账户(含 archived;汇编侧自行过滤)。
  Future<List<AccountRow>> accounts();

  /// 全量分录(按日期升序;BalanceReplay 对顺序不敏感,排序仅为
  /// 与 LLD 单遍口径一致)。
  Future<List<LedgerEntryRow>> entries();
}
