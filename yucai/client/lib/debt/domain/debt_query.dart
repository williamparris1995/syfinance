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
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';

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
