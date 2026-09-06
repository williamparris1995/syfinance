// 持仓资产配置饼图(fl_chart 1.x PieChart)。
//
// 对齐 A-od holdings-mobile.html `#pie`(conic-gradient donut):
// 按 SecurityType 占比,御财金色板(TYPE_META,design-output/holding/styles.css)。
// 中心展示最大 type 的百分比(原型 .pie-hole 模式)。
//
// fl_chart 1.x API(非 0.69):PieChartData(sections, centerSpaceRadius, ...);
// PieChartSectionData(value, color, radius, showTitle)。centerSpaceRadius>0
// 形成空心环(donut)。centerSpaceColor 透白(放中心文本 stack)。
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';

/// SecurityType → 御财金色板(对齐 A-od TYPE_META colors)——亮色板(保原值)。
/// option/未命中 type 走中性灰 fallback(原型无 option 色,补一个不抢戏的)。
const Map<SecurityType, Color> kHoldingTypeColors = {
  SecurityType.stock: Color(0xFFB08D57), // 御财金
  SecurityType.fund: Color(0xFF8A6D3B), // 深金
  SecurityType.etf: Color(0xFF2D8A6E), // 盈绿
  SecurityType.bond: Color(0xFF6B7A8F), // 灰蓝
  SecurityType.gold: Color(0xFFC9A04A), // 金黄
  SecurityType.option: Color(0xFF9A8C7A), // 中性
  SecurityType.other: Color(0xFFB9B2A6), // 暖灰
};

/// SecurityType 类型序列色 —— 暗色板(v2 墨黑底整组提亮一档)。
///
/// F4-P2 数据可视化序列色裁决(照 kRingGoldGradient/ringGoldGradientOf 双板
/// 模式):亮板保原型 v1 原值;深金 #8A6D3B / 盈绿 #2D8A6E 等中间调在墨黑底
/// 上对比不足(≈3.5:1),暗板整组提亮一档(亮端锚定 v2 暗色 accent 量级)
/// ——暗色下可辨识且不刺眼。饼图配图例 secondary encoding(色块+名称+占比)
/// 兜底 CVD。落点选常量旁 context 感知 accessor 而非 YucaiTheme 扩展:序列色
/// 组随 holding 模块走(核心 theme 不 import 业务 domain),与 T1 金渐变同款。
const Map<SecurityType, Color> _kHoldingTypeColorsDark = {
  SecurityType.stock: Color(0xFFE3C285), // 御财金(提亮)
  SecurityType.fund: Color(0xFFC9A86B), // 深金(提亮)
  SecurityType.etf: Color(0xFF45B895), // 盈绿(提亮)
  SecurityType.bond: Color(0xFF8FA3C4), // 灰蓝(提亮)
  SecurityType.gold: Color(0xFFE0B45E), // 金黄(提亮)
  SecurityType.option: Color(0xFFB3A695), // 中性(提亮)
  SecurityType.other: Color(0xFFCFC8BC), // 暖灰(提亮,兜底)
};

/// 主题感知的 SecurityType 序列色:亮 = 原型 v1 金色板;暗 = 提亮暗板。
/// 未命中 type → 暖灰兜底(other 槽位)。全模块消费方一律走本 accessor。
Color holdingTypeColorOf(BuildContext context, SecurityType type) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final board = dark ? _kHoldingTypeColorsDark : kHoldingTypeColors;
  return board[type] ?? board[SecurityType.other]!;
}

/// SecurityType → 中文标签(对齐 A-od TYPE_META label,无 i18n 惯例)。
const Map<SecurityType, String> kHoldingTypeLabels = {
  SecurityType.stock: '股票',
  SecurityType.fund: '基金',
  SecurityType.etf: 'ETF',
  SecurityType.bond: '债券',
  SecurityType.gold: '黄金',
  SecurityType.option: '期权',
  SecurityType.other: '其他',
};

/// 单 type 占比条目(供饼图 + 图例共用)。
class HoldingSlice {
  const HoldingSlice({required this.type, required this.valueCents});
  final SecurityType type;
  final int valueCents; // 该 type 合计市值(分)
}

/// 资产配置 donut 饼图 + 图例。
///
/// 对齐 A-od `#pie`(donut + 中心最大 type 百分比)+ `#legend`(色块 + 名称 + 百分比)。
/// 空数据(总市值=0)显示占位环 +「无持仓」中心文,图例全部 dim(对齐原型 legend-empty)。
class HoldingPieChart extends StatelessWidget {
  const HoldingPieChart({
    super.key,
    required this.slices,
    this.size = 132,
  });

  /// 按 type 聚合的市值切片(每条 = 某 type 合计市值)。调用方负责聚合。
  final List<HoldingSlice> slices;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (s, sl) => s + sl.valueCents);
    // 按 value 降序,稳定顺序(对齐原型 sort by pct desc)。
    final ordered = ([...slices]..sort((a, b) => b.valueCents - a.valueCents));
    final top = ordered.isNotEmpty && total > 0 ? ordered.first : null;
    final topPct = (top != null && total > 0)
        ? (top.valueCents / total) * 100
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
                  sections: _sections(context, ordered, total),
                ),
              ),
              // 中心文本:最大 type 百分比 + 名称(对齐 .pie-hole)。
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    top != null
                        ? '${topPct.toStringAsFixed(1)}%'
                        : '—',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    top != null
                        ? kHoldingTypeLabels[top.type] ?? '—'
                        : '无持仓',
                    style: TextStyle(
                        fontSize: 11, color: context.yucai.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(child: _legend(context, ordered, total)),
      ],
    );
  }

  List<PieChartSectionData> _sections(
      BuildContext context, List<HoldingSlice> ordered, int total) {
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
    return [
      for (final sl in ordered)
        PieChartSectionData(
          value: sl.valueCents.toDouble(),
          color: holdingTypeColorOf(context, sl.type),
          radius: 22,
          showTitle: false,
        ),
    ];
  }

  Widget _legend(
      BuildContext context, List<HoldingSlice> ordered, int total) {
    // 含全部 7 type(原型 legend 列全量,dim 表示 pct=0)。
    final byType = {for (final sl in ordered) sl.type: sl.valueCents};
    const order = SecurityType.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in order)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: _LegendRow(
              color: holdingTypeColorOf(context, t),
              label: kHoldingTypeLabels[t] ?? t.name,
              pct: total > 0
                  ? ((byType[t] ?? 0) / total) * 100
                  : 0.0,
              dim: (byType[t] ?? 0) == 0,
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
    required this.pct,
    required this.dim,
  });
  final Color color;
  final String label;
  final double pct;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    // dim(占比 0)= 整行置灰:muted;常规行 label/数值 = fg(对齐原型
    // legend-empty 语义,标签与数值同档)。
    final c = dim ? context.yucai.muted : context.yucai.fg;
    final labelColor = c;
    final valColor = c;
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color.withValues(alpha: dim ? 0.3 : 1.0),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 12.5, color: labelColor)),
        ),
        Text('${pct.toStringAsFixed(1)}%',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: valColor,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }
}
