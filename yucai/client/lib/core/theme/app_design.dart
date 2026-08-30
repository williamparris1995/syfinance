import 'package:flutter/material.dart';

/// 御财设计令牌 v2 —— A+B 亮暗双主题(设计源 docs/sydusx/products/yucai-client/design-v2.md,
/// 原型 design-output-v2/ab/)。
///
/// v2 变化(相对 v1 奶油白+御财金+serif):
/// - 双主题:暗=墨鎏金(鎏金 #E8C07A),亮=晨白(翡翠绿 #059669);语义色经
///   [YucaiTheme] ThemeExtension 随 ThemeData 注入,页面用 `context.yucai` 读取。
/// - 全无衬线:v1 的 serif 标题(Windows 中文渲染发虚)退役,[AppTypography]
///   display 族指向同一 sans 栈。
/// - legacy [AppColors] 静态量保留并重指向 v2 亮色值 —— 未迁移主题感知的模块
///   页面在亮色下即刻呈现 v2 观感;暗色感知迁移为 R8 后续 feature(R8 release.md defer)。

/// 主题语义令牌。每套主题一个 const 实例,由 [AppTheme.light]/[AppTheme.dark]
/// 挂到 ThemeData.extensions;组件层经 `context.yucai` 取用,不再内联魔法色值。
@immutable
class YucaiTheme extends ThemeExtension<YucaiTheme> {
  const YucaiTheme({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.fg,
    required this.muted,
    required this.accent,
    required this.accentDeep,
    required this.accentSoft,
    required this.onAccent,
    required this.positive,
    required this.negative,
    required this.info,
    required this.warn,
    required this.sidebarBg,
    required this.sidebarBorder,
    required this.sidebarFg,
    required this.sidebarHover,
    required this.sidebarActiveBg,
    required this.sidebarActiveFg,
    required this.topbarBarrier,
  });

  /// 暗色 = 方向 A「墨鎏金」:墨黑底 + 鎏金主色,描边分层(无阴影)。
  factory YucaiTheme.dark() {
    return const YucaiTheme(
      bg: Color(0xFF0B0E13),
      surface: Color(0xFF141922),
      surfaceAlt: Color(0xFF1A2130),
      border: Color(0xFF232B38),
      fg: Color(0xFFF2F4F8),
      muted: Color(0xFF8B93A3),
      accent: Color(0xFFE8C07A),
      accentDeep: Color(0xFFC9964A),
      accentSoft: Color(0x14E8C07A), // rgba(232,192,122,.08)
      onAccent: Color(0xFF1A1408),
      positive: Color(0xFF34D399),
      negative: Color(0xFFF87171),
      info: Color(0xFF22D3EE),
      warn: Color(0xFFFBBF24),
      sidebarBg: Color(0xFF0E1219),
      sidebarBorder: Color(0xFF1B2231),
      sidebarFg: Color(0xFFB8B5AD),
      sidebarHover: Color(0xFF151B26),
      sidebarActiveBg: Color(0x17E8C07A), // rgba(232,192,122,.09)
      sidebarActiveFg: Color(0xFFE8C07A),
      topbarBarrier: Color(0xB80B0E13), // rgba(11,14,19,.72)
    );
  }

