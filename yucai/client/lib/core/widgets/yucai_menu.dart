import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// v2 卡片操作菜单统一样式（MenuAnchor）。
///
/// 所有卡片「更多」菜单统一走 MenuAnchor 锚定按钮本体 —— 自动翻转/钳制于
/// 窗口内，杜绝手算坐标（F4 前 accounts 卡用陈旧长按锚点导致菜单飞位、
/// debt 卡用底部抽屉在桌面端观感错位）。
MenuStyle yucaiMenuStyle(BuildContext context) {
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(context.yucai.surface),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    // F4-P2 黑阴影豁免复用论证(同 debt_list_widgets 口径):菜单投影
    // #1F000000(黑 12%)在暗色墨黑底上天然不可见,恰好等效 v2 暗色「无
    // 阴影」设计;改 fg 透导会引入白辉光,保原值不迁(与 _open 内联菜单
    // 同值同口径)。
    shadowColor: const WidgetStatePropertyAll(Color(0x1F000000)),
    elevation: const WidgetStatePropertyAll(6),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    ),
    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(36)),
  );
}


/// 菜单项数据(供 [YucaiAnchoredMenu])。
class YucaiMenuItemData {
  const YucaiMenuItemData({
    required this.label,
    required this.icon,
    this.onTap,
    this.destructive = false,
    this.enabled = true,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;
  final bool enabled;
}

/// 锚定弹出菜单 —— CompositedTransformLeader/Follower 实现。
///
/// 为什么不用 MenuAnchor:壳层「侧栏+顶栏+分支 Navigator」结构下,
/// MenuAnchor 经 OverlayPortal 渲染菜单,锚点矩形与目标 Overlay 坐标系
/// 脱节 → 菜单整体偏移(F5b/F5d 实测 -262px 水平漂移)。
/// Leader/Follower 是层级别锚定,跨 Navigator/Overlay 边界像素级贴合。
class YucaiAnchoredMenu extends StatefulWidget {
  const YucaiAnchoredMenu({
    super.key,
    required this.items,
    required this.builder,
    this.offset = const Offset(0, 6),
    this.menuWidth = 180,
  });

  final List<YucaiMenuItemData> items;
  /// 触发器 builder;[open] 由组件内部提供(切换开/关)。
  final Widget Function(BuildContext context, VoidCallback open) builder;
  final Offset offset;
  final double menuWidth;

  @override
  State<YucaiAnchoredMenu> createState() => _YucaiAnchoredMenuState();
}

class _YucaiAnchoredMenuState extends State<YucaiAnchoredMenu> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  bool get isOpen => _entry != null;

  void _toggle() => isOpen ? _close() : _open();

  void _open() {
    _close();
    _entry = OverlayEntry(
      builder: (_) => Stack(children: [
        // 全屏点击屏障:点菜单外任意处关闭(含滚动/拖动)。
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
            onPanUpdate: (_) => _close(),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: widget.offset,
          child: Material(
            color: Theme.of(context).extension<YucaiTheme>()!.surface,
            elevation: 6,
            // 黑阴影豁免(见 yucaiMenuStyle 注释,同值同口径)。
            shadowColor: const Color(0x1F000000),
            borderRadius: BorderRadius.circular(10),
            child: IntrinsicWidth(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in widget.items) ...[
                      _itemTile(item),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  Widget _itemTile(YucaiMenuItemData item) {
    final color = item.destructive ? context.yucai.negative : context.yucai.fg;
    return InkWell(
      onTap: item.enabled
          ? () {
              _close();
              item.onTap?.call();
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(children: [
          Icon(item.icon, size: 15, color: item.enabled ? color : context.yucai.muted),
          const SizedBox(width: 10),
          Text(item.label,
              style: TextStyle(
                  fontSize: 13.5,
                  color: item.enabled ? color : context.yucai.muted)),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: widget.builder(context, _toggle),
    );
  }
}
