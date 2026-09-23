/// 信用卡「账单周期」面板 —— v5 原型**变体 B「应还拆解」**(2026-09-23
/// 用户拍板;布局契约照 prototype/v5/ui/credit-card-account.html 快照):
/// 应答优先的欠款拆解,直答「还款日要还多少」。
///
/// 结构:①应答块(accentSoft 软底)——「还款日 X日 · 应还」+「还有 N 天」
/// chip + 应还大字(= [CreditCardStatementBreakdown.remainingCents],与催办
/// toast/聚合条/还款对话框同一数字,强调色)+ 恢复等式推导行;②「当前
/// 欠款构成」比例条 + 双行图例(上期剩余/本期账单占比,把「上期剩余 +
/// 本期账单 = 当前欠款」恒等式做成一段可视化)。
///
/// 纯展示:数据由页面经 [CreditCardStatementDue.breakdown] 算好注入(共享
/// 推导,单一口径);账单日未设 → 降级一行 muted 提示 + 可选「去设置」
/// (页面注入回调)。语义令牌零裸色;金额千分位两位小数(同详情页
/// _fmtSigned 口径)。
library;

import 'package:flutter/material.dart';

import 'package:yucai_client/core/notifications/credit_card_statement.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';

class CreditCardStatementPanel extends StatelessWidget {
  const CreditCardStatementPanel({
    super.key,
    required this.billingDay,
    this.repaymentDay,
    required this.currencyCode,
    this.breakdown,
    this.onSetupBilling,
    this.clock,
  });

  /// 卡的账单日(null = 未设 → 降级提示行)。
  final int? billingDay;

  /// 卡的还款日(可缺:应答块标签退「应还」,无「还有 N 天」chip)。
  final int? repaymentDay;

  /// 金额符号随卡币种(不换算)。
  final String currencyCode;

  /// 周期拆解(null = 未加载,主体暂不渲染;账单日未设时恒 null)。
  final CreditCardStatementBreakdown? breakdown;

  /// 降级提示行「去设置」回调(页面接编辑账户;null = 不渲染按钮)。
  final VoidCallback? onSetupBilling;

