/// F43 财务报告 —— 账本数据源 port(ADR-2,report domain 自有)。
///
/// 汇编层不 import 任何其他模块的 data 层(三态路由会走 remote 破坏
/// FR-2 纯本地),改经本 port 读原始行,adapter(report/data)直读
/// core/localdb DAO(core=共享基建,非任何模块私有)——T2 实现,
/// 本票只定契约。
///
/// 纯 Dart:零 flutter/drift/proto import。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/report_document.dart';

/// 账户原始行(汇编所需最小集)。
///
/// [type] 为会计类型 contract int:1 asset / 2 liability / 3 equity /
/// 4 income / 5 expense(与本地库 Accounts.accountType 同值)。
/// [category] 为账类代码串(取 AccountCategory 枚举名:'savings'/
/// 'creditCard'/'investment'/'fixedDeposit'/'goldFx'/'realEstate'/
/// 'loan'/'otherAsset'/'otherLiability'/'storedValue';本地库存的是
/// proto 枚举 int,adapter 负责换算)——现金流分类以 'savings' 判现金。
/// [name] 为账户展示名(T5-R1 分类名称契约:收支构成行显示科目账户名;
/// 缺省 null = 未提供,汇编层回退 category 代码)。
class AccountRow {
  const AccountRow({
    required this.id,
    required this.type,
    required this.category,
    required this.initialBalanceCents,
    required this.currencyCode,
    this.name,
  });

  /// 账户 id。
  final String id;

  /// 会计类型(1..5,见类注释)。
  final int type;

  /// 账类代码(见类注释;旧数据可能缺失 → null)。
  final String? category;

  /// 账户展示名(T5-R1;缺失 → null)。
  final String? name;

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

/// 预算原始行(T4:预算执行章节输入,budget 头+item 合并扁平行)。
///
/// [month] 为 budget 头行预算月('YYYY-MM',本地库 Budgets.month 口径;
/// budget_local_ds 同源)。actuals 不在行上——汇编层自同一份 [entries]
/// 按 item 账户聚合(口径 = budget_local_ds L157-186:item 账户当月
/// max(Σdebit, Σcredit),conformance 钉死)。
class BudgetRow {
  const BudgetRow({
    required this.budgetId,
    required this.month,
    required this.itemId,
    required this.accountId,
    required this.accountCategory,
    required this.accountName,
    required this.plannedCents,
  });

  /// 所属预算头 id。
  final String budgetId;

  /// 预算月('YYYY-MM')。
  final String month;

  /// 预算项 id。
  final String itemId;

  /// 关联账户 id(actuals 按此账户聚合)。
  final String accountId;

  /// 关联账户账类代码(同 [AccountRow.category];旧数据缺失 → null)。
  final String? accountCategory;

  /// 关联账户名称(章节展示名;账户已删 → null)。
  final String? accountName;

  /// 预算限额(int cents)。
  final int plannedCents;
}

/// 汇率快照(T4:外币账户折 CNY 的两级候选,ADR-3 近似口径原始输入)。
///
/// 择优策略(历史优先、现值回退、双缺失跳过+附注)在 domain 汇编层
/// 单点实现——adapter 只做无策略读取,口径可经 fake store 在 domain
/// 层测试。汇率方向 = CNY per unit(与 server ConvertToBase 的
/// rateFrom 同义:amount × rate → CNY)。
class RateQuote {
  const RateQuote({this.asOfRate, this.currentRate});

  /// RateHistories ≤ 查询日 最近可得汇率;无 → null。
  final double? asOfRate;

  /// Currencies.exchangeRate 现值汇率;无行 → null。
  final double? currentRate;
}

/// 账本数据源 port:全量原始行读取(回放/汇编的唯数入口)。
///
/// T1 定 T1..T3 汇编路径所需最小方法;T4 追加预算行与汇率读取
/// (adapter 单点隔离 drift 表结构变化,见 design 风险表);F44 T2 追加
/// 模板/交易两读法(MD&A supplement 输入,expectedDates 预推演在 adapter)。
abstract class ReportLedgerStore {
  /// 全部账户(含 archived;汇编侧自行过滤)。
  Future<List<AccountRow>> accounts();

  /// 全量分录(按日期升序;BalanceReplay 对顺序不敏感,排序仅为
  /// 与 LLD 单遍口径一致)。
  Future<List<LedgerEntryRow>> entries();

  /// 全部预算行(头×item 扁平;含 inactive 头——budget_local_ds
  /// getBudgetByMonth 同款不按 active 过滤,汇编侧自行按期筛选)。
  Future<List<BudgetRow>> budgetRows();

  /// [currencyCode] 折 CNY 的汇率候选(查询日 [on] 时点)。
  ///
  /// 'CNY' 本币由汇编层直加不调本方法(port 不做币种语义)。
  Future<RateQuote> rateToCny(String currencyCode, DateTime on);

  /// 支出/收入订阅模板全量行(F44 MD&A supplement 输入)。
  ///
  /// [expectedDates] 为 adapter 预推演的 [period] **期内**应扣日
  /// (date-only 升序;推演逻辑留 data 侧直用 core/recurrence,domain
  /// 收纯日期表);direction/paused/nextDate 直读列,
  /// lastRecordedDate 由 lastTransactionId join 交易头行日期(一次 join)。
  /// 全量不过滤:含 paused(直读,R4 域内过滤)与
  /// transfer(direction=3 → expense=false 惰性行,R4 域内兜住)。
  Future<List<TemplateRowVO>> templateRows(ReportPeriod period);

  /// [period] 期内交易级支出投影(F44 R5 大额单笔候选)。
  ///
  /// expenseCents = 该交易 expense 科目分录 debit 合计(复用 entries 读法,
  /// 交易级聚合);description/date 头行直投影;仅含支出合计 > 0 的交易
  /// (纯收入/转账交易非候选),按日期升序。
  Future<List<LargeTxnVO>> transactions(ReportPeriod period);
}
