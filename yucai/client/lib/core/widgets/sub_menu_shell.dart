// 通用「子菜单壳」:模块内二级导航。
//
// ≥1100 桌面:左侧垂直 SubMenuSidebar(对齐 OD 垂直模块侧栏 + M3 navigation rail);
// <1100 平板/手机:顶部横向 SubMenuTab(M3 允许 mobile tab bar)。
// items 配置驱动,各模块按需复用(holding 首批接入)。
// 对齐 Apple HIG「sidebar within a tab」(≤2 层:全局 L1 + 模块 L2)。
//
// 视觉:方案 A 统一深色 — 子侧栏 AppColors.subSidebar(全局 sidebar #1C1E21 略浅,
// 同系区分);selected tile 用 AppColors.subSidebarActive(更浅 → 凸起,避免选中反相)。
// 高亮 left-border accent + 选中底色(复用 app_shell._NavItemTile 模式)。
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// 一个子菜单导航项。
class SubMenuItem {
  const SubMenuItem({
    required this.label,
    required this.icon,
    required this.route,
    this.group,
    this.badge,
  });
  final String label;
  final IconData icon;
  final String route; // 完整路由路径,点击 context.go(route)
  final String? group; // 分组名(侧栏按 group 分组;tab 扁平忽略)
  final String? badge; // 可选计数(如持仓列表 6)
}

/// 模块内二级导航壳:LayoutBuilder 切换 垂直侧栏(桌面)/ 横向 tab(窄屏)。
/// [child] 是当前匹配子路由的 outlet(由 GoRouter ShellRoute 注入)。
class SubMenuShell extends StatelessWidget {
  const SubMenuShell({super.key, required this.items, required this.child});

  final List<SubMenuItem> items;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1100) {
          return Row(
            children: [
              SubMenuSidebar(items: items),
              const VerticalDivider(width: 1, color: AppColors.border),
              Expanded(child: child),
            ],
          );
        }
        return Column(
          children: [
            SubMenuTab(items: items),
            const Divider(height: 1, color: AppColors.border),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// 当前路由是否对应某 item。
/// 精确匹配优先;非任何 item 的子路径(如 /holdings/:id 详情、/holdings/trade 操作)
/// → 回退高亮第一个 item(列表),对齐 OD「详情从属列表」。
bool _subMenuMatches(String current, String route, List<SubMenuItem> items) {
  if (current == route) return true;
  if (!items.any((i) => i.route == current)) {
    return route == items.first.route;
  }
  return false;
}

/// 垂直子侧栏(桌面)。items 按 group 分组;路由感知高亮;点击 context.go。
class SubMenuSidebar extends StatelessWidget {
  const SubMenuSidebar({super.key, required this.items});
  final List<SubMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final current = GoRouterState.of(context).matchedLocation;
    final groups = <String?>[...{for (final i in items) i.group}];
    return Container(
      width: 180,
      color: AppColors.subSidebar, // 方案 A:全局 sidebar(#1C1E21)略浅,同系区分
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        children: [
          for (final g in groups) ...[
            if (g != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Text(
                  g,
                  style: TextStyle(
                    color: AppColors.sidebarFg.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            for (final it in items.where((i) => i.group == g))
              _SidebarTile(
                item: it,
                selected: _subMenuMatches(current, it.route, items),
                onTap: () => context.go(it.route),
              ),
          ],
        ],
      ),
    );
  }
}

class _SidebarTile extends StatefulWidget {
  const _SidebarTile({required this.item, required this.selected, required this.onTap});
  final SubMenuItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final bg = selected
        ? AppColors.subSidebarActive
        : (_hover ? AppColors.sidebarHover : Colors.transparent);
    final fg = selected ? Colors.white : (_hover ? Colors.white : AppColors.sidebarFg);
    final iconColor =
        selected ? AppColors.accent : (_hover ? Colors.white : AppColors.sidebarFg);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.smBorder,
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(children: [
            Icon(widget.item.icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.item.label,
                style: TextStyle(
                    color: fg, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            if (widget.item.badge != null)
              Text(widget.item.badge!,
                  style: TextStyle(
                      color: AppColors.sidebarFg.withValues(alpha: 0.6),
                      fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}

/// 横向子菜单 tab(窄屏降级)。items 扁平;路由感知高亮;点击 context.go。
class SubMenuTab extends StatelessWidget {
  const SubMenuTab({super.key, required this.items});
  final List<SubMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final current = GoRouterState.of(context).matchedLocation;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final it in items)
              _TabItem(
                label: it.label,
                icon: it.icon,
                selected: _subMenuMatches(current, it.route, items),
                onTap: () => context.go(it.route),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: 2,
                  color: selected ? AppColors.accent : Colors.transparent,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
