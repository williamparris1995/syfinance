// F65-T1 —— goals_list 只读工具(FR-2,目标进度)。
//
// 流程:GoalRepository.listGoals()(与目标页同一条读路径,当前金额 =
// 读时三源 actuals:investment=Σ持仓市值 / savings=Σ账户余额 /
// debtPayoff=Σ期次已还;无挂接 → 手工记录值直读)→ 每目标
// {名称/类型/目标额(cents+元)/当前额/剩余/进度%/截止日(若有)/完成
// 标记}+ 汇总。「预计达成」:域内无该派生(GoalView 无投影字段,页面
// 也不算)→ 只如实输出 deadline,不编造预测数字(FR-5 禁编造)。
// 逐分一致由 tools_caliber_test 参数化钉死(NFR-1 八工具化)。
library;

import 'package:yucai_client/assistant/data/tools/tool_args.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';

/// 目标进度工具:每目标行 + 汇总(读时 actuals,与目标页同源)。
class GoalsListTool implements AssistantTool {
  GoalsListTool(this._goals);

  final GoalRepository _goals;

  @override
  String get name => 'goals_list';

  @override
  String get description =>
      'Lists savings, debt-payoff and investment goals with their progress, '
      'same numbers as the goals page: per goal name/type/target amount/'
      'current amount/remaining/progress percent/deadline (when set) and a '
      'completed flag, plus a summary. Current amounts are computed at read '
      'time from linked accounts, debts or holdings. There is no projected '
      'completion date in the data - do not invent one; use the deadline '
      'field. Use for "how is my emergency fund / am I close to my goal". '
      'No parameters. Not for contributing to goals or editing them.';

  @override
  Map<String, Object> get parametersSchema => const {
        'type': 'object',
        'properties': <String, Object>{},
      };

  @override
  Future<ToolResult> execute(Map<String, Object> args) async {
    final result = await _goals.listGoals();
    final goals = result.fold((l) => null, (r) => r);
    if (goals == null) {
      return const ToolError(
        'failed to load goals from the local store; '
        'ask the user to retry later',
      );
    }

    var totalTarget = 0;
    var totalCurrent = 0;
    var completedCount = 0;
    final rows = <Map<String, Object>>[];
    for (final g in goals) {
      if (g.isCompleted) completedCount++;
      totalTarget += g.targetAmountCents;
      totalCurrent += g.currentAmountCents;
      rows.add({
        'name': g.name,
        'type': g.type.name,
        'targetAmountCents': g.targetAmountCents,
        'targetAmountYuan': yuan(g.targetAmountCents),
        'currentAmountCents': g.currentAmountCents,
        'currentAmountYuan': yuan(g.currentAmountCents),
        'remainingCents': g.remainingCents,
        'remainingYuan': yuan(g.remainingCents),
        'progressPct': g.progressPct,
        if (g.deadline != null)
          'deadline': '${g.deadline!.year.toString().padLeft(4, '0')}-'
              '${g.deadline!.month.toString().padLeft(2, '0')}-'
              '${g.deadline!.day.toString().padLeft(2, '0')}',
        'isCompleted': g.isCompleted,
        if (g.currencyCode.isNotEmpty) 'currency': g.currencyCode,
      });
    }

    return ToolData({
      'goals': rows,
      'summary': {
        'count': goals.length,
        'activeCount': goals.length - completedCount,
        'completedCount': completedCount,
        'totalTargetCents': totalTarget,
        'totalTargetYuan': yuan(totalTarget),
        'totalCurrentCents': totalCurrent,
        'totalCurrentYuan': yuan(totalCurrent),
      },
    });
  }
}
