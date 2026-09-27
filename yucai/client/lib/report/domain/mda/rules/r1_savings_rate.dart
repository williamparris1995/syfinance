/// F44 R1 —— 储蓄率分层(FR-2)。
///
/// 结余为负 → risk「本期透支」;储蓄率 <10% → risk;10-20% → warn;
/// ≥20% 通过;收入 ≤ 0 不触发(储蓄率无定义,不除零)。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/mda_rule.dart';
import 'package:yucai_client/report/domain/report_document.dart';

class R1SavingsRate extends MdaRule {
  const R1SavingsRate();

  @override
  String get id => 'R1';

  @override
  List<MdaFinding> evaluate(ReportDocument doc, MdaSupplement sup) {
    final ov = doc.overview;
    if (ov.incomeCents <= 0) return const [];

    final riskLine =
        (MdaThresholds.savingsRiskBelow * 100).round(); // 展示用整数 10
    final warnLine = (MdaThresholds.savingsWarnBelow * 100).round(); // 20
    final surplus = mdaCny(ov.surplusCents);
    final income = mdaCny(ov.incomeCents);

    if (ov.surplusCents < 0) {
      return [
        MdaFinding(
          ruleId: id,
          severity: MdaSeverity.risk,
          conclusion: '本期透支:支出 ${mdaCny(ov.expenseCents)} 超过收入 '
              '$income,结余 $surplus',
          advice: '核对超支来源,优先压减可选支出,下期恢复正结余',
        ),
      ];
    }
    if (ov.savingsRate < MdaThresholds.savingsRiskBelow * 100) {
      return [
        MdaFinding(
          ruleId: id,
          severity: MdaSeverity.risk,
          conclusion: '储蓄率 ${ov.savingsRate}%,低于 $riskLine%'
              '(结余 $surplus / 收入 $income)',
          advice: '先守住 $riskLine% 底线:发薪日先转存再消费',
        ),
      ];
    }
    if (ov.savingsRate < MdaThresholds.savingsWarnBelow * 100) {
      return [
        MdaFinding(
          ruleId: id,
          severity: MdaSeverity.warn,
          conclusion: '储蓄率 ${ov.savingsRate}%,低于 $warnLine%'
              '(结余 $surplus / 收入 $income)',
          advice: '接近 $warnLine% 常用目标:可尝试自动转存或削减一类非必要支出',
        ),
      ];
    }
    return const [];
  }
}
