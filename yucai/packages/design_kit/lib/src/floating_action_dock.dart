import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// 悬浮簇动作描述(F58 design LLD 契约)。
class DockAction {
  const DockAction({required this.icon, required this.tooltip, this.onTap});

  /// 钮面图标。
  final IconData icon;

  /// 悬停提示 + 语义标签(可达性:每钮必有)。
  final String tooltip;

  /// null = 禁用态:不可触发、不获焦,视觉降权淡显(归档页降级先例);
  /// 落在 muted 段时两态叠加,以禁用为准(恒淡,hover/焦点不恢复)。
  final VoidCallback? onTap;
}

/// 竖排悬浮动作簇 —— 原型 v17 模型 C'(全平铺三段式,零菜单零折叠:
/// 主操作一步直达,一切操作可见;取代 v16 形态 B 的方圆次级+菜单)。
///
/// 结构进包、颜色全走 [DesignTokens] 缝(ADR-007:包内零宿主常量):
///  - primary:52px 圆,[DesignTokens.accentGradient] 渐变底,空则回落
///    [DesignTokens.accent] 纯色;阴影 = [DesignTokens.actionShadow](空则无);
///  - secondary / muted:44px 全圆钮(半径 = 边长一半,v16 方圆 12 废除),
///    surface 底 + border 描边 + muted 图标;secondary 正常亮度,
///    muted 降饱和淡显([DesignTokens.dimmedOpacity])—— 低频/危险项
///    置顶离主钮最远,视觉淡但可点可获焦,hover 与键盘焦点恢复满透明度;
///  - [secondary]/[muted] 均为自下而上的有序列表,渲染逆序
///    (Column 自上而下 = [...muted.reversed, 分隔线?, ...secondary.reversed,
///    primary];primary 恒最下);muted 非空时内置 1px 高 × 宽 20 居中
///    分隔线(tokens.border)隔开淡显组,空则无;相邻间距恒 10;
///    簇常驻不折叠,自身不含 Positioned —— 由宿主 Scaffold body Stack
///    摆放(定位是页面职责,不是组件职责)。
/// 尺寸均为总视觉口径(含描边,border-box):Ink 会把描边宽度内衬,
/// 故经其 width/height 定外盒,而非内容 SizedBox 定尺寸。
class FloatingActionDock extends StatelessWidget {
  const FloatingActionDock({
    super.key,
    required this.primary,
    this.secondary = const [],
    // F59 C' 增段:缺省空,F58 既有调用点(primary+secondary)零改动可编译。
    this.muted = const [],
    this.primaryForeground,
  });

  /// 主操作(每页恒有;禁用态经 [DockAction.onTap] null 表达,不缺席)。
  final DockAction primary;

  /// 高频次级操作,自下而上叠于 primary 之上(列表首项最贴近 primary)。
  final List<DockAction> secondary;

  /// 低频/危险操作,降饱和淡显组,渲染置顶(列表末项最上,离 primary 最远)。
  final List<DockAction> muted;

  /// primary 图标前景色;缺省白(纯中性缺省,宿主可注入自有强调前景)。
  final Color? primaryForeground;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in muted.reversed) ...[
          _tierButton(action, tokens, dimmed: true),
          const SizedBox(height: 10),
        ],
        // 内置分隔线:muted 非空才渲染(条件在结构里,不留给调用方摆)。
        if (muted.isNotEmpty) ...[
          _DockDivider(color: tokens.border),
          const SizedBox(height: 10),
        ],
        for (final action in secondary.reversed) ...[
          _tierButton(action, tokens, dimmed: false),
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

  /// 次级两段(secondary/muted)公共构造:同壳同令牌,差异只在亮度语言
  /// ([dimmed] 淡显 vs 正常),由 [_DockButton] 内部裁定透明度。
  Widget _tierButton(DockAction action, DesignTokens tokens,
      {required bool dimmed}) {
    // C' 全圆:半径 = 边长一半(44 → 22;v16 方圆 12 已废除)。
    final round = BorderRadius.circular(44 / 2);
    return _DockButton(
      action: action,
      size: 44,
      dimmed: dimmed,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: round,
      ),
      customBorder: RoundedRectangleBorder(borderRadius: round),
      iconColor: tokens.muted,
      iconSize: 20,
    );
  }
}

/// 淡显组与常规组之间的内置分隔线:1px 高、宽 20、水平居中(Column
/// 默认 CrossAxisAlignment.center 收拢到最宽的 primary 中轴),色走令牌。
class _DockDivider extends StatelessWidget {
  const _DockDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 20, height: 1, color: color);
}

/// 簇内单钮公共壳:Tooltip + Material/Ink + InkWell。
/// InkWell 自带 ActivateIntent 映射 → Tab 获焦后 Enter 即触发(键盘可达);
/// onTap 为 null 时 InkWell 自身不获焦不响应(禁用),外层 [Opacity] 降权。
///
/// 透明度裁定(C' 两种「淡」的语言,值共用 [DesignTokens.dimmedOpacity]):
///  - 禁用(onTap = null):不可点不获焦,恒淡 —— 与淡显叠加时以禁用为准;
///  - 淡显([dimmed] 组):视觉淡但可点可获焦,MouseRegion hover 与
///    InkWell 焦点(onFocusChange)任一命中即恢复满透明度,离开/失焦回淡
///    (NFR-2:焦点态视觉不淡)。
class _DockButton extends StatefulWidget {
  const _DockButton({
    required this.action,
    required this.size,
    required this.decoration,
    required this.customBorder,
    required this.iconColor,
    required this.iconSize,
    this.dimmed = false,
  });

  final DockAction action;

  /// 是否属淡显组(muted);primary/secondary 正常亮度。
  final bool dimmed;
  final double size;

  /// 钮面装饰(渐变/纯色/描边差异全部在此,壳不关心)。
  final Decoration decoration;

  /// 水波/悬停高亮裁形,与装饰形状一致。
  final ShapeBorder customBorder;
  final Color iconColor;
  final double iconSize;

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final disabled = widget.action.onTap == null;
    // 恢复仅对「可点的淡显钮」生效;禁用恒淡(叠加以禁用为准)。
    final restored = widget.dimmed && !disabled && (_hovered || _focused);
    final opacity =
        disabled || widget.dimmed ? (restored ? 1.0 : tokens.dimmedOpacity) : 1.0;
    return Opacity(
      opacity: opacity,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Tooltip(
          message: widget.action.tooltip,
          child: Material(
            color: Colors.transparent,
            child: Ink(
              width: widget.size,
              height: widget.size,
              decoration: widget.decoration,
              child: InkWell(
                onTap: widget.action.onTap,
                customBorder: widget.customBorder,
                onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
                child: SizedBox.expand(
                  child: Center(
                    child: Icon(widget.action.icon,
                        size: widget.iconSize, color: widget.iconColor),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
