// F9 FR-4 / ADR-3 —— 债务/债权列表查询助手(纯 domain 函数,无 Flutter/drift 依赖)。
//
// 搜索(对手方 contains)与排序(总金额/到期日 × 升降)的**唯一实现**:
// DebtLocalDataSource(list 查询参数)与债务/债权两页(前端管道)共用,避免
// DS/页面两套口径漂移(复用第一)。承 F7 模式(TxnSortKey/TxnSortDir 落
// transaction/domain/value_objects.dart,此处独立成文件因 debt 的
// value_objects 被 debt_entity 反向引用,查询助手依赖 Debt 实体,单独文件
// 保持依赖单向:debt_query → debt_entity)。
//
// 本文件同时收编原 core/widgets/debt_list_widgets.dart 内的列表筛选纯函数
// (DebtListFilter / debtMatchesListFilter / debtCompareList)—— 它们本就是
// 无 UI 依赖的 domain 规则,搬到这里后 debt_list_widgets 通过 export 转发,
// 既有 import 不变。
import 'package:equatable/equatable.dart';

import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

/// 列表排序键(F9 FR-4):总金额(totalPrincipalCents,LLD 口径)或到期日。
enum DebtSortKey { amount, dueDate }

/// 列表排序方向(F9 FR-4)。默认态 (dueDate, asc) 与既有默认序
/// [debtCompareList] 逐位一致 —— NFR-2:不带新参数时行为不变。
enum DebtSortDir { asc, desc }

/// 列表筛选:全部 / 进行中 / 已结清 / 逾期(两侧共用,顺序一致 = 镜像)。
/// (原 debt_list_widgets.dart 内定义,F9-T3 收编至 domain,注释语义不变。)
enum DebtListFilter { all, active, settled, overdue }

/// 列表筛选命中判断(原 debt_list_widgets.dart,语义不变)。
bool debtMatchesListFilter(Debt d, DebtListFilter f) {
  final settled = d.remainingPrincipalCents <= 0;
  switch (f) {
    case DebtListFilter.all:
      return true;
    case DebtListFilter.active:
      return !settled;
    case DebtListFilter.settled:
      return settled;
    case DebtListFilter.overdue:
      return !settled && d.dueDate.isBefore(DateTime.now());
  }
}

/// 分类(subtype)命中:key null/空 = 全部。subtype 是纯 String(DebtSubtypes /
/// ReceivableSubtypes 的 key),与状态筛选正交,两页共用。
bool debtMatchesSubtype(Debt d, String? subtypeKey) {
  final k = subtypeKey?.trim() ?? '';
  if (k.isEmpty) return true;
  return d.subtype == k;
}

/// 列表默认序(原 debt_list_widgets.dart,语义不变):未结清在前(按到期
/// 升序),已结清沉底。
int debtCompareList(Debt a, Debt b) {
  final aSettled = a.remainingPrincipalCents <= 0;
  final bSettled = b.remainingPrincipalCents <= 0;
  if (aSettled != bSettled) return aSettled ? 1 : -1;
  return a.dueDate.compareTo(b.dueDate);
}

/// 搜索命中(F9 FR-4):对手方 counterparty contains 忽略大小写。
///
/// [query] null/空白 = 不过滤(恒 true,与 F7 searchText「非空非空白才生效」
/// 口径一致);匹配用 trim 后的小写词。
bool debtSearchMatches(Debt d, String? query) {
  final q = query?.trim() ?? '';
  if (q.isEmpty) return true;
  return d.counterparty.toLowerCase().contains(q.toLowerCase());
}

/// 四态排序比较器(F9 FR-4):键(金额/到期日)× 方向(升/降)。
///
/// - **(dueDate, asc) 即默认序**:直接委托 [debtCompareList](未结清在前 +
///   到期升序),与列表页现状逐位一致(NFR-2)—— 排序控件初始态选中
///   「到期日升序」时列表顺序零变化。
/// - 其余三态为纯键序(不按结清分组);同键 tie-break 落回默认序,保证
///   顺序确定(同键 + 同结清态时再按到期升序,来自 debtCompareList)。
int debtCompareQuery(Debt a, Debt b, DebtSortKey key, DebtSortDir dir) {
  if (key == DebtSortKey.dueDate && dir == DebtSortDir.asc) {
    return debtCompareList(a, b);
  }
  int primary;
  if (key == DebtSortKey.amount) {
    // 金额口径 = totalPrincipalCents(总本金,LLD 定案;remaining 会随还款
    // 变动,排序抖动大)。
    final byAmount = b.totalPrincipalCents.compareTo(a.totalPrincipalCents);
    primary = dir == DebtSortDir.asc ? -byAmount : byAmount;
  } else {
    final byDate = b.dueDate.compareTo(a.dueDate);
    primary = dir == DebtSortDir.asc ? -byDate : byDate;
  }
  if (primary != 0) return primary;
  return debtCompareList(a, b);
}

