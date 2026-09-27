/// 通用分类构成横条清单(T5,原型 .rows-list):名称 + 进度横条 + 金额 +
/// 占比。用于 资产负债期末构成 / 支出分类 / 收入构成 三处(02/03 章节)。
///
/// 金额格式化走 chart_helpers.fmtCents(千分位单点);颜色全部
/// context.yucai 语义令牌(零裸色,NFR-2)。
library;

import 'package:flutter/material.dart';

import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/presentation/widgets/chart_helpers.dart';

/// 账类代码 → 中文标签:AccountCategory 枚举名(如 'savings'/'realEstate')
/// 经 [AccountCategoryX.label] 转译;非账类串(收支章节维度 = 科目账户 id)
/// 原样返回——展示层不做任何数据改写。
String categoryLabelOf(String code) {
  for (final c in AccountCategory.values) {
    if (c.name == code) return c.label;
  }
  return code;
}

/// 分类构成横条清单。
///
/// [rows] 按金额降序(汇编层排序惯例);横条宽度 = 相对首行(最大值)的
/// 比例,照原型「最大类满条」形态。空列表 → 空态提示。
class CategoryBars extends StatelessWidget {
  const CategoryBars({
    super.key,
    required this.rows,
    required this.barColor,
    this.amountColor,
    this.emptyText = '暂无数据',
  });

  final List<CategoryAmount> rows;

  /// 横条填充色(资产/收入=accent·positive 语义;负债/支出=negative)。
  final Color? barColor;

  /// 金额数字颜色(收入构成传 positive;缺省=fg)。
  final Color? amountColor;

  /// 空态文案。
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(emptyText, style: TextStyle(color: context.yucai.muted)),
      );
    }
    final maxCents = rows.first.amountCents;
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    categoryLabelOf(row.category),
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
                  child: _Bar(
                    ratio: maxCents <= 0
                        ? 0.0
                        : (row.amountCents / maxCents).clamp(0.0, 1.0),
                    color: barColor ?? context.yucai.accent,
                    track: context.yucai.surfaceAlt,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 104,
                  child: Text(
                    fmtCents(row.amountCents),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: amountColor ?? context.yucai.fg,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${row.pct.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.yucai.muted,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 单根圆角横条(track 底 + 按比例填充)。
class _Bar extends StatelessWidget {
  const _Bar({required this.ratio, required this.color, required this.track});

  final double ratio;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 8,
        color: track,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: ratio,
          child: Container(color: color),
        ),
      ),
    );
  }
}
