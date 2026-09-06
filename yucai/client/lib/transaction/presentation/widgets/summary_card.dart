import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 月度汇总四卡（本月收入 / 支出 / 净额 / 日均）。
///
/// **纯 UI 组件**：四个数值以分（cents）传入，本组件只负责排版与配色。
/// 不接 bloc / repository —— Task 5.2 才接真实 MonthlySummary。
///
/// 配色遵循设计规范：收入绿 [context.yucai.positive]、支出红
/// [context.yucai.negative]、净额按正负染色，日均中性。数字采用 tabular-nums 等宽对齐。
/// Mobile 单列堆叠；Tablet 2×2；Desktop 一行 4 张。
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.incomeCents,
    required this.expenseCents,
    required this.netCents,
    required this.dailyAvgCents,
    this.currencySymbol = '¥',
  });

  /// 本月收入（分）。
  final int incomeCents;

  /// 本月支出（分）。
  final int expenseCents;

  /// 本月净额（分，可负）。
  final int netCents;

  /// 本月日均（分）。
  final int dailyAvgCents;

  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _grid(context, sliver: false, crossAxisCount: 1),
      tablet: _grid(context, sliver: false, crossAxisCount: 2),
      desktop: _row(context),
    );
  }

  Widget _row(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _cell(context, _SummaryKind.income, incomeCents)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _cell(context, _SummaryKind.expense, expenseCents)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _cell(context, _SummaryKind.net, netCents)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _cell(context, _SummaryKind.dailyAvg, dailyAvgCents)),
      ],
    );
  }

  Widget _grid(BuildContext context,
      {required bool sliver, required int crossAxisCount}) {
    final cards = [
      _cell(context, _SummaryKind.income, incomeCents),
      _cell(context, _SummaryKind.expense, expenseCents),
      _cell(context, _SummaryKind.net, netCents),
      _cell(context, _SummaryKind.dailyAvg, dailyAvgCents),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.6,
      children: cards,
    );
  }

  Widget _cell(BuildContext context, _SummaryKind kind, int cents) {
    final color = kind.colorFor(context, cents);
    return DataCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kind.label,
            style: TextStyle(
              color: context.yucai.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatAmount(kind, cents),
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  /// 净额保留负号；其余按绝对值展示（收入/支出/日均本身非负）。
  String _formatAmount(_SummaryKind kind, int cents) {
    final sign = (kind == _SummaryKind.net && cents < 0) ? '-' : '';
    return '$sign$currencySymbol${_formatAbs(cents)}';
  }

  /// 分 → 「1,234.56」格式（千分位 + 两位小数）。纯本地格式化，不引 intl。
  static String _formatAbs(int cents) {
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final frac = (abs % 100).toString().padLeft(2, '0');
    final yuanStr = _groupThousands(yuan);
    return '$yuanStr.$frac';
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

enum _SummaryKind { income, expense, net, dailyAvg }

extension _SummaryKindX on _SummaryKind {
  String get label {
    switch (this) {
      case _SummaryKind.income:
        return '本月收入';
      case _SummaryKind.expense:
        return '本月支出';
      case _SummaryKind.net:
        return '本月净额';
      case _SummaryKind.dailyAvg:
        return '日均';
    }
  }

  /// F4-P2:语义色经 context.yucai 解析(暗色跟随主题提亮档)。
  Color colorFor(BuildContext context, int cents) {
    switch (this) {
      case _SummaryKind.income:
        return context.yucai.positive;
      case _SummaryKind.expense:
        return context.yucai.negative;
      case _SummaryKind.net:
        return cents >= 0
            ? context.yucai.positive
            : context.yucai.negative;
      case _SummaryKind.dailyAvg:
        return context.yucai.fg;
    }
  }
}
