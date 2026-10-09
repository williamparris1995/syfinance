import 'package:flutter/material.dart';

/// Kit 的最小语义令牌接口 —— **依赖倒置缝**(YuCai ADR-007):
/// kit 组件只读这些令牌,**不认识任何宿主产品**;宿主把自己的设计
/// 系统映射到本扩展(在 ThemeData.extensions 注册),未注册时回落亮色
/// (裸 MaterialApp 测试可渲染,与宿主侧 ThemeExtension 兜底同惯例)。
class DesignTokens extends ThemeExtension<DesignTokens> {
  const DesignTokens({
    required this.surface,
    required this.border,
    required this.fg,
    required this.muted,
    required this.accent,
    required this.positive,
    required this.negative,
  });

  /// 容器/弹出面底色。
  final Color surface;

  /// 描边。
  final Color border;

  /// 正文。
  final Color fg;

  /// 辅助文字。
  final Color muted;

  /// 主操作强调色。
  final Color accent;

  /// 正向(成功/收入)语义色。
  final Color positive;

  /// 负向(危险/支出)语义色。
  final Color negative;

  /// 亮色兜底(宿主未注册扩展时;取自中性石板色系,任何宿主下不刺眼)。
  static const DesignTokens light = DesignTokens(
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFEEF2F7),
    fg: Color(0xFF0F172A),
    muted: Color(0xFF64748B),
    accent: Color(0xFF059669),
    positive: Color(0xFF059669),
    negative: Color(0xFFE11D48),
  );

  @override
  DesignTokens copyWith({
    Color? surface,
    Color? border,
    Color? fg,
    Color? muted,
    Color? accent,
    Color? positive,
    Color? negative,
  }) =>
      DesignTokens(
        surface: surface ?? this.surface,
        border: border ?? this.border,
        fg: fg ?? this.fg,
        muted: muted ?? this.muted,
        accent: accent ?? this.accent,
        positive: positive ?? this.positive,
        negative: negative ?? this.negative,
      );

  @override
  DesignTokens lerp(ThemeExtension<DesignTokens>? other, double t) {
    if (other is! DesignTokens) return this;
    return DesignTokens(
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      fg: Color.lerp(fg, other.fg, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DesignTokens &&
      surface == other.surface &&
      border == other.border &&
      fg == other.fg &&
      muted == other.muted &&
      accent == other.accent &&
      positive == other.positive &&
      negative == other.negative;

  @override
  int get hashCode => Object.hashAll(
      [surface, border, fg, muted, accent, positive, negative]);
}

/// 组件层读取语义令牌:`context.designTokens.accent`。
extension DesignTokensX on BuildContext {
  DesignTokens get designTokens =>
      Theme.of(this).extension<DesignTokens>() ?? DesignTokens.light;
}
