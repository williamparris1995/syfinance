// F65-T1 —— holdings_list 只读工具(FR-2,持仓面板口径)。
//
// 流程:HoldingRepository.listHoldings() → name 过滤(contains 忽略大小写,
// symbol/name 双字段,与 F9 搜索/DS listPaged 同口径)→ 市值降序基准序
// (tie-break symbol/id 升序,DS listPaged 同式)→ 分页页片。
//
// 口径 = 持仓面板同源:每标的 {名称/代码/数量/成本(cents+元)/市值/浮动
// 盈亏+百分比};汇总 = HoldingSummary 同式(Σ成本 = Σ round(qty×avgCost),
// holding_bloc._summarize→derivedInvestFields 同式;Σ市值/Σ浮盈 = 直和);
// pnlPct = pnl/cost×100(页面同式,零成本 → 0 不除零)。逐分一致由
// tools_caliber_test 参数化钉死(NFR-1 八工具化)。
library;

import 'package:yucai_client/assistant/data/tools/tool_args.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';

/// 持仓列表工具:面板口径每标的行 + 汇总,name 过滤 + 分页。
class HoldingsListTool implements AssistantTool {
  HoldingsListTool(this._holdings);

  final HoldingRepository _holdings;

  @override
  String get name => 'holdings_list';

  @override
  String get description =>
      'Lists current investment holdings with the same numbers as the '
      'holdings page: per security name/symbol/quantity/cost/market value/'
      'unrealized PnL with percentage, plus a portfolio summary (total cost, '
      'total market value, total unrealized PnL). Market value uses the live '
      'price when available, else the average-cost basis (honest stale '
      'fallback). Optional name filter matches symbol or name '
      '(case-insensitive contains). Use for "what do I hold / how much have '
      'my investments gained or lost". Not for range performance (use '
      'performance_range) or account balances.';

  @override
  Map<String, Object> get parametersSchema => const {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description':
                'Optional filter: match security symbol or name '
                '(case-insensitive contains).',
          },
          'page': {
            'type': 'integer',
            'minimum': 1,
            'description': '1-based page number (default 1).',
          },
          'page_size': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 50,
            'description': 'Items per page, 1..50 (default 20).',
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, Object> args) async {
    final query = lenientString(args['name'])?.toLowerCase();
    final page = parsePagination(args);

    final result = await _holdings.listHoldings();
    final List<Holding>? all = result.fold((l) => null, (r) => r);
    if (all == null) {
      return const ToolError(
        'failed to load holdings from the local store; '
        'ask the user to retry later',
      );
    }

    // name 过滤(symbol/name contains 忽略大小写,DS listPaged 同式)。
    var visible = query == null
        ? all
        : all
            .where((h) =>
                h.securitySymbol.toLowerCase().contains(query) ||
                h.securityName.toLowerCase().contains(query))
            .toList();

    // 市值降序基准序(tie-break symbol/id 升序,DS listPaged 同式)。
    visible = [...visible]..sort((a, b) {
        final byMv = b.marketValueCents.compareTo(a.marketValueCents);
        if (byMv != 0) return byMv;
        final bySymbol = a.securitySymbol.compareTo(b.securitySymbol);
        return bySymbol != 0 ? bySymbol : a.id.compareTo(b.id);
      });

    // 汇总(HoldingSummary 同式:Σ round(qty×avgCost) 成本 / Σ市值 / Σ浮盈)。
    var totalCost = 0;
    var totalMv = 0;
    var totalPnl = 0;
    for (final h in visible) {
      totalCost += (h.quantity * h.avgCostCents).round();
      totalMv += h.marketValueCents;
      totalPnl += h.unrealizedPnlCents;
    }

    final start = (page.page - 1) * page.pageSize;
    final slice = start >= visible.length
        ? const <Holding>[]
        : visible.skip(start).take(page.pageSize).toList();

    return ToolData({
      if (query != null) 'name': query,
      'holdings': [
        for (final h in slice)
          {
            'name': h.securityName,
            'symbol': h.securitySymbol,
            'quantity': h.quantity,
            'avgCostCents': h.avgCostCents,
            'avgCostYuan': yuan(h.avgCostCents),
            'costCents': (h.quantity * h.avgCostCents).round(),
            'costYuan': yuan((h.quantity * h.avgCostCents).round()),
            'marketValueCents': h.marketValueCents,
            'marketValueYuan': yuan(h.marketValueCents),
            'unrealizedPnlCents': h.unrealizedPnlCents,
            'unrealizedPnlYuan': yuan(h.unrealizedPnlCents),
            // 页面同式:pnl/cost×100;零成本 → 0(不除零)。
            'pnlPct': _pct(h.unrealizedPnlCents, h.quantity * h.avgCostCents),
            if (h.currency != null) 'currency': h.currency,
          }
      ],
      'summary': {
        'count': visible.length,
        'totalCostCents': totalCost,
        'totalCostYuan': yuan(totalCost),
        'totalMarketValueCents': totalMv,
        'totalMarketValueYuan': yuan(totalMv),
        'totalPnlCents': totalPnl,
        'totalPnlYuan': yuan(totalPnl),
        'totalPnlPct': _pct(totalPnl, totalCost),
      },
      ...paginationMeta(
        page: page.page,
        pageSize: page.pageSize,
        totalCount: visible.length,
      ),
    });
  }

  /// pnl/cost×100(holdings_page 同式;cost ≤ 0 → 0,不除零)。
  static double _pct(int pnl, num cost) =>
      cost <= 0 ? 0.0 : pnl * 100 / cost;
}
