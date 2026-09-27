/// F44 R6 —— runway 备用金(FR-2)。
///
/// 近 3 月均支出(trailing3m÷3)>0 时:现金可支撑月数 = cashEnd ÷ 月均;
/// <1 → risk;<3 → warn;≥3 通过;trailing3m == 0 不触发(无基数)。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/mda_rule.dart';
import 'package:yucai_client/report/domain/report_document.dart';

class R6Runway extends MdaRule {
  const R6Runway();

  @override
  String get id => 'R6';

  @override
  List<MdaFinding> evaluate(ReportDocument doc, MdaSupplement sup) {
    if (sup.trailing3mExpenseCents <= 0) return const [];

    final monthlyAvg = sup.trailing3mExpenseCents / 3;
    final months = sup.cashEndCents / monthlyAvg;

    MdaSeverity? severity;
    if (months < MdaThresholds.runwayRiskMonths) {
      severity = MdaSeverity.risk;
    } else if (months < MdaThresholds.runwayWarnMonths) {
      severity = MdaSeverity.warn;
    }
    if (severity == null) return const [];

    final monthsLabel = mdaRound1(months).toString();
    return [
      MdaFinding(
        ruleId: id,
        severity: severity,
        conclusion: '现金可支撑约 $monthsLabel 个月'
            '(期末现金 ${mdaCny(sup.cashEndCents)} ÷ 近 3 月均月支出 '
            '${mdaCny(monthlyAvg.round())})',
        advice: '目标是攒足 3-6 个月基本生活费的应急备用金;短期可先压减'
            '非必要支出提升现金缓冲',
      ),
    ];
  }
}
