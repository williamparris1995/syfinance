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
import 'package:yucai_client/report/presentation/widgets/chart_helpers.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// 分类筛选：消费 [aggregateCategorySlices] 时按 accountType 拆 income/expense。
enum CategoryFilter {
  /// 支出分类（「钱花哪儿」）。报表默认。
  expense,
  /// 收入分类。
  income;

  String get wire => this == CategoryFilter.expense ? 'expense' : 'income';
}

/// 御财金色分类板(固定顺序,回避语义绿/红)——亮色板(保原值)。
/// CVD 由图例 secondary encoding 弥补。
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

/// 分类序列色 —— 暗色板(v2 墨黑底整组提亮一档,与亮板顺序一一对应)。
///
/// F4-P2 数据可视化序列色裁决(照 kRingGoldGradient/ringGoldGradientOf 双板
/// 模式):深金 #8A6D3B / 棕 #9A7B4F 等中间调在墨黑底上对比不足(≈3.5:1),
/// 暗板整组提亮一档(亮端锚定 v2 暗色 accent 量级)——暗色下可辨识且不刺眼;
/// 亮板保原型 v1 原值。落点选常量旁 context 感知 accessor 而非 YucaiTheme
/// 扩展:序列色组随 report 模块走,与 holding 的 holdingTypeColorOf 同款。
const List<Color> _kCategoryColorsDark = [
  Color(0xFFD9B478), // 御财金(提亮)
  Color(0xFFBE9A5F), // 深金(提亮)
  Color(0xFF96A5BC), // 灰蓝(提亮)
  Color(0xFFE0B45E), // 金黄(提亮)
  Color(0xFFC4A276), // 棕(提亮)
  Color(0xFF7FB1C7), // 蓝(提亮)
  Color(0xFFBBAE9C), // 中性(提亮)
  Color(0xFFD4CEC3), // 暖灰(提亮,兜底)
];

/// 主题感知的分类序列色:亮 = 原型 v1 金色板;暗 = 提亮暗板。
List<Color> categoryColorsOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? _kCategoryColorsDark
        : kCategoryColors;

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
                  // 中心空心底 = 卡面 surface(放中心文本 stack;暗色随卡面)。
                  centerSpaceColor: context.yucai.surface,
                  sections: _sections(context, top, topTotal),
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
                    style: TextStyle(
                        fontSize: 11, color: context.yucai.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg - 10),
        Expanded(child: _legend(context, top, total)),
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

  List<PieChartSectionData> _sections(
      BuildContext context, List<CategorySlice> src, int total) {
    if (total <= 0) {
      // 空数据占位:单一灰满环(底走 surfaceAlt,暗色随卡面浅一档,
      // 原硬米白 #E6E3DC 在墨黑底上会刺眼)。
      return [
        PieChartSectionData(
          value: 1,
          color: context.yucai.surfaceAlt,
          radius: 22,
          showTitle: false,
        ),
      ];
    }
    final palette = categoryColorsOf(context);
    return [
      for (var i = 0; i < src.length; i++)
        PieChartSectionData(
          value: src[i].amountCents.toDouble(),
          color: palette[i % palette.length],
          radius: 22,
          showTitle: false,
        ),
    ];
  }

  Widget _legend(BuildContext context, List<CategorySlice> src, int total) {
    if (src.isEmpty || total <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text('暂无分类数据',
            style: TextStyle(fontSize: 12.5, color: context.yucai.muted)),
      );
    }
    final palette = categoryColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < src.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: _LegendRow(
              color: palette[i % palette.length],
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
              style: TextStyle(fontSize: 12.5, color: context.yucai.fg)),
        ),
        Text('${_fmtCents(amountCents)}  ·  ${pct.toStringAsFixed(1)}%',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.yucai.fg,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }
}

String _fmtCents(int cents) {
  final yuan = cents.abs() ~/ 100;
  return '¥${groupInt(yuan)}';
}
