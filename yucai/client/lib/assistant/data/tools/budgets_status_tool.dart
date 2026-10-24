// F65-T1 —— budgets_status 只读工具(FR-2,预算执行度)。
//
// 流程:BudgetRepository.listBudgets()(与预算页同一条读路径,读时
// actuals = 账户级 max(Σdebit,Σcredit) 大边口径,server 规则)→
// 每预算 {名称/月份/额度(cents+元)/已用/剩余/执行度%/超支标记}+
// 汇总 {count/超支数/总额度/总已用/总剩余}。无参数。逐分一致由
// tools_caliber_test 参数化钉死(NFR-1 八工具化)。
library;

import 'package:yucai_client/assistant/data/tools/tool_args.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';

/// 预算执行度工具:每预算行 + 汇总(读时 actuals,与预算页同源)。
class BudgetsStatusTool implements AssistantTool {
  BudgetsStatusTool(this._budgets);

  final BudgetRepository _budgets;

  @override
  String get name => 'budgets_status';

  @override
  String get description =>
      'Lists every budget with its execution status, same numbers as the '
      'budget page: per budget name/month/limit/actual spend/remaining/'
      'usage percent and an over-budget flag, plus a cross-budget summary. '
      'Actual spend is the larger-side total per covered account within the '
      'budget month (refunds can offset). Use for "am I over budget / how '
      'much is left in my budget". No parameters. Not for setting budgets '
      'or per-category breakdowns beyond the budgeted accounts.';

  @override
  Map<String, Object> get parametersSchema => const {
        'type': 'object',
        'properties': <String, Object>{},
      };

  @override
  Future<ToolResult> execute(Map<String, Object> args) async {
    final result = await _budgets.listBudgets();
    final budgets = result.fold((l) => null, (r) => r);
    if (budgets == null) {
      return const ToolError(
        'failed to load budgets from the local store; '
        'ask the user to retry later',
      );
    }

    // 确定性序:月份降序(近月在前),tie-break name/id 升序。
    final sorted = [...budgets]..sort((a, b) {
        final byMonth = b.month.compareTo(a.month);
        if (byMonth != 0) return byMonth;
        final byName = a.name.compareTo(b.name);
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });

    var totalLimit = 0;
    var totalActual = 0;
    var overBudgetCount = 0;
    final rows = <Map<String, Object>>[];
    for (final b in sorted) {
      final remaining = b.totalRemainingCents;
      if (b.isOverBudget) overBudgetCount++;
      totalLimit += b.totalAmountCents;
      totalActual += b.totalActualCents;
      rows.add({
        'name': b.name,
        'month': b.month,
        'currency': b.currencyCode,
        'limitCents': b.totalAmountCents,
        'limitYuan': yuan(b.totalAmountCents),
        'actualCents': b.totalActualCents,
        'actualYuan': yuan(b.totalActualCents),
        'remainingCents': remaining,
        'remainingYuan': yuan(remaining),
        'usagePct': b.usagePct,
        'overBudget': b.isOverBudget,
      });
    }

    return ToolData({
      'budgets': rows,
      'summary': {
        'count': sorted.length,
        'overBudgetCount': overBudgetCount,
        'totalLimitCents': totalLimit,
        'totalLimitYuan': yuan(totalLimit),
        'totalActualCents': totalActual,
        'totalActualYuan': yuan(totalActual),
        'totalRemainingCents': totalLimit - totalActual,
        'totalRemainingYuan': yuan(totalLimit - totalActual),
      },
    });
  }
}
