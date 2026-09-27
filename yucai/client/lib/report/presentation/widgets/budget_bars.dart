/// 预算执行条形清单(T5,05 章节,原型 .bdg-row;形态参照预算页条形)。
///
/// 三档状态色(照原型 chip.warn/chip.neg):超支=negative(含「超支」
/// 徽标)、≥90%=warn(临界提醒)、正常=accent。全走 context.yucai 令牌。
library;

import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/presentation/widgets/chart_helpers.dart';

/// 预算执行章节主体(卡内条形清单)。
class BudgetBars extends StatelessWidget {
  const BudgetBars({super.key, required this.items});

  final List<ReportBudgetItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child:
            Text('本期无预算项', style: TextStyle(color: context.yucai.muted)),
      );
    }
    return Column(
      children: [
        for (final item in items) _BudgetRow(item: item),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.item});

  final ReportBudgetItem item;

  /// 状态:超支 / 临界(≥90%) / 正常。
  Color _barColor(BuildContext context) {
    if (item.overran) return context.yucai.negative;
    if (item.pct >= 90) return context.yucai.warn;
    return context.yucai.accent;
  }

  Color _chipColor(BuildContext context) {
    if (item.overran) return context.yucai.negative;
    if (item.pct >= 90) return context.yucai.warn;
    return context.yucai.positive;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = item.limitCents <= 0
        ? 0.0
        // 超支封顶满条(原型 width:100%)。
        : (item.actualCents / item.limitCents).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.yucai.fg,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 8,
                color: context.yucai.surfaceAlt,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio,
                  child: Container(color: _barColor(context)),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 190,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.yucai.fg,
                          fontFeatures: AppTypography.tabularFigures,
                        ),
                        children: [
                          TextSpan(text: fmtCents(item.actualCents)),
                          TextSpan(
                            text: ' / ${fmtCents(item.limitCents)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: context.yucai.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _chipColor(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.overran
                        ? '${item.pct.toStringAsFixed(1)}% 超支'
                        : '${item.pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _chipColor(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
