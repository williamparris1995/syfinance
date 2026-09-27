/// F44 H2 —— 环比突增(FR-2 双门槛)。
///
/// 类别环比 +50% 且增加额 ≥ 当期总支出 5% → warn(双门槛防小基数)。
/// 环比基准 = supplement.priorExpense(前期支出分类构成,T2 汇编层
/// 同通道喂入;ReportDocument 只带 priorComparison 汇总、无前期构成,
/// 类别级口径由此降级通道承载——design LLD 拍板)。前期为 0/缺失的
/// 类别无基准,不触发;环比下降不触发。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/mda_rule.dart';
import 'package:yucai_client/report/domain/report_document.dart';

class H2Spike extends MdaRule {
  const H2Spike();

  @override
  String get id => 'H2';

  @override
  List<MdaFinding> evaluate(ReportDocument doc, MdaSupplement sup) {
    final total = doc.overview.expenseCents;
    if (total <= 0 || sup.priorExpense.isEmpty) return const [];

    final priorByCategory = <String, CategoryAmount>{
      for (final row in sup.priorExpense) row.category: row,
    };

    return [
      for (final cur in doc.incomeStatement.expense)
        if (_spikes(cur, priorByCategory[cur.category], total))
          _finding(cur, priorByCategory[cur.category]!, total),
    ];
  }

  /// 双门槛:环比 ≥+50% 且增加额 ≥ 当期总支出 5%(均含等号)。
  bool _spikes(CategoryAmount cur, CategoryAmount? prior, int total) {
    if (prior == null || prior.amountCents <= 0) return false; // 无基准
    final delta = cur.amountCents - prior.amountCents;
    if (delta <= 0) return false; // 下降不触发
    return delta / prior.amountCents >= MdaThresholds.spikePct &&
        delta / total >= MdaThresholds.spikeSharePct;
  }

  MdaFinding _finding(CategoryAmount cur, CategoryAmount prior, int total) {
    final delta = cur.amountCents - prior.amountCents;
    final deltaPct = mdaRound1(delta * 100 / prior.amountCents);
    final share = mdaRound1(delta * 100 / total);
    return MdaFinding(
      ruleId: id,
      severity: MdaSeverity.warn,
      conclusion: '「${cur.name ?? cur.category}」支出环比突增:'
          '本期 ${mdaCny(cur.amountCents)},较上期 ${mdaCny(prior.amountCents)} '
          '+$deltaPct%,增加 ${mdaCny(delta)}(占本期总支出 $share%)',
      advice: '核对是否一次性/季节性支出;该类持续上行可设预算线观察',
    );
  }
}
