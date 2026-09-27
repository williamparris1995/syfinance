/// F43 R16 财务报告 FR-6:区间绩效分解 VO(T3 LocalPerformanceAssembler
/// 区间扩展输出)。字段口径详见下方类注释(金额 cents、ffill 成交价回放)。
library;

import 'package:equatable/equatable.dart';

/// 区间绩效分解 VO(F43 R16 财务报告 FR-6;T3 LocalPerformanceAssembler
/// 区间扩展输出)。
///
/// 全部金额为 cents、口径与本地收益引擎一致(qty@T 回放 × 成交价前向填充,
/// 无市场价序列)。字段:
/// - [beginMvCents] 期初市值:窗口起点前持仓 × ffill 价;
/// - [endMvCents] 期末市值:窗口末日收盘持仓(含末日成交)× ffill 价;
/// - [netBuyCents] 当期净买入 = Σ买入金额 − Σ卖出金额(不含费用/分红);
/// - [estimatedGainCents] 估算收益 = 期末 − 期初 − 净买入;
/// - [twrPct] 区间 TWR(累计,×100 百分比):期初起链、现金流日子期链接;
///   期初市值为 0 时约定报 0(见 assembler 注释);null = 坏价等数据降级。
class PeriodPerformance extends Equatable {
  const PeriodPerformance({
    required this.beginMvCents,
    required this.endMvCents,
    required this.netBuyCents,
    required this.estimatedGainCents,
    this.twrPct,
  });

  final int beginMvCents;
  final int endMvCents;
  final int netBuyCents;
  final int estimatedGainCents;
  final double? twrPct;

  @override
  List<Object?> get props => [
        beginMvCents,
        endMvCents,
        netBuyCents,
        estimatedGainCents,
        twrPct,
      ];
}
