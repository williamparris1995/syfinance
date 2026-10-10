// TDD RED → GREEN:F51 invest 派生两值纯函数(derivedInvestFields)单测。
//
// F51 FR-2(spec)/ADR-1、U2(design):「loan·invest 双重表示规则化」的
// holding 侧 —— 账户侧 invest 双重表示与持仓域共用同一套 Σ成本/Σ市值
// 口径,规则落 domain 纯函数(照 debt/domain/debt_query.dart F50 先例,
// holding 域新增 holding_query.dart)。口径同源(不造第二套):
//   Σ成本 = Σ 每持仓 (quantity × avgCostCents).round() —— 与
//     HoldingLocalDataSource._toEntity 的 cost basis(盈亏同式)一致,
//     每持仓先取整再求和;
//   Σ市值 = Σ Holding.marketValueCents —— 市值由 DS(marketValueOf:live
//     price 优先、退 avgCost)在投影里算好,函数不依赖 price 仓库
//     (与 HoldingBloc 汇总 mv += h.marketValueCents 同源)。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/holding_query.dart';

/// 持仓 fixture(照 holding_bloc_test.sampleHolding 范式)。
Holding _h(
  String id,
  double quantity,
  int avgCostCents,
  int marketValueCents,
) =>
    Holding(
      id: id,
      accountId: 'a-$id',
      securityId: 's-$id',
      securityName: '证券$id',
      securitySymbol: 'SYM$id',
      quantity: quantity,
      avgCostCents: avgCostCents,
      marketValueCents: marketValueCents,
      unrealizedPnlCents: marketValueCents - (quantity * avgCostCents).round(),
      version: 1,
    );

void main() {
  group('derivedInvestFields(F51 invest 两值聚合)', () {
    test('两持仓成本/市值求和', () {
      final holdings = [
        // 成本 10 × 1,000 = 10,000;市值 12,000。
        _h('h1', 10, 1000, 12000),
        // 成本 25.5 × 3,200 = 81,600;市值 90,000。
        _h('h2', 25.5, 3200, 90000),
      ];
      final r = derivedInvestFields(holdings);
      expect(r.totalCostCents, 91600); // 10,000 + 81,600
      expect(r.totalMarketValueCents, 102000); // 12,000 + 90,000
    });

    test('成本口径:每持仓先取整再求和(与 DS cost basis 同式)', () {
      final holdings = [
        // 0.1 × 334 = 33.4 → 每持仓 round → 33(两笔 66;若先求和 66.8 → 67,
        // 与持仓页每行口径漂移 —— 锁定「每持仓先取整」)。
        _h('frac1', 0.1, 334, 33),
        _h('frac2', 0.1, 334, 33),
      ];
      expect(derivedInvestFields(holdings).totalCostCents, 66);
    });

    test('空列表 → 两值 0(不抛)', () {
      final r = derivedInvestFields(const []);
      expect(r.totalCostCents, 0);
      expect(r.totalMarketValueCents, 0);
    });
  });
}