  /// 时钟注入(「还有 N 天」chip 可测;缺省 DateTime.now)。
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('账单周期', style: TextStyle(fontWeight: FontWeight.w600)),
          if (billingDay != null) ...[
            const SizedBox(height: 4),
            Text(
              repaymentDay == null
                  ? '账单日 $billingDay日'
                  : '账单日 $billingDay日 · 还款日 $repaymentDay日',
              style: TextStyle(
                  fontSize: 12,
                  color: context.yucai.muted,
                  fontFeatures: AppTypography.tabularFigures),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (billingDay == null)
            // 降级:无法分账单周期,一行 muted 提示 + 可选「去设置」
            //(隐藏优于空占位;v5 原型降级形态)。
            Row(
              children: [
                Expanded(
                  child: Text('设置账单日后可查看账单周期明细',
                      style: TextStyle(
                          fontSize: 12, color: context.yucai.muted)),
                ),
                if (onSetupBilling != null)
                  TextButton(
                    onPressed: onSetupBilling,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('去设置',
                        style: TextStyle(
                            fontSize: 12, color: context.yucai.accent)),
                  ),
              ],
            )
          else if (b != null) ...[
            _answerBlock(context, b),
            const SizedBox(height: 16),
            _composition(context, b),
          ],
        ],
      ),
    );
  }

  /// ① 应答块:还款日应还大字(与催办/还款对话框同数)+ 恢复等式推导。
  Widget _answerBlock(BuildContext context, CreditCardStatementBreakdown b) {
    final days = _daysLeft();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      decoration: BoxDecoration(
        color: context.yucai.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                repaymentDay == null ? '应还' : '还款日 $repaymentDay日 · 应还',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: context.yucai.muted),
              ),
              const Spacer(),
              if (days != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.yucai.surface,
                    border: Border.all(color: context.yucai.border),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    days > 0 ? '还有 $days 天' : '今天',
                    style: TextStyle(
                        fontSize: 11,
                        color: context.yucai.accent,
                        fontFeatures: AppTypography.tabularFigures),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            key: const ValueKey('ccAnswerAmount'),
            _fmtMoney(b.remainingCents, currencyCode),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: context.yucai.accent,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          const SizedBox(height: 5),
          // 恢复等式:应还 = 上期账单(出账日)− 上期已还。
          Text.rich(
            TextSpan(
              style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: context.yucai.muted,
                  fontFeatures: AppTypography.tabularFigures),
              children: [
                const TextSpan(text: '= 上期账单 '),
                TextSpan(
                    text: _fmtMoney(b.statementCents, currencyCode),
                    style: TextStyle(
                        color: context.yucai.fg, fontWeight: FontWeight.w600)),
                TextSpan(
                    text: '(${b.billingDate.month}/${b.billingDate.day} 出账)'
                        ' − 上期已还 '),
                TextSpan(
                    text: _fmtMoney(b.repaidSinceCents, currencyCode),
                    style: TextStyle(
                        color: context.yucai.fg, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ② 当前欠款构成:比例条 + 图例 —— 上期剩余(应还)+ 本期账单(未出账)
  /// 的占比可视化(未钳零时合计 = 当前欠款,恒等式测试钉死)。
  Widget _composition(BuildContext context, CreditCardStatementBreakdown b) {
    final remaining = b.remainingCents;
    final cycleNew = b.cycleNewCents;
    final total = remaining + cycleNew;
    final remainPct = total > 0 ? (remaining * 100 / total).round() : 0;
    final cyclePct = total > 0 ? (cycleNew * 100 / total).round() : 0;
    // 本期账单出账日 = 下一账单日(D + 1 月,月长 clamp 共享口径)。
    final nextBilling =
        CreditCardStatementDue.clampDay(b.billingDate.year,
            b.billingDate.month + 1, b.billingDate.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('当前欠款构成',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.yucai.muted)),
            const Spacer(),
            Text(
              _fmtMoney(total, currencyCode),
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: context.yucai.fg,
                  fontFeatures: AppTypography.tabularFigures),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            key: const ValueKey('ccCompBar'),
            height: 10,
            width: double.infinity,
            child: total <= 0
                ? ColoredBox(color: context.yucai.fg.withValues(alpha: 0.06))
                : Row(
                    children: [
                      Expanded(
                          flex: remaining,
                          child: ColoredBox(
                              color: context.yucai.accent)),
                      Expanded(
                          flex: cycleNew,
                          child:
                              ColoredBox(color: context.yucai.info)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 9),
        _legendRow(
          context,
          swatch: context.yucai.accent,
          label: '上期剩余(应还) ',
          value: _fmtMoney(remaining, currencyCode),
          valueColor: context.yucai.accent,
          suffix: ' · $remainPct%',
        ),
        const SizedBox(height: 7),
        _legendRow(
          context,
          swatch: context.yucai.info,
          label: '本期账单(未出账) ',
          value: _fmtMoney(cycleNew, currencyCode),
          valueColor: context.yucai.fg,
          suffix: ' · ${nextBilling.month}/${nextBilling.day} 出账 · $cyclePct%',
        ),
      ],
    );
  }

  Widget _legendRow(
    BuildContext context, {
    required Color swatch,
    required String label,
    required String value,
    required Color valueColor,
    required String suffix,
  }) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: swatch,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                  fontSize: 11.5,
                  color: context.yucai.muted,
                  fontFeatures: AppTypography.tabularFigures),
              children: [
                TextSpan(text: label),
                TextSpan(
                    text: value,
                    style: TextStyle(
                        color: valueColor, fontWeight: FontWeight.w600)),
                TextSpan(text: suffix),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 距下一还款日天数([CreditCardStatementDue.nextRepaymentDate] 单一口径;
  /// 还款日未设 → null 不渲染 chip)。0 = 还款日就在今天。
  int? _daysLeft() {
    final d = repaymentDay;
    if (d == null) return null;
    final now = (clock ?? DateTime.now)();
    final today = DateTime(now.year, now.month, now.day);
    return CreditCardStatementDue.nextRepaymentDate(today, d)
        .difference(today)
        .inDays;
  }

  /// 千分位 + 两位小数 + 币种符号(与账户详情页 _fmtSigned 同口径)。
  static String _fmtMoney(int cents, String currencyCode) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final frac = (abs % 100).toString().padLeft(2, '0');
    final yuanStr = _groupThousands(yuan);
    return '$sign${currencySymbol(currencyCode)}$yuanStr.$frac';
  }

  static String _groupThousands(int yuan) {
    final s = yuan.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