  /// 亮色 = 方向 B「晨白」:净白底 + 翡翠绿主色,无边框卡片 + 柔阴影。
  factory YucaiTheme.light() {
    return const YucaiTheme(
      bg: Color(0xFFF8FAFC),
      surface: Color(0xFFFFFFFF),
      surfaceAlt: Color(0xFFF1F5F9),
      border: Color(0xFFEEF2F7),
      fg: Color(0xFF0F172A),
      muted: Color(0xFF64748B),
      accent: Color(0xFF059669),
      accentDeep: Color(0xFF047857),
      accentSoft: Color(0xFFECFDF5),
      onAccent: Color(0xFFFFFFFF),
      positive: Color(0xFF059669),
      negative: Color(0xFFE11D48),
      info: Color(0xFF0EA5E9),
      warn: Color(0xFFD97706),
      sidebarBg: Color(0xFFFFFFFF),
      sidebarBorder: Color(0xFFEEF2F7),
      sidebarFg: Color(0xFF64748B),
      sidebarHover: Color(0xFFF1F5F9),
      sidebarActiveBg: Color(0xFFECFDF5),
      sidebarActiveFg: Color(0xFF047857),
      topbarBarrier: Color(0xD1FFFFFF), // rgba(255,255,255,.82)
    );
  }

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color fg;
  final Color muted;
  final Color accent;
  final Color accentDeep;
  final Color accentSoft;
  final Color onAccent;
  final Color positive;
  final Color negative;
  final Color info;
  final Color warn;
  final Color sidebarBg;
  final Color sidebarBorder;
  final Color sidebarFg;
  final Color sidebarHover;
  final Color sidebarActiveBg;
  final Color sidebarActiveFg;
  final Color topbarBarrier;

