// 报表图表共享 helpers（DRY）。抽取自 income_expense_trend_chart /
// monthly_comparison_bar / category_breakdown_pie 三图的重复私有 helper。
//
// 收录：
//   - [LegendDot]          图例圆点 + 文字（≥2 series 可访问性 secondary encoding）
//   - [niceMax]            Y 轴「好看」上界（1/2/5 × 10^n）
//   - [pow10]              [niceMax] 的辅助：≤ v 的最大 10^n
//   - [compactYuan]        Y 轴/tooltip 紧凑金额（<1万 千分位；≥1万 「万」）
//   - [fmtYuan]            tooltip 精确金额（≥1万 2 位小数万；否则 元.角分）
//   - [groupInt]           整数千分位（上述两者的基础）
//
// 设计原则：纯函数 + 无状态 widget，无图表库依赖（fl_chart 留给各图自身 import），
// 便于复用与单测。颜色语义沿用 AppColors（与 _SummaryStrip / 交易列表一致）。
import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 图例圆点 + 文字。用于 ≥2 series 折线/柱状图作 secondary encoding（CVD）。
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.fg)),
      ],
    );
  }
}

/// 取数据最大值并向上取整到「好看」的刻度（1/2/5 × 10^n）。
/// 空或 ≤0 → 100（默认刻度）。
double niceMax(List<double> vals) {
  final max = vals.isEmpty || vals.reduce((a, b) => a > b ? a : b) <= 0
      ? 100.0
      : vals.reduce((a, b) => a > b ? a : b);
  if (max <= 0) return 100;
  final pow = pow10(max);
  final n = max / pow;
  final nice = n <= 1 ? 1 : (n <= 2 ? 2 : (n <= 5 ? 5 : 10));
  return nice * pow;
}

/// ≤ v 的最大 10 的幂（10^floor(log10(v))）。v<1 → 1。
double pow10(double v) {
  var p = 1.0;
  while (p * 10 <= v) {
    p *= 10;
  }
  return p;
}

/// 紧凑金额（元）：<10000 直显千分位；≥10000 用「万」。
/// 用于 Y 轴标签等空间受限处。
String compactYuan(double yuan) {
  if (yuan >= 10000) {
    final wan = yuan / 10000;
    return '${wan.toStringAsFixed(wan >= 100 ? 0 : 1)}万';
  }
  return groupInt(yuan.round());
}

/// 精确金额（元）：≥10000 用「万」（2 位小数）；否则 元.角分。
/// 用于 tooltip 等可读性优先处。
String fmtYuan(double yuan) {
  if (yuan >= 10000) {
    return '${(yuan / 10000).toStringAsFixed(2)}万';
  }
  return '${groupInt(yuan.round())}.${((yuan * 100) % 100).round().toString().padLeft(2, '0')}';
}

/// 整数千分位分组（取绝对值，忽略符号）。
String groupInt(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
