// F51 FR-2 / ADR-1 / U2 —— 投资持仓派生两值(纯 domain 函数,无 Flutter/drift 依赖)。
//
// 「loan·invest 双重表示规则化」的 holding 侧:账户侧 invest 双重表示与
// 持仓域共用同一套 Σ成本/Σ市值 口径,规则落 domain 纯函数。落位照
// debt/domain/debt_query.dart 的 F9/F50 先例独立成文件(holding 域首个
// 查询助手文件,依赖单向:holding_query → holding_entity)。
//
// 口径同源(不造第二套):
// - Σ成本 = Σ 每持仓 (quantity × avgCostCents).round() —— 与
//   HoldingLocalDataSource._toEntity 的 cost basis(未实现盈亏同式)一致,
//   **每持仓先取整再求和**(与持仓页逐行展示口径对齐);
// - Σ市值 = Σ [Holding.marketValueCents] —— 市值由 DS(marketValueOf:
//   live price 优先、缺价退 avgCost)在投影里算好,本函数不依赖 price
//   仓库(与 HoldingBloc 汇总 mv += h.marketValueCents 同源)。
import 'package:equatable/equatable.dart';

import 'package:yucai_client/holding/domain/entities/holding_entity.dart';

/// invest 派生两值(F51 FR-2,账户侧 invest 双重表示与持仓域共用口径)。
class DerivedInvestFields extends Equatable {
  const DerivedInvestFields({
    required this.totalCostCents,
    required this.totalMarketValueCents,
  });

  /// Σ成本 = Σ 每持仓 (quantity × avgCostCents).round()(持仓页 cost
  /// basis 同式;每持仓先取整再求和)。
  final int totalCostCents;

  /// Σ市值 = Σ [Holding.marketValueCents](每持仓市值已算好的投影;空 → 0)。
  final int totalMarketValueCents;

  @override
  List<Object?> get props => [totalCostCents, totalMarketValueCents];
}

/// invest 两值聚合(F51 FR-2):Σ成本 + Σ市值。
///
/// [holdings] 为「每持仓市值已算好」的 [Holding] 投影(DS watch 列表即
/// 满足);空列表 → 两值 0(不抛)。
DerivedInvestFields derivedInvestFields(List<Holding> holdings) {
  var cost = 0;
  var mv = 0;
  for (final h in holdings) {
    cost += (h.quantity * h.avgCostCents).round();
    mv += h.marketValueCents;
  }
  return DerivedInvestFields(totalCostCents: cost, totalMarketValueCents: mv);
}
