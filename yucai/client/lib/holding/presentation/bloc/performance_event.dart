// 收益统计页 Bloc 事件(Task 13,holding-C)。
//
// 职责分离:performance 页独立 PerformanceBloc(不复用 HoldingBloc),
// 仅消费 HoldingRepository.getPortfolioPerformance(Task 12)。
//
// range 取**大写英文串** 'DAY'/'MONTH'/'YEAR'(对齐 mapper curveRangeToProto,
// 未知值折叠为 DAY)。**不可传 PerfRange.label**(中文 '日/月/年')。
// UI 层用 PerfRange enum,经 rangeName() 映射为大写串再发事件(见
// performance_page.dart)。
import 'package:equatable/equatable.dart';

abstract class PerformanceEvent extends Equatable {
  const PerformanceEvent();
  @override
  List<Object?> get props => [];
}

/// 拉取组合收益曲线 + 盈亏明细。
///
/// [range] 大写英文串('DAY'/'MONTH'/'YEAR',默认 DAY)。
/// [accountId] 可选账户过滤(组合级默认全账户)。
/// [baseCurrency] 折算本位币(ISO code,Task 12 D-currency;来自
/// CurrencySettings.getBaseCurrency(),空/CNY → server 不折算)。
class LoadPortfolioPerformanceRequested extends PerformanceEvent {
  const LoadPortfolioPerformanceRequested({
    this.range = 'DAY',
    this.accountId,
    this.baseCurrency = '',
  });
  final String range;
  final String? accountId;
  final String baseCurrency;
  @override
  List<Object?> get props => [range, accountId, baseCurrency];
}
