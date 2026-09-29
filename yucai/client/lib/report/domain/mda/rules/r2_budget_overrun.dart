/// F44 R2 —— 预算超支(FR-2)。
///
/// 各预算项独立评估:超支(actual > limit)→ warn;超支比例
/// (actual−limit)/limit ≥20% → risk;未超支项不触发;budget == null
/// (本期无预算)整规则不触发。超支比例用原始 cents 计算(不经四舍五入的
/// 使用率 pct,避免边界漂移),文案再按 1 位小数呈现。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/mda_rule.dart';
import 'package:yucai_client/report/domain/report_document.dart';

class R2BudgetOverrun extends MdaRule {
  const R2BudgetOverrun();

  @override
  String get id => 'R2';

  @override
  List<MdaFinding> evaluate(ReportDocument doc, MdaSupplement sup) {
    final items = doc.budget?.items;
    if (items == null || items.isEmpty) return const [];

    return [
      for (final item in items)
        if (item.overran) _finding(item),
    ];
  }

  MdaFinding _finding(ReportBudgetItem item) {
    final overCents = item.actualCents - item.limitCents;
    final overrunPct = overCents * 100 / item.limitCents;
    final severity = overrunPct >= MdaThresholds.budgetOverrunRiskPct * 100
        ? MdaSeverity.risk
        : MdaSeverity.warn;
    return MdaFinding(
      ruleId: id,
      severity: severity,
      conclusion: '预算「${item.name}」${severity == MdaSeverity.risk ? '严重' : ''}'
          '超支:实际 ${mdaCny(item.actualCents)},预算 ${mdaCny(item.limitCents)},'
          '使用率 ${item.pct}%,超支 ${mdaRound1(overrunPct)}%'
          '(${mdaCny(overCents)})',
      advice: severity == MdaSeverity.risk
          ? '超支已超两成,建议重设该类预算基线或立刻压减支出'
          : '小幅超支:核对是否一次性支出,连续超支再调预算额度',
      // 行尾语义 chip(原型 .chip.neg「超支 620.00」,金额不带 ¥)。
      chip: MdaChip(
          label: '超支 ${mdaYuan(overCents)}',
          tone: MdaChipTone.negative),
    );
  }
}
