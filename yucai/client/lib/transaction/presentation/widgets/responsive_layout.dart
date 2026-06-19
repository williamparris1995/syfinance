import 'package:flutter/material.dart';

/// 御财响应式断点（设计规范 §6）。
///
/// 三档：
///   - [mobile]   viewport 宽度 ≤ 600
///   - [tablet]   600 < 宽度 < 1200
///   - [desktop]  宽度 ≥ 1200
///
/// 与 Material 3 默认窗口尺寸类相近：Compact / Medium / Expanded。
/// 以 `MediaQuery.of(context).size.width` 为唯一输入，方便 widget test
/// 通过包一层 [MediaQuery] 注入宽度，不依赖宿主窗口。
enum Breakpoint { mobile, tablet, desktop }

/// 御财响应式断点阈值。提取为常量便于测试断言与文档化。
class Breakpoints {
  const Breakpoints._();

  /// mobile 上界（含）。≤ 此值视为 mobile。
  static const double mobileUpper = 600;

  /// desktop 下界（含）。≥ 此值视为 desktop。
  static const double desktopLower = 1200;

  /// 根据宽度返回断点档位。
  static Breakpoint ofWidth(double width) {
    if (width <= mobileUpper) return Breakpoint.mobile;
    if (width >= desktopLower) return Breakpoint.desktop;
    return Breakpoint.tablet;
  }

  /// 从 [BuildContext] 读取当前断点（基于 MediaQuery 宽度）。
  static Breakpoint of(BuildContext context) =>
      ofWidth(MediaQuery.of(context).size.width);
}

/// 根据断点选择其中一个子树渲染。
///
/// 三档必须由调用方提供 —— 简化心智模型：不在 widget 树里隐式回退。
/// 若某档确实共用同一子树，调用方自己传同一 widget 即可。
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });

  final Widget mobile;
  final Widget tablet;
  final Widget desktop;

  @override
  Widget build(BuildContext context) {
    switch (Breakpoints.of(context)) {
      case Breakpoint.mobile:
        return mobile;
      case Breakpoint.tablet:
        return tablet;
      case Breakpoint.desktop:
        return desktop;
    }
  }
}
