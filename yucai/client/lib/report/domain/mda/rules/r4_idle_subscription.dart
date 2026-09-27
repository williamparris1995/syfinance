/// F44 R4 —— 闲置订阅近似口径(FR-3,四道防御)。
///
/// 近似口径:本地交易行无模板关联、无扣费日志镜像,只能以
/// 「期内有应扣日 + 最近记账未推进到应扣日附近」近似判定。四道防御:
/// ①疑问式文案(禁断言);②grace 宽限(nextDate 在期末后
/// [MdaThresholds.idleGraceDays] 天内不报);③级别恒 warn(≤warn);
/// ④actionLink 跳订阅中心 /accounts/subscriptions(router 实际路由)。
///
/// 月度等价口径(可行口径,注释说明):supplement 无显式周期月数字段,
/// 由「期内最后一个应扣日 → nextDate」的间距推周期:
/// months = round(天数 ÷ 30.4375),最小 1(年付 365d→12、月付 31d→1);
/// nextDate 缺失或早于应扣日(异常数据)时兜底按 1 个月,注释钉死口径。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/mda_rule.dart';
import 'package:yucai_client/report/domain/report_document.dart';

class R4IdleSubscription extends MdaRule {
  const R4IdleSubscription();

  /// 平均月长(365.25/12):周期月数换算基数。
  static const double _avgMonthDays = 30.4375;

  @override
  String get id => 'R4';

  @override
  List<MdaFinding> evaluate(ReportDocument doc, MdaSupplement sup) {
    final periodEnd = doc.period.endInclusive;
    final graceCutoff = periodEnd.add(
      const Duration(days: MdaThresholds.idleGraceDays),
    );

    final idle = <TemplateRowVO>[];
    for (final t in sup.templates) {
      if (!t.expense || t.paused) continue;
      if (t.expectedDates.isEmpty) continue; // 期内无应扣日

      // 防御②grace:nextDate 在 (期末, 期末+7天] 内 → 即将扣费,不报。
      final next = t.nextDate;
      if (next != null && next.isAfter(periodEnd) && !next.isAfter(graceCutoff)) {
        continue;
      }

      // 近似判定:从未记账,或最近记账早于期内首个应扣日−1 天
      // (−1 天 = 扣费日附近入账的时点宽松,跨日入账防御)。
      final firstExpected = t.expectedDates.first;
      final last = t.lastRecordedDate;
      final recorded = last != null &&
          !last.isBefore(firstExpected.subtract(const Duration(days: 1)));
      if (recorded) continue;

      idle.add(t);
    }
    if (idle.isEmpty) return const [];

    // 多条闲置 → 单条 finding 合计月度等价(spec FR-3)。
    var monthlyTotal = 0;
    for (final t in idle) {
      monthlyTotal += (t.amountCents / _periodMonths(t)).round();
    }
    final names = idle.map((t) => t.name).join('、');

    return [
      MdaFinding(
        ruleId: id,
        severity: MdaSeverity.warn, // 防御③:级别 ≤ warn
        conclusion: '可能闲置:${idle.length} 个支出订阅($names)在本期有应扣日'
            '但未见关联记账,月度等价合计约 ${mdaCny(monthlyTotal)};'
            '若仍在使用,记一笔时请关联该订阅',
        advice: '到订阅中心核对:仍在使用则记账时关联该订阅(规则即可校准),'
            '已不用则暂停或删除模板',
        actionLink: '/accounts/subscriptions', // 防御④:跳订阅中心
      ),
    ];
  }

  /// 周期月数:期内最后一个应扣日 → nextDate 的间距换算。
  int _periodMonths(TemplateRowVO t) {
    final next = t.nextDate;
    final lastExpected = t.expectedDates.last;
    if (next == null || !next.isAfter(lastExpected)) return 1; // 异常兜底
    final months =
        (next.difference(lastExpected).inDays / _avgMonthDays).round();
    return months < 1 ? 1 : months;
  }
}
