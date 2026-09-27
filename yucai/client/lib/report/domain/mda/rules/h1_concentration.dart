/// F44 H1 —— 支出集中度(FR-2)。
///
/// 支出构成首条(汇编层已按金额降序)占比 ≥40% → warn;中性表述
/// 「支出集中于 XX 类别」(不用恩格尔等标签,FR-2 拍板);类别名回退:
/// name 为 null/空时用 category 代码(渲染层兜底同口径)。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/mda_rule.dart';
import 'package:yucai_client/report/domain/report_document.dart';

class H1Concentration extends MdaRule {
  const H1Concentration();

  @override
  String get id => 'H1';

  @override
  List<MdaFinding> evaluate(ReportDocument doc, MdaSupplement sup) {
    final expense = doc.incomeStatement.expense;
    if (expense.isEmpty) return const [];

    final top = expense.first; // 汇编已按金额降序,首条即最大类
    if (top.pct < MdaThresholds.concentrationPct * 100) return const [];

    final label = (top.name == null || top.name!.isEmpty)
        ? top.category
        : top.name!;
    return [
      MdaFinding(
        ruleId: id,
        severity: MdaSeverity.warn,
        conclusion: '支出集中于「$label」类别:本期 ${mdaCny(top.amountCents)},'
            '占当期总支出 ${top.pct}%',
        advice: '可结合该类明细确认集中是否来自少数高频/大额场景,'
            '无需立刻削减',
      ),
    ];
  }
}
