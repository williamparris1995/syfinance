/// F44 规则诊断引擎 —— 执行器(FR-1/ADR-2)。
///
/// 不可变规则表 + 遍历执行:全规则跑完后按 severity(risk>warn>info)
/// 稳定排序——同 severity 保持规则表序(Dart List.sort 非稳定,故按
/// severity 分桶拼接,不入 sort)。规则表顺序 = 风险类前:
/// [R1,R6,R2,R3,R4,H1,H2,R5](design LLD 拍板)。
library;

import 'package:injectable/injectable.dart';

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/mda_rule.dart';
import 'package:yucai_client/report/domain/mda/rules/h1_concentration.dart';
import 'package:yucai_client/report/domain/mda/rules/h2_spike.dart';
import 'package:yucai_client/report/domain/mda/rules/r1_savings_rate.dart';
import 'package:yucai_client/report/domain/mda/rules/r2_budget_overrun.dart';
import 'package:yucai_client/report/domain/mda/rules/r3_debt_ratio.dart';
import 'package:yucai_client/report/domain/mda/rules/r4_idle_subscription.dart';
import 'package:yucai_client/report/domain/mda/rules/r5_large_single.dart';
import 'package:yucai_client/report/domain/mda/rules/r6_runway.dart';
import 'package:yucai_client/report/domain/report_document.dart';

@LazySingleton()
class MdaEngine {
  const MdaEngine();

  /// 规则表(顺序即同 severity 内的输出序;风险类前置)。
  static const List<MdaRule> rules = [
    R1SavingsRate(),
    R6Runway(),
    R2BudgetOverrun(),
    R3DebtRatio(),
    R4IdleSubscription(),
    H1Concentration(),
    H2Spike(),
    R5LargeSingle(),
  ];

  /// 对一份报告快照执行全部规则,输出排序汇总后的诊断章节。
  MdaSection evaluate(ReportDocument doc, MdaSupplement sup) {
    final bySeverity = {
      MdaSeverity.risk: <MdaFinding>[],
      MdaSeverity.warn: <MdaFinding>[],
      MdaSeverity.info: <MdaFinding>[],
    };
    for (final rule in rules) {
      for (final finding in rule.evaluate(doc, sup)) {
        bySeverity[finding.severity]!.add(finding);
      }
    }
    final sorted = [
      ...bySeverity[MdaSeverity.risk]!,
      ...bySeverity[MdaSeverity.warn]!,
      ...bySeverity[MdaSeverity.info]!,
    ];
    return MdaSection.create(findings: sorted);
  }
}
