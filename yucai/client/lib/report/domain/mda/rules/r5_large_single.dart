/// F44 R5 —— 大额单笔(FR-2 双门槛)。
///
/// 单笔支出 ≥ 当期日均支出×3 且 ≥ 当期总支出 20% → info(两门槛
/// 均含等号,单边不触发);日均 = 总支出 ÷ 当期自然天数(含首尾,
/// 由报告期起止推得,不用 incomeStatement.dailyAvgCents——那是
/// 「月报结余/活跃日」异口径)。文案恒带年付语境句(报告不应制造
/// 它要诊断的问题:年付/预付类支出触发本规则属预期)。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/mda_rule.dart';
import 'package:yucai_client/report/domain/report_document.dart';

class R5LargeSingle extends MdaRule {
  const R5LargeSingle();

  @override
  String get id => 'R5';

  @override
  List<MdaFinding> evaluate(ReportDocument doc, MdaSupplement sup) {
    final total = doc.overview.expenseCents;
    if (total <= 0) return const [];

    final days =
        doc.period.endInclusive.difference(doc.period.start).inDays + 1;
    final dailyAvg = total / days;
    final dailyGate = dailyAvg * MdaThresholds.largeSingleDayAvgX;
    final shareGate = total * MdaThresholds.largeSingleSharePct;

    return [
      for (final t in sup.transactions)
        if (t.expenseCents >= dailyGate && t.expenseCents >= shareGate)
          _finding(t, dailyAvg, total),
    ];
  }

  MdaFinding _finding(LargeTxnVO t, double dailyAvg, int total) {
    final multiple = t.expenseCents / dailyAvg;
    final share = t.expenseCents * 100 / total;
    return MdaFinding(
      ruleId: id,
      severity: MdaSeverity.info,
      conclusion: '单笔大额支出:${t.date.month} 月 ${t.date.day} 日'
          '「${t.description}」${mdaCny(t.expenseCents)},'
          '约为日均支出 ${mdaCny(dailyAvg.round())} 的 '
          '${mdaRound1(multiple)} 倍,占当期总支出 ${mdaRound1(share)}%;'
          '若为年付/预付类支出属正常现象',
      advice: '确认该笔是否年付/预付类一次性支出;若是,按年均摊口径'
          '观察更合理',
    );
  }
}
