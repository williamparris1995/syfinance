/// F44 R3 —— 资产负债率(FR-2)。
///
/// 期末资产负债率(既有字段 debtRatioPct,1 位小数):≥70% → risk;
/// 50-70% → warn(warn 文案带房贷语境附注:长期房贷期的负债率偏高属
/// 常见区间,不与消费负债同等恐慌);<50% 通过;资产 ≤0(null)不触发。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/mda_rule.dart';
import 'package:yucai_client/report/domain/report_document.dart';

class R3DebtRatio extends MdaRule {
  const R3DebtRatio();

  @override
  String get id => 'R3';

  @override
  List<MdaFinding> evaluate(ReportDocument doc, MdaSupplement sup) {
    final bs = doc.balanceSheet;
    final ratio = bs.debtRatioPct;
    if (ratio == null) return const [];

    const riskLine = MdaThresholds.debtRiskAt * 100; // 70.0
    const warnLine = MdaThresholds.debtWarnAt * 100; // 50.0

    MdaSeverity? severity;
    String context;
    if (ratio >= riskLine) {
      severity = MdaSeverity.risk;
      context = '偿债压力偏高,建议优先压降高息负债';
    } else if (ratio >= warnLine) {
      severity = MdaSeverity.warn;
      context = '若含长期房贷属常见区间';
    } else {
      return const [];
    }

    return [
      MdaFinding(
        ruleId: id,
        severity: severity,
        conclusion: '资产负债率 $ratio%'
            '(负债 ${mdaCny(bs.liabilitiesTotalCents)} / '
            '资产 ${mdaCny(bs.assetsTotalCents)}),$context',
        advice: severity == MdaSeverity.risk
            ? '优先偿还利率高于投资回报的负债,避免新增高息借款'
            : '关注高息负债占比;房贷等长期低息负债可按还款计划正常推进',
      ),
    ];
  }
}