  @override
  YucaiTheme copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? fg,
    Color? muted,
    Color? accent,
    Color? accentDeep,
    Color? accentSoft,
    Color? onAccent,
    Color? positive,
    Color? negative,
    Color? info,
    Color? warn,
    Color? sidebarBg,
    Color? sidebarBorder,
    Color? sidebarFg,
    Color? sidebarHover,
    Color? sidebarActiveBg,
    Color? sidebarActiveFg,
    Color? topbarBarrier,
  }) {
    return YucaiTheme(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      fg: fg ?? this.fg,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      accentDeep: accentDeep ?? this.accentDeep,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      info: info ?? this.info,
      warn: warn ?? this.warn,
      sidebarBg: sidebarBg ?? this.sidebarBg,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      sidebarFg: sidebarFg ?? this.sidebarFg,
      sidebarHover: sidebarHover ?? this.sidebarHover,
      sidebarActiveBg: sidebarActiveBg ?? this.sidebarActiveBg,
      sidebarActiveFg: sidebarActiveFg ?? this.sidebarActiveFg,
      topbarBarrier: topbarBarrier ?? this.topbarBarrier,
    );
  }

  @override
  YucaiTheme lerp(YucaiTheme? other, double t) {
    if (other == null) return this;
    return YucaiTheme(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      fg: Color.lerp(fg, other.fg, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      info: Color.lerp(info, other.info, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      sidebarBg: Color.lerp(sidebarBg, other.sidebarBg, t)!,
      sidebarBorder: Color.lerp(sidebarBorder, other.sidebarBorder, t)!,
      sidebarFg: Color.lerp(sidebarFg, other.sidebarFg, t)!,
      sidebarHover: Color.lerp(sidebarHover, other.sidebarHover, t)!,
      sidebarActiveBg: Color.lerp(sidebarActiveBg, other.sidebarActiveBg, t)!,
      sidebarActiveFg: Color.lerp(sidebarActiveFg, other.sidebarActiveFg, t)!,
      topbarBarrier: Color.lerp(topbarBarrier, other.topbarBarrier, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YucaiTheme &&
          runtimeType == other.runtimeType &&
          bg == other.bg &&
          surface == other.surface &&
          surfaceAlt == other.surfaceAlt &&
          border == other.border &&
          fg == other.fg &&
          muted == other.muted &&
          accent == other.accent &&
          accentDeep == other.accentDeep &&
          accentSoft == other.accentSoft &&
          onAccent == other.onAccent &&
          positive == other.positive &&
          negative == other.negative &&
          info == other.info &&
          warn == other.warn &&
          sidebarBg == other.sidebarBg &&
          sidebarBorder == other.sidebarBorder &&
          sidebarFg == other.sidebarFg &&
          sidebarHover == other.sidebarHover &&
          sidebarActiveBg == other.sidebarActiveBg &&
          sidebarActiveFg == other.sidebarActiveFg &&
          topbarBarrier == other.topbarBarrier;

  @override
  int get hashCode => Object.hashAll([
        bg,
        surface,
        surfaceAlt,
        border,
        fg,
        muted,
        accent,
        accentDeep,
        accentSoft,
        onAccent,
        positive,
        negative,
        info,
        warn,
        sidebarBg,
        sidebarBorder,
        sidebarFg,
        sidebarHover,
        sidebarActiveBg,
        sidebarActiveFg,
        topbarBarrier,
      ]);
}

/// 组件层读取主题语义令牌:`context.yucai.accent`。
/// 缺失时回落亮色 —— 部分测试用裸 MaterialApp 挂载 shell(不装 extension),
/// 生产路径 AppTheme 恒注入,不受影响。
extension YucaiThemeX on BuildContext {
  YucaiTheme get yucai =>
      Theme.of(this).extension<YucaiTheme>() ?? YucaiTheme.light();
}

/// legacy 静态色(过渡期兼容层,R8 defer 清单:各模块页面迁移 context.yucai 后退役)。
/// 值 = v2 亮色(晨白),使未迁移页面在亮色主题下即刻对齐 v2。
class AppColors {
  const AppColors._();

  static const bg = Color(0xFFF8FAFC); // 净白主背景
  static const surface = Color(0xFFFFFFFF); // 卡片/容器
  static const surfaceAlt = Color(0xFFF1F5F9); // 次级容器(筛选条等)
  static const fg = Color(0xFF0F172A); // 深色正文
  static const muted = Color(0xFF64748B); // 石板灰辅助文字
  static const border = Color(0xFFEEF2F7); // 浅描边

  static const accent = Color(0xFF059669); // 翡翠绿(主操作,替换 v1 御财金)
  static const accentHover = Color(0xFF047857);
  static const accentSoft = Color(0xFFECFDF5); // 翡翠浅背景(激活标签等)

  static const positive = Color(0xFF059669); // 收入绿
  static const negative = Color(0xFFE11D48); // 支出红

  // 侧边栏(shell 已迁移 context.yucai;静态量仅供未迁移代码引用)。
  static const sidebar = Color(0xFF0E1219);
  static const sidebarFg = Color(0xFFB8B5AD);
  static const sidebarActive = Color(0x17E8C07A);
  static const sidebarHover = Color(0xFF151B26);
  static const sidebarDivider = Color(0xFF1B2231);
}

/// 间距体系:xs:6 sm:12 md:20 lg:28 xl:40。
class AppSpacing {
  const AppSpacing._();
  static const xs = 6.0;
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const xl = 40.0;
}

/// 圆角(v2 整体放大一档):sm:12 lg:16 xl:24(hero)。
class AppRadius {
  const AppRadius._();
  static const sm = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;

  static const smBorder = BorderRadius.all(Radius.circular(sm));
  static const lgBorder = BorderRadius.all(Radius.circular(lg));
  static const xlBorder = BorderRadius.all(Radius.circular(xl));
}

/// 字体栈(v2 全无衬线:v1 serif 标题退役,display 与 body 同栈)。
/// 数字处叠加 [tabularFigures] 等宽特性(对齐原型 .num)。
class AppTypography {
  const AppTypography._();

  /// 标题/正文统一 sans。Windows 上 Microsoft YaHei;跨平台回退。
  static const bodyFamily = 'Microsoft YaHei';
  static const bodyFallback = [
    'PingFang SC',
    'Segoe UI',
    'Helvetica',
    'Arial',
    'sans-serif',
  ];

  static const displayFamily = bodyFamily;
  static const List<String> displayFallback = bodyFallback;

  /// 等宽数字特性(叠加在正文字体上)。
  static const tabularFigures = <FontFeature>[FontFeature.tabularFigures()];
}
