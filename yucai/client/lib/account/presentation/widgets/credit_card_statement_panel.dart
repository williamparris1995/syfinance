/// 信用卡「账单周期」面板(T8,2026-09 用户验收②):银行 App 式四行账单
/// 周期明细 —— 上期账单 / 上期已还 / 上期剩余(= 还款日应还,与催办/还款
/// 对话框同一数字,强调色)/ 本期账单(未出账)。
///
/// 纯展示:数据由页面经 [CreditCardStatementDue.breakdown] 算好注入(共享
/// 推导,单一口径);账单日未设 → 不渲染四行,降级一行 muted 提示。语义
/// 令牌零裸色;金额千分位两位小数(同详情页 _fmtSigned 口径)。
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
  });

  /// 卡的账单日(null = 未设 → 降级提示行)。
  final int? billingDay;

  /// 卡的还款日(可缺:副标注只显账单日段)。
  final int? repaymentDay;

  /// 金额符号随卡币种(不换算)。
  final String currencyCode;

  /// 周期拆解(null = 未加载,四行暂不渲染;账单日未设时恒 null)。
  final CreditCardStatementBreakdown? breakdown;

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    // 四行仅在「账单日已设且数据已算出」时渲染。
    final rows = <(String, int, bool)>[];
    if (billingDay != null && b != null) {
      rows
        ..add(('上期账单', b.statementCents, false))
        ..add(('上期已还', b.repaidSinceCents, false))
        // 上期剩余 = 还款日应还(催办 toast/聚合条/还款对话框同数)→ 强调。
        ..add(('上期剩余', b.remainingCents, true))
        ..add(('本期账单(未出账)', b.cycleNewCents, false));
    }
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
            // 降级:无法分账单周期,一行 muted 提示(隐藏优于空占位)。
            Text('设置账单日后可查看账单周期明细',
                style: TextStyle(
                    fontSize: 12, color: context.yucai.muted))
          else
            for (final (label, cents, emphasized) in rows)
              _row(context, label, cents, emphasized),
        ],
      ),
    );
  }

  /// 单行:label 左 + 金额右(muted/fg);强调行(上期剩余)accent + 加粗。
  Widget _row(BuildContext context, String label, int cents, bool emphasized) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: emphasized ? context.yucai.fg : context.yucai.muted,
                  fontWeight:
                      emphasized ? FontWeight.w600 : FontWeight.w400)),
          const Spacer(),
          Text(
            _fmtMoney(cents, currencyCode),
            style: TextStyle(
                fontSize: 13,
                color: emphasized ? context.yucai.accent : context.yucai.fg,
                fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
                fontFeatures: AppTypography.tabularFigures),
          ),
        ],
      ),
    );
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
