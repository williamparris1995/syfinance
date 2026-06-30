import 'package:equatable/equatable.dart';

import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';

abstract class HoldingState extends Equatable {
  const HoldingState();
  @override
  List<Object?> get props => [];
}

class HoldingInitial extends HoldingState {}

class HoldingLoading extends HoldingState {}

/// 持仓汇总(纯前端展示模型,非 proto DTO)。
///
/// holding.proto 无 summary RPC / DTO —— 本结构由 bloc 从 List<Holding>
/// 聚合计算(totalCostCents 按 quantity*avgCostCents 重建,因为 proto
/// HoldingDTO 未暴露总成本字段;totalPnlCents 来自 unrealizedPnlCents 求和)。
/// 放在此处(而非 domain/entities)因其仅服务于列表页展示,bloc 直接构造。
class HoldingSummary extends Equatable {
  const HoldingSummary({
    required this.totalCostCents,
    required this.totalMarketValueCents,
    required this.totalPnlCents,
  });
  final int totalCostCents; // 总投入成本(分)= Σ quantity*avgCostCents
  final int totalMarketValueCents; // 总市值(分)= Σ marketValueCents
  final int totalPnlCents; // 总未实现盈亏(分)= Σ unrealizedPnlCents

  @override
  List<Object?> get props => [
        totalCostCents,
        totalMarketValueCents,
        totalPnlCents,
      ];
}

/// 列表页 loaded 状态。`typeFilter` 回显当前过滤,供 UI 高亮 tab;
/// `securities` 供表单选择器复用(可空,LoadSecuritiesRequested 单独加载时
/// 仍保留上次列表背景)。
class HoldingLoaded extends HoldingState {
  HoldingLoaded({
    required this.holdings,
    required this.summary,
    this.securities = const [],
    this.typeFilter,
    this.lastPriceSyncedAt,
  });
  final List<Holding> holdings;
  final HoldingSummary summary;
  final List<Security> securities;
  final SecurityType? typeFilter;
  final DateTime? lastPriceSyncedAt; // 上次价格刷新时间(client 本地记录,拍板点①)

  @override
  List<Object?> get props => [holdings, summary, securities, typeFilter, lastPriceSyncedAt];
}

/// 详情页 loaded 状态。`pnlBreakdown` 可空(盈亏明细,前端计算/扩展用)。
///
/// `isPendingBackend` 为 true 时表示交易历史来自 ⏳ 端点降级(trades=空,
/// holding 已从 listHoldings 成功获取)——UI 保留 holding 卡/曲线/配置/关联目标
/// 7 组件主体,仅交易历史区显示「⏳ 待后端」空态(对齐 brief)。
class HoldingDetailLoaded extends HoldingState {
  const HoldingDetailLoaded({
    required this.holding,
    required this.trades,
    this.pnlBreakdown,
    this.isPendingBackend = false,
  });
  final Holding holding;
  final List<HoldingTransaction> trades;
  final Map<String, int>? pnlBreakdown;
  final bool isPendingBackend;

  @override
  List<Object?> get props => [holding, trades, pnlBreakdown, isPendingBackend];
}

/// 提交中:携带上次状态,UI 保持背景列表/详情不变。
class HoldingSubmitting extends HoldingState {
  const HoldingSubmitting({this.last});
  final HoldingState? last;
  @override
  List<Object?> get props => [last];
}

/// 错误状态。
///
/// `last` 携带上次成功状态供 UI 恢复背景;`isPendingBackend` 区分
/// 后端兜底降级(ListHoldingTransactions 等网络/后端异常 fail)与真业务错误
/// —— 前者为 true,UI 显示空态而非报错。
class HoldingError extends HoldingState {
  const HoldingError(
    this.message, {
    this.last,
    this.isPendingBackend = false,
  });
  final String message;
  final HoldingState? last;
  final bool isPendingBackend;

  @override
  List<Object?> get props => [message, last, isPendingBackend];
}
