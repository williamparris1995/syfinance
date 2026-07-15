// 支出分类占比（fl_chart 1.x PieChart）。报表分析页 §2。
//
// 数据：[MonthlySummary.byDay] 逐日 byCategory，按 accountType=="expense"
// 聚合到分类（账户 = 分类，account-as-category）。聚合由
// [aggregateCategorySlices] 完成；widget 仅消费 [CategorySlice] 列表（纯展示，
// 对齐 holding_pie_chart 消费 HoldingSlice 的范式）。
//
// fl_chart 1.x API（对齐 holding_pie_chart.dart）：PieChartData(sections,
// centerSpaceRadius, centerSpaceColor, sectionsSpace)；PieChartSectionData(
// value, color, radius, showTitle)。centerSpaceRadius>0 形成空心环。
//
// 配色：御财金色板（kCategoryColors，固定顺序，**刻意回避** positive 绿 /
// negative 红——语义色不挪作分类色）。CVD：app 金色板饱和度低，
// 故配图例（色块 + 名称 + 百分比）作 secondary encoding（非仅靠颜色辨识）。
// 展示 Top N + 「其他」合并，避免切片过多。
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// 分类筛选：消费 [aggregateCategorySlices] 时按 accountType 拆 income/expense。
enum CategoryFilter {
  /// 支出分类（「钱花哪儿」）。报表默认。
  expense,
  /// 收入分类。
  income;

  String get wire => this == CategoryFilter.expense ? 'expense' : 'income';
}

/// 御财金色分类板（固定顺序，回避语义绿/红）。CVD 由图例 secondary encoding 弥补。
const List<Color> kCategoryColors = [
  Color(0xFFB08D57), // 御财金
  Color(0xFF8A6D3B), // 深金
  Color(0xFF6B7A8F), // 灰蓝
  Color(0xFFC9A04A), // 金黄
  Color(0xFF9A7B4F), // 棕
  Color(0xFF5A8AA3), // 蓝
  Color(0xFF9A8C7A), // 中性
  Color(0xFFB9B2A6), // 暖灰（兜底）
];

/// 单个分类切片（聚合后）。name 用于图例，amountCents 已按 filter 求和。
class CategorySlice {
  const CategorySlice({this.id = '', required this.name, required this.amountCents});
  final String id;
  final String name;
  final int amountCents;
}

/// 把 [summary] 的 byDay 逐日 byCategory 按 [filter]（expense/income）聚合为
/// 分类切片，按金额降序。report_page 调用一次后传入 widget。
List<CategorySlice> aggregateCategorySlices(
  MonthlySummary summary, {
  CategoryFilter filter = CategoryFilter.expense,
}) {
  final byId = <String, int>{};
  final nameOf = <String, String>{};
  for (final d in summary.byDay) {
    for (final c in d.byCategory) {
      if (c.accountType.toLowerCase() != filter.wire) continue;
      byId[c.categoryId] = (byId[c.categoryId] ?? 0) + c.amountCents;
      nameOf.putIfAbsent(c.categoryId, () => c.name);
    }
  }
  final slices = [
    for (final entry in byId.entries)
      CategorySlice(
        id: entry.key,
        name: nameOf[entry.key]!.isEmpty ? '未分类' : nameOf[entry.key]!,
        amountCents: entry.value,
      ),
  ]..sort((a, b) => b.amountCents - a.amountCents);
  return slices;
}

/// 分类占比 donut 饼图 + 图例。
///
/// [maxSlices] 控制展示切片数（默认 6），超出合并为「其他」。
/// 总额 ≤ 0 → 空态环 + 「暂无${filter}记录」。
class CategoryBreakdownPie extends StatelessWidget {
  const CategoryBreakdownPie({
    super.key,
    required this.slices,
    this.size = 132,
    this.maxSlices = 6,
    this.emptyLabel = '暂无支出记录',
  });

  final List<CategorySlice> slices;
  final double size;
  final int maxSlices;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (s, sl) => s + sl.amountCents);
    final top = _fold(slices, maxSlices);
    final topTotal = top.fold<int>(0, (s, sl) => s + sl.amountCents);
    final first = total > 0 && top.isNotEmpty ? top.first : null;
    final topPct = (first != null && total > 0)
        ? (first.amountCents / total) * 100
        : 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: size * 0.34,
                  centerSpaceColor: AppColors.surface,
                  sections: _sections(top, topTotal),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    total > 0 ? '${topPct.toStringAsFixed(1)}%' : '—',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    total > 0 ? (first!.name) : emptyLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg - 10),
        Expanded(child: _legend(top, total)),
      ],
    );
  }

  /// Top N 切片，余下合并为「其他」。
  List<CategorySlice> _fold(List<CategorySlice> src, int n) {
    if (src.length <= n) return src;
    final head = src.take(n - 1).toList();
    final rest = src.skip(n - 1);
    final otherCents = rest.fold<int>(0, (s, sl) => s + sl.amountCents);
    return [...head, CategorySlice(id: '__other', name: '其他', amountCents: otherCents)];
  }

  List<PieChartSectionData> _sections(List<CategorySlice> src, int total) {
    if (total <= 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: const Color(0xFFE6E3DC),
          radius: 22,
          showTitle: false,
        ),
      ];
    }
    return [
      for (var i = 0; i < src.length; i++)
        PieChartSectionData(
          value: src[i].amountCents.toDouble(),
          color: kCategoryColors[i % kCategoryColors.length],
          radius: 22,
          showTitle: false,
        ),
    ];
  }

  Widget _legend(List<CategorySlice> src, int total) {
    if (src.isEmpty || total <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text('暂无分类数据',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < src.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: _LegendRow(
              color: kCategoryColors[i % kCategoryColors.length],
              label: src[i].name,
              amountCents: src[i].amountCents,
              pct: (src[i].amountCents / total) * 100,
            ),
          ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.amountCents,
    required this.pct,
  });
  final Color color;
  final String label;
  final int amountCents;
  final double pct;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.fg)),
        ),
        Text('${_fmtCents(amountCents)}  ·  ${pct.toStringAsFixed(1)}%',
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.fg,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }
}

String _fmtCents(int cents) {
  final yuan = cents.abs() ~/ 100;
  return '¥${_group(yuan)}';
}

String _group(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
