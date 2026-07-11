import 'package:flutter/material.dart';

/// 御财设计令牌 —— 单一事实来源。
/// 匹配 docs/superpowers/specs/2026-06-08-yucai-ui-redesign-design.md 第 1 节。
/// 所有页面与组件只从这里取色/间距/圆角，不内联魔法值。
class AppColors {
  const AppColors._();

  static const bg = Color(0xFFF7F6F2); // 奶油白主背景
  static const surface = Color(0xFFFFFFFF); // 卡片/容器
  static const surfaceAlt = Color(0xFFFBFAF6); // 次级容器（分组区头等）
  static const fg = Color(0xFF1A1916); // 深色正文
  static const muted = Color(0xFF7A7770); // 灰色辅助文字
  static const border = Color(0xFFE6E3DC); // 暖灰边框

  static const accent = Color(0xFFB08D57); // 御财金（主操作）
  static const accentHover = Color(0xFF9C7A48);
  static const accentSoft = Color(0xFFF3ECDD); // 御财金浅背景（激活标签等）

  static const positive = Color(0xFF2D8A6E); // 收入绿
  static const negative = Color(0xFFC4544D); // 支出红

  // 侧边栏深色体系
  static const sidebar = Color(0xFF1C1E21);
  static const sidebarFg = Color(0xFFB8B5AD); // 侧栏次级文字
  static const sidebarActive = Color(0xFF2A2D31); // 激活项背景(全局侧栏)
  static const sidebarHover = Color(0xFF26292C);
  static const sidebarDivider = Color(0xFF33363A);

  // 子侧栏(模块内二级导航 SubMenuShell)深色体系。
  // subSidebar 略浅于全局 sidebar(#1C1E21,每通道 +0x06 同系区分);
  // subSidebarActive 比 subSidebar 更浅 → selected tile 凸起(避免选中反相)。
  static const subSidebar = Color(0xFF222427);
  static const subSidebarActive = Color(0xFF2C2F33);
}

/// 间距体系：xs:6 sm:12 md:20 lg:28 xl:40。
class AppSpacing {
  const AppSpacing._();
  static const xs = 6.0;
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const xl = 40.0;
}

/// 圆角：sm:10 lg:14。
class AppRadius {
  const AppRadius._();
  static const sm = 10.0;
  static const lg = 14.0;

  static const smBorder = BorderRadius.all(Radius.circular(sm));
  static const lgBorder = BorderRadius.all(Radius.circular(lg));
}

/// 字体栈：标题 serif，正文 sans，数字等宽。
class AppTypography {
  const AppTypography._();

  /// 标题（serif）。Windows 上 Georgia + 中文回退 SimSong；跨平台回退 Noto Serif SC。
  static const displayFamily = 'Georgia';
  static const List<String> displayFallback = [
    'Noto Serif SC',
    'Songti SC',
    'STSong',
    'SimSun',
    'serif',
  ];

  /// 正文（sans）。
  static const bodyFamily = 'Microsoft YaHei';
  static const List<String> bodyFallback = [
    'PingFang SC',
    'Segoe UI',
    'Helvetica',
    'Arial',
    'sans-serif',
  ];

  /// 等宽数字特性（叠加在正文字体上）。
  static const tabularFigures = <FontFeature>[FontFeature.tabularFigures()];
}
