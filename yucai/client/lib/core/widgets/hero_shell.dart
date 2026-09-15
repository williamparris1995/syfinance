import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// F26(R12 sprint-1)hero 变体 A 外壳 —— design-v2 §4「hero 净资产大卡
/// (暗=渐变描边+渐变金字,亮=白卡阴影+黑字)」。home 净资产 hero 与账户详情
/// hero 共用(复用第一;design.md HLD「如结构同则抽共享件」)。
///
/// 主题分支(ADR-3,`Theme.brightness` 判定,色值全部 `context.yucai` 语义令牌):
/// - 暗色 = surface 墨面卡 + 1.5px 金渐变描边:外层 Container 铺
///   accent→accentDeep LinearGradient(prototype 135deg = topLeft→bottomRight),
///   内层同圆角 surface Container 以 padding 镂空露出渐变边(ADR-1 双层容器
///   描边法,免自绘 painter);无阴影(墨鎏金「描边分层」口径)。
/// - 亮色 = surface 白卡 + 柔影(fg 5% 派生;AppTheme.cardTheme 亮色
///   shadowColor 0x0D0F172A = fg@5% 同口径),无边框(晨白「无边框卡片」)。
///
/// 圆角 AppRadius.xl(24,design-v2「hero 24」;外层);内层同心内缩
/// 24 − 描边宽(review:内外同值会角部描边 flare ≈2.12px);内层 clip 以裁住
/// 内容 Stack 里的负偏移金晕。金晕不在此壳内 —— 各 hero 自备 Stack +
/// [heroGlowAlpha]。
const double _kHeroBorderWidth = 1.5;

class HeroShell extends StatelessWidget {
  const HeroShell({super.key, required this.child, this.padding});

  final Widget child;

  /// 卡内边距(home hero 32;账户详情 hero OD .hero 28/32/30)。
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.yucai.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl - _kHeroBorderWidth),
        // 晨白柔影(fg 5%);墨鎏金无阴影(描边分层)。
        boxShadow: isDark ? null : _lightShadow(context),
      ),
      child: child,
    );
    if (!isDark) return card;
    return Container(
      // 描边宽 1.5(prototype v2 变体 A --hero-border-w;设计 Open Question
      // 定案:随变体页 1.5)。
      padding: const EdgeInsets.all(_kHeroBorderWidth),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.yucai.accent, context.yucai.accentDeep],
        ),
        borderRadius: AppRadius.xlBorder,
      ),
      child: card,
    );
  }

  /// 晨白柔影:双层照抄 prototype --shadow(theme.css「0 1px 2px +
  /// 0 4px 16px,均 fg@5%」;色口径 = AppTheme.cardTheme 亮色 shadowColor
  /// 0x0D0F172A 同源)——review P3:原单层手调值与事实源不符。
  static List<BoxShadow> _lightShadow(BuildContext context) => [
        BoxShadow(
          color: context.yucai.fg.withValues(alpha: 0.05),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: context.yucai.fg.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}

/// F26 ADR-2:hero 大数字暗色渐变金 —— ShaderMask(srcIn)叠 accent→accentDeep
/// LinearGradient(方向同描边 135deg);亮色直出 [child](数字自身走 fg)。
/// 仓内先例:debt_detail_widgets schedule 进度条 ShaderMask 同手法。
class HeroGradientText extends StatelessWidget {
  const HeroGradientText({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) return child;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [context.yucai.accent, context.yucai.accentDeep],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// F26 ADR-4:hero 金晕 alpha —— 单值 0.18 双主题(prototype .glow 单一定义,
/// 亮色无覆盖;review P2 修正:此前亮色 0.10 的「出处」失实)。
double heroGlowAlpha(BuildContext context) => 0.18;