/// F37 到期紧迫度(未结清债的到期日分桶;已结清 = none)。
enum DebtDueUrgency { none, within15, within7, overdue }

/// [d] 的到期紧迫度,[now] 为「今天」(测试可注入)。
/// 按日期差分桶(当日 0 点对齐,剔除时刻噪声):
/// 已结清 → none;due < today → overdue;0..7 天 → within7;
/// 8..15 天 → within15;>15 天 → none。
DebtDueUrgency debtDueUrgency(Debt d, DateTime now) {
  if (d.remainingPrincipalCents <= 0) return DebtDueUrgency.none;
  final due = DateTime(d.dueDate.year, d.dueDate.month, d.dueDate.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = due.difference(today).inDays;
  if (days < 0) return DebtDueUrgency.overdue;
  if (days <= 7) return DebtDueUrgency.within7;
  if (days <= 15) return DebtDueUrgency.within15;
  return DebtDueUrgency.none;
}

/// 卡贷未出账占用(F50,银行口径:仅剩余本金,期表口径;开关关的不计)。
///
/// = Σ [Debt.remainingPrincipalCents] over 满足三条件的债:
/// ① subtype == [DebtSubtypes.cardLoan](卡贷);
/// ② [Debt.collectionAccountId] == [cardId](挂接该信用卡);
/// ③ [Debt.countsTowardCardLimit](债级开关开,备用金类独立额度置关)。
///
/// **不得**使用载体户余额(期表才是事实源)或 unpaidInterestCents
/// (spec FR-1 定口径:仅剩余本金;未出账利息不占额度)。
int cardLoanOccupationCents(List<Debt> debts, String cardId) {
  var sum = 0;
  for (final d in debts) {
    if (d.subtype == DebtSubtypes.cardLoan &&
        d.collectionAccountId == cardId &&
        d.countsTowardCardLimit) {
      sum += d.remainingPrincipalCents;
    }
  }
  return sum;
}

/// 下一未还期最小投影(F51 FR-1):{期总额, 期还款日} 二元组。
///
/// 调用方(TB/TC 组装)从期表构造 —— [debtNextPeriod] 是该构造的**唯一
/// 实现**,直接复用勿自写(复用第一)。字段刻意最小(不含 principal/
/// interest 拆分、期数),保持 domain 纯函数与 drift/仓储解耦。
class DebtNextPeriod extends Equatable {
  const DebtNextPeriod({required this.totalCents, required this.date});

  /// 该期应还总额(本 + 利,即期表 totalCents)。
  final int totalCents;

  /// 该期还款日(**可为过去日期** —— 逾期未付仍是下一期,含逾期口径)。
  final DateTime date;

  @override
  List<Object?> get props => [totalCents, date];
}

/// 下一未还期(F51 FR-1,含逾期):期表 paid=false 中 payment_date 最早者。
///
/// 与 [DebtLocalDataSource._toEntity] 的既有 next 口径同源(`!paid` 按
/// paymentDate 升序取 first,含逾期未付 —— 过去日期仍算下期,不按 now
/// 过滤)。全付清 / 空期表 → null。
DebtNextPeriod? debtNextPeriod(List<PaymentEntry> schedule) {
  PaymentEntry? earliest;
  for (final e in schedule) {
    if (e.paid) continue;
    if (earliest == null || e.paymentDate.isBefore(earliest.paymentDate)) {
      earliest = e;
    }
  }
  if (earliest == null) return null;
  return DebtNextPeriod(totalCents: earliest.totalCents, date: earliest.paymentDate);
}

/// loan 派生四值(F51 FR-1,账户侧 loan 双重表示与债务域共用口径)。
class DerivedLoanFields extends Equatable {
  const DerivedLoanFields({
    required this.totalPrincipalCents,
    required this.remainingPrincipalCents,
    this.nextPaymentCents,
    this.nextPaymentDate,
  });

  /// Σ [Debt.totalPrincipalCents](总本金,LLD 口径)。
  final int totalPrincipalCents;

  /// Σ [Debt.remainingPrincipalCents](剩余本金,期表口径)。
  final int remainingPrincipalCents;

  /// Σ 各债下一未还期 total;**无期表债计 0;全无 → null**(区别于 0:
  /// null = 所有债都没有未还期,UI 可显「无月供」而非 ¥0)。
  final int? nextPaymentCents;

  /// min 各债下一未还期日(含逾期未付的过去日期);全无 → null。
  final DateTime? nextPaymentDate;

  @override
  List<Object?> get props => [
        totalPrincipalCents,
        remainingPrincipalCents,
        nextPaymentCents,
        nextPaymentDate,
      ];
}

/// loan 四值聚合(F51 FR-1):Σ 债头两值 + Σ/min 下一未还期投影。
///
/// [nextByDebtId] 以 [Debt.id] 为 key 的下一未还期投影(用 [debtNextPeriod]
/// 构造);**以 [debts] 驱动遍历** —— map 中不在 debts 列表的 key 不计入
/// (孤儿投影防御)。空债列表 → 全 0/null 空视图(不抛)。
DerivedLoanFields derivedLoanFields(
    List<Debt> debts, Map<String, DebtNextPeriod> nextByDebtId) {
  var total = 0;
  var remaining = 0;
  var nextSum = 0;
  DateTime? nextDate;
  var hasAnyNext = false;
  for (final d in debts) {
    total += d.totalPrincipalCents;
    remaining += d.remainingPrincipalCents;
    final next = nextByDebtId[d.id];
    if (next == null) continue; // 无期表债:月供计 0、日期不参与
    hasAnyNext = true;
    nextSum += next.totalCents;
    if (nextDate == null || next.date.isBefore(nextDate)) {
      nextDate = next.date;
    }
  }
  return DerivedLoanFields(
    totalPrincipalCents: total,
    remainingPrincipalCents: remaining,
    nextPaymentCents: hasAnyNext ? nextSum : null,
    nextPaymentDate: nextDate,
  );
}

/// F49 FR-4a:挂接信用卡 [cardId] 的并入型分期摘要(卡面徽标数据源)。
///
/// 归集口径:`subtype==cardLoan && collectionAccountId==cardId && 未结清`
/// (已结清 [Debt.remainingPrincipalCents]<=0 不计,与 [debtMatchesListFilter]
/// 同式);card_loan 是借入侧子类型,显式收 `type==borrowedIn` 使函数自含
/// (不依赖调用方预过滤);[Debt.remainingPrincipalCents] 为实体剩余本金
/// 字段 —— 本金口径(不含未付息费,区别于 accounts_page 债务聚合的本息
/// 口径),存储溯源 = F36 北极星式 totalPrincipal − Σpaid(repairs.dart
/// 不变式注释钉死的 remainingPrincipalCents 同源)。
///
/// **与 F50 cardLoanOccupationCents 并行落地**(F49/F50 两会话各自实现),
/// 口径差异 = 徽标展示全额剩余本金,占用按 countsTowardCardLimit 开关过滤
/// —— 后续收敛候选(收敛前勿再新增第三种平行聚合)。
/// 调用方(accounts_page 徽标)传入**全量** borrowedIn debts 流 —— 徽标数据
/// 不受 T4 列表过滤影响(载体户被滤后,其分期仍在挂接卡上可见)。
({int count, int remainingCents}) cardInstallmentSummary(
    List<Debt> debts, String cardId) {
  var count = 0;
  var remainingCents = 0;
  for (final d in debts) {
    if (d.type != DebtType.borrowedIn) continue;
    if (d.subtype != DebtSubtypes.cardLoan) continue;
    if (d.collectionAccountId != cardId) continue;
    if (d.remainingPrincipalCents <= 0) continue;
    count++;
    remainingCents += d.remainingPrincipalCents;
  }
  return (count: count, remainingCents: remainingCents);
}
