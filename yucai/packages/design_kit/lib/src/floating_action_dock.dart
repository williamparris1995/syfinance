import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// 悬浮簇动作描述(F58 design LLD 契约)。
class DockAction {
  const DockAction({required this.icon, required this.tooltip, this.onTap});

  /// 钮面图标。
  final IconData icon;

  /// 悬停提示 + 语义标签(可达性:每钮必有)。
  final String tooltip;

  /// null = 禁用态:不可触发、不获焦,视觉半透明降权(归档页降级先例)。
  final VoidCallback? onTap;
}

/// 竖排悬浮动作簇 —— 原型 v16 形态 B(详情页右下角常驻操作簇)。
///
/// 结构进包、颜色全走 [DesignTokens] 缝(ADR-007:包内零宿主常量):
///  - primary:52px 圆,[DesignTokens.accentGradient] 渐变底,空则回落
///    [DesignTokens.accent] 纯色;阴影 = [DesignTokens.actionShadow](空则无);
///  - secondary:44px 方圆钮,surface 底 + border 描边 + muted 图标;
///  - [secondary] 为自下而上的有序列表,渲染逆序叠于 primary 之上
///    (primary 恒最下);簇常驻不折叠,自身不含 Positioned —— 由宿主
///    Scaffold body Stack 摆放(定位是页面职责,不是组件职责)。
/// 尺寸均为总视觉口径(含描边,border-box):Ink 会把描边宽度内衬,
/// 故经其 width/height 定外盒,而非内容 SizedBox 定尺寸。
class FloatingActionDock extends StatelessWidget {
  const FloatingActionDock({
    super.key,
    required this.primary,
    this.secondary = const [],
    this.primaryForeground,
  });

  /// 主操作(每页恒有;禁用态经 [DockAction.onTap] null 表达,不缺席)。
  final DockAction primary;

  /// 次级操作,自下而上叠于 primary 之上(列表首项最贴近 primary)。
  final List<DockAction> secondary;

  /// primary 图标前景色;缺省白(纯中性缺省,宿主可注入自有强调前景)。
  final Color? primaryForeground;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in secondary.reversed) ...[
          _DockButton(
            action: action,
            size: 44,
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border.all(color: tokens.border),
              borderRadius: BorderRadius.circular(12),
            ),
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            iconColor: tokens.muted,
            iconSize: 20,
          ),
          const SizedBox(height: 10),
        ],
        _DockButton(
          action: primary,
          size: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: tokens.accentGradient.isEmpty
                ? null // 渐变未注入:回落 accent 纯色,不留空窗
                : LinearGradient(colors: tokens.accentGradient),
            color: tokens.accentGradient.isEmpty ? tokens.accent : null,
            boxShadow: tokens.actionShadow,
          ),
          customBorder: const CircleBorder(),
          iconColor: primaryForeground ?? Colors.white,
          iconSize: 24,
        ),
      ],
    );
  }
}

/// 簇内单钮公共壳:Tooltip + Material/Ink + InkWell。
/// InkWell 自带 ActivateIntent 映射 → Tab 获焦后 Enter 即触发(键盘可达);
/// onTap 为 null 时 InkWell 自身不获焦不响应,外层 [Opacity] 给半透明降权
/// (半透明会透出底内容,非降饱和;禁用语义以不获焦/不触发为准)。
class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.action,
    required this.size,
    required this.decoration,
    required this.customBorder,
    required this.iconColor,
    required this.iconSize,
  });

  final DockAction action;
  final double size;

  /// 钮面装饰(渐变/纯色/描边差异全部在此,壳不关心)。
  final Decoration decoration;

  /// 水波/悬停高亮裁形,与装饰形状一致。
  final ShapeBorder customBorder;
  final Color iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: action.onTap == null ? 0.45 : 1, // 禁用:半透明降权(非降饱和)
      child: Tooltip(
        message: action.tooltip,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            width: size,
            height: size,
            decoration: decoration,
            child: InkWell(
              onTap: action.onTap,
              customBorder: customBorder,
              child: SizedBox.expand(
                child: Center(
                  child: Icon(action.icon, size: iconSize, color: iconColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
