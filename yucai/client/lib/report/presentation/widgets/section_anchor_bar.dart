/// 章节锚点导航(T5,ADR-5 **变体 B**:右缘竖排圆点 + 悬停标签,用户
/// 2026-09-25 拍板的实现终态;原型 .dot-nav,变体 A 横条不实现)。
///
/// 交互契约(照原型脚本):点击圆点 → 平滑滚动到对应章节;滚动时高亮
/// 当前章(active);悬停/激活显示左侧标签 chip。滚动驱动由页面侧
/// ScrollController 完成,本组件纯展示(active + onTap 回调)。
///
/// 对齐实现(2026-09-28 二轮反馈①修订):全部行共用**固定标签槽宽**
/// (=最长标签 chip 宽,TextPainter 预测量)——标签在槽内做透明度
/// 动画,始终处于常规布局流(首版 AnimatedOpacity 不占位致圆点参差,
/// 次版 Positioned 悬浮在部分渲染路径被裁致标签丢失,本版两者兼治)。
library;

import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 右缘圆点锚点导航(竖排;随报告体覆盖在滚动区右缘)。
class SectionDotNav extends StatelessWidget {
  const SectionDotNav({
    super.key,
    required this.labels,
    required this.active,
    required this.onTap,
  });

  /// 章节标签(与章节顺序一致;自适应缺席章节已由调用方剔除)。
  final List<String> labels;

  /// 当前高亮章索引。
  final int active;

  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final slotWidth = _labelSlotWidth(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _Dot(
              key: ValueKey('sectionDot-$i'),
              label: labels[i],
              slotWidth: slotWidth,
              active: i == active,
              onTap: () => onTap(i),
            ),
          ),
      ],
    );
  }

  /// 最长标签 chip 的渲染宽度(文本 + 横 padding 20 + 边框 2),
  /// 各行共用 → 圆点恒定右对齐。
  ///
  /// 测算样式必须**带主题字体**(继承 DefaultTextStyle 的 fontFamily):
  /// TextPainter 裸 TextStyle 走默认字体,中文宽度普遍小于微软雅黑
  /// 实测,曾致最宽标签被 ellipsis 截断(反馈①三版)。
  double _labelSlotWidth(BuildContext context) {
    final scaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    final base = DefaultTextStyle.of(context).style;
    final style = base.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600);
    final tp = TextPainter(textDirection: TextDirection.ltr, textScaler: scaler);
    var widest = 0.0;
    for (final label in labels) {
      tp.text = TextSpan(text: label, style: style);
      tp.layout();
      if (tp.width > widest) widest = tp.width;
    }
    tp.dispose();
    return widest + 20 + 2;
  }
}

class _Dot extends StatefulWidget {
  const _Dot({
    super.key,
    required this.label,
    required this.slotWidth,
    required this.active,
    required this.onTap,
  });

  final String label;

  /// 标签槽宽(SectionDotNav 预测量,全行一致)。
  final double slotWidth;

  final bool active;

  final VoidCallback onTap;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final showLabel = _hover || widget.active;
    // a11y(T5-R1):Tooltip + Semantics 对齐同页 IconButton 形态——悬停
    // 出标签之外,读屏/键盘用户同样可获得章节名与按钮语义。
    return Semantics(
      button: true,
      label: '跳转到 ${widget.label}',
      child: Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 300),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标签 chip:固定槽宽内**右对齐贴住圆点**(三版反馈修订:
                // 左对齐时短标签距圆点过远)+单行强制(maxLines 1,槽宽
                // 按最长标签预留,正常不截断,ell 属防御)。
                SizedBox(
                  width: widget.slotWidth,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: showLabel ? 1 : 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: context.yucai.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.yucai.border),
                          ),
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: context.yucai.fg,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // 激活:accent 实心 + accent 22% 光环(原型 .on box-shadow)。
                    color: widget.active
                        ? context.yucai.accent
                        : context.yucai.muted.withValues(alpha: 0.45),
                    boxShadow: widget.active
                        ? [
                            BoxShadow(
                              color:
                                  context.yucai.accent.withValues(alpha: 0.22),
                              spreadRadius: 4,
                              blurRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
