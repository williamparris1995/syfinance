// ReceivablesSummary entity(receivables 对齐,Task 8)—— 应收债权汇总只读视图。
//
// 字段对齐 debt.proto ReceivablesSummaryDTO(14 字段)。cents 字段为 int
// (proto Int64 经 mapper `.toInt()`,对齐 holding/budget mapper 的 Int64→int
// 惯例);nextPaymentDate 为可空 DateTime(proto date-only string,空串 → null)。
//
// 复用方:Task 9-11 presentation / bloc 消费此 summary 渲染应收看板(总额、
// 已收、待收利息、逾期笔数、趋势、下一期回款)。本 task 仅 data 层产出,
// 不动 UI。
import 'package:equatable/equatable.dart';

/// 应收债权(borrowedOut)汇总。所有字段不可变;cents 为分(int)。
class ReceivablesSummary extends Equatable {
  const ReceivablesSummary({
    required this.totalPrincipalCents,
    required this.totalRemainingCents,
    required this.totalCollectedCents,
    required this.pendingInterestCents,
    required this.count,
    required this.overdueCount,
    required this.overdueAmountCents,
    required this.principalTrendCents,
    required this.remainingTrendCents,
    this.nextPaymentDate,
    required this.nextPaymentAmountCents,
    required this.nextPaymentCounterparty,
    required this.nextPaymentPeriodNo,
    this.newCountThisMonth = 0,
  });

  /// 本金总额(借出累计)。
  final int totalPrincipalCents;

  /// 剩余待收本金。
  final int totalRemainingCents;

  /// 已收回款(本+利累计)。
  final int totalCollectedCents;

  /// 待收利息(尚未到账)。
  final int pendingInterestCents;

  /// 应收笔数。
  final int count;

  /// 逾期笔数。
  final int overdueCount;

  /// 逾期总额(分)。
  final int overdueAmountCents;

  /// 本月新借出本金(created_at 在当月的 borrowedOut 的 totalPrincipal Σ;
  /// 服务端 created_at 算,非快照,冷启动安全)。
  final int principalTrendCents;

  /// 剩余趋势(用于图表/预警,服务端快照算)。
  final int remainingTrendCents;

  /// 下一期回款日(date-only string 解析后的 DateTime;null = 无计划)。
  final DateTime? nextPaymentDate;

  /// 下一期回款金额(本+利)。
  final int nextPaymentAmountCents;

  /// 下一期回款对方。
  final String nextPaymentCounterparty;

  /// 下一期期数。
  final int nextPaymentPeriodNo;

  /// 本月新增债权笔数(created_at 在当月的 borrowedOut 数;drives trend「新增 N 笔」)。
  final int newCountThisMonth;

  /// 已收比例(0~1)。totalCollected 相对 (totalCollected + totalRemaining)。
  /// 分母 ≤0 时 0(避免除零)。
  double get progressPct {
    final denom = totalCollectedCents + totalRemainingCents;
    return denom <= 0 ? 0 : totalCollectedCents / denom;
  }

  @override
  List<Object?> get props => [
        totalPrincipalCents,
        totalRemainingCents,
        totalCollectedCents,
        pendingInterestCents,
        count,
        overdueCount,
        overdueAmountCents,
        principalTrendCents,
        remainingTrendCents,
        nextPaymentDate,
        nextPaymentAmountCents,
        nextPaymentCounterparty,
        nextPaymentPeriodNo,
        newCountThisMonth,
      ];
}
