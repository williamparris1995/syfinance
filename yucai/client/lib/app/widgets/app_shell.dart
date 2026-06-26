import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// 应用外壳（侧边栏 + 顶栏 + 内容区）。
/// 由 [StatefulShellRoute] 驱动：[navigationShell] 切换各功能分支，
/// 侧栏/顶栏在整个受保护区域内保持挂载、状态不丢失。
/// 对应设计规范 §2.1/§2.2（侧边栏 + 顶栏布局）。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final userName = auth is Authenticated ? auth.user.displayName : '御财用户';
    final title = _branchTitle(navigationShell.currentIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1100) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            body: Row(
              children: [
                _Sidebar(
                  currentIndex: navigationShell.currentIndex,
                  userName: userName,
                  onSelect: (i) => navigationShell.goBranch(i,
                      initialLocation: i == navigationShell.currentIndex),
                  onLogout: () =>
                      context.read<AuthBloc>().add(LogoutRequested()),
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(title: title),
                      const Divider(height: 1, color: AppColors.border),
                      Expanded(child: navigationShell),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        // 窄屏：底部导航 + 简化顶栏
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: _TopBar(title: title, compact: true),
          ),
          body: navigationShell,
          bottomNavigationBar: _BottomNav(
            currentIndex: navigationShell.currentIndex,
            onSelect: (i) => navigationShell.goBranch(i,
                initialLocation: i == navigationShell.currentIndex),
            onLogout: () =>
                context.read<AuthBloc>().add(LogoutRequested()),
          ),
        );
      },
    );
  }

  String _branchTitle(int index) {
    switch (index) {
      case 0:
        return '仪表盘';
      case 1:
        return '账户管理';
      case 2:
        return '交易管理';
      case 3:
        return '债务管理';
      default:
        return '御财';
    }
  }
}

// ───────────────────────── 侧边栏 ─────────────────────────

class _NavItem {
  const _NavItem(this.label, this.icon, this.branchIndex,
      {this.badge, this.route});
  final String label;
  final IconData icon;
  final int? branchIndex; // null = 即将上线（禁用）或由 route 自定义导航
  final String? badge;
  // 自定义导航目标路由（非 branch 切换）。非 null 时该项可点击，走 context.go(route)。
  // 例如「分类管理」位于 transactions branch 内（/categories），不是顶层 branch，
  // 不能用 navigationShell.goBranch，改用 context.go('/categories')。
  final String? route;
}

class _NavGroup {
  const _NavGroup(this.title, this.items);
  final String title;
  final List<_NavItem> items;
}

const _navGroups = <_NavGroup>[
  _NavGroup('概览', [
    _NavItem('仪表盘', Icons.dashboard_outlined, 0),
  ]),
  _NavGroup('财务', [
    _NavItem('账户管理', Icons.account_balance_wallet_outlined, 1),
    _NavItem('预算管理', Icons.savings_outlined, null),
    _NavItem('目标追踪', Icons.flag_outlined, null),
  ]),
  _NavGroup('交易', [
    _NavItem('分类管理', Icons.category_outlined, null, route: '/categories'),
  ]),
  _NavGroup('投资', [
    _NavItem('投资组合', Icons.show_chart_outlined, null, badge: '5'),
    _NavItem('交易记录', Icons.receipt_long_outlined, 2),
  ]),
  _NavGroup('借贷', [
    _NavItem('债务管理', Icons.account_balance_wallet_outlined, 3,
        route: '/debts'),
  ]),
  _NavGroup('工具', [
    _NavItem('报表分析', Icons.bar_chart_outlined, null),
    _NavItem('设置', Icons.settings_outlined, null, route: '/settings'),
  ]),
];

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentIndex,
    required this.userName,
    required this.onSelect,
    required this.onLogout,
  });

  final int currentIndex;
  final String userName;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.sidebar,
      child: Column(
        children: [
          // 品牌区
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.diamond_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '御财',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback,
                    ),
                  ),
                  Text('财务管家',
                      style: TextStyle(
                          color: AppColors.sidebarFg.withValues(alpha: 0.8),
                          fontSize: 11)),
                ],
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                for (final g in _navGroups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
                    child: Text(
                      g.title,
                      style: TextStyle(
                        color: AppColors.sidebarFg.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  for (final item in g.items)
                    _NavItemTile(
                      item: item,
                      // route 项：当前路径在 /categories 下时高亮（非 branch index）。
                      selected: item.route != null
                          ? GoRouterState.of(context)
                              .matchedLocation
                              .startsWith(item.route!)
                          : item.branchIndex == currentIndex,
                      onTap: item.branchIndex == null && item.route == null
                          ? null
                          : () {
                              if (item.route != null) {
                                context.go(item.route!);
                              } else if (item.branchIndex != null) {
                                onSelect(item.branchIndex!);
                              }
                            },
                    ),
                ],
              ],
            ),
          ),
          // 用户区
          Container(
            decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.sidebarDivider))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.accent,
                child: Text(
                  userName.isNotEmpty ? userName.characters.first : '财',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    Text('高级会员',
                        style: TextStyle(
                            color: AppColors.sidebarFg, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                tooltip: '退出登录',
                icon: const Icon(Icons.logout,
                    color: AppColors.sidebarFg, size: 18),
                onPressed: onLogout,
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _NavItemTile extends StatefulWidget {
  const _NavItemTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_NavItemTile> createState() => _NavItemTileState();
}

class _NavItemTileState extends State<_NavItemTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final selected = widget.selected;

    Color bg;
    if (selected) {
      bg = AppColors.sidebarActive;
    } else if (_hover && enabled) {
      bg = AppColors.sidebarHover;
    } else {
      bg = Colors.transparent;
    }
    final fg = selected
        ? Colors.white
        : (enabled
            ? (_hover ? Colors.white : AppColors.sidebarFg)
            : AppColors.sidebarFg.withValues(alpha: 0.4));
    final iconColor = selected
        ? AppColors.accent
        : (enabled
            ? (_hover ? Colors.white : AppColors.sidebarFg)
            : AppColors.sidebarFg.withValues(alpha: 0.4));

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(widget.item.badge!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10)),
              )
            else if (!enabled)
              Text('敬请期待',
                  style: TextStyle(
                      color: AppColors.sidebarFg.withValues(alpha: 0.4),
                      fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── 顶栏 ─────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.compact = false});

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          // OD .topbar: rgba(247,246,242,.85)
          color: const Color(0xFFF7F6F2).withValues(alpha: 0.85),
          child: Row(children: [
        Text(title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.fg,
              fontFamily: AppTypography.displayFamily,
              fontFamilyFallback: AppTypography.displayFallback,
            )),
        const Spacer(),
        if (!compact)
          SizedBox(
            width: 220,
            child: TextField(
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: '搜索交易、账户…',
                isDense: true,
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppColors.muted),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          tooltip: '通知',
          icon: const Icon(Icons.notifications_none_outlined,
              color: AppColors.muted),
          onPressed: () {},
        ),
        if (!compact)
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.muted),
            onPressed: () => context.go('/settings'),
          ),
      ]),
        ),
      ),
    );
  }
}

// ───────────────────────── 移动底部导航 ─────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentIndex,
    required this.onSelect,
    required this.onLogout,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    // 底栏映射已实现的分支：仪表盘(0) / 交易(2) / 账户(1) / 债务(3) / 退出
    // 四个分支索引 0/2/1/3 + 退出（末位），用 _branchSlots 把底栏位序 → 分支索引。
    return NavigationBar(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accentSoft,
      selectedIndex: _slotIndexOf(currentIndex),
      onDestinationSelected: (i) {
        if (i < _branchSlots.length) {
          onSelect(_branchSlots[i]);
        } else {
          onLogout();
        }
      },
      destinations: const [
        NavigationDestination(
            icon: Icon(Icons.dashboard_outlined), label: '仪表盘'),
        NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined), label: '交易'),
        NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: '账户'),
        NavigationDestination(
            icon: Icon(Icons.credit_card_outlined), label: '债务'),
        NavigationDestination(icon: Icon(Icons.logout), label: '退出'),
      ],
    );
  }

  /// 底栏位序 → 分支索引。底栏顺序为 仪表盘/交易/账户/债务/退出，
  /// 对应分支 0/2/1/3，退出单独处理。未匹配的分支（如未来新增）回退到 0。
  static const _branchSlots = [0, 2, 1, 3];

  static int _slotIndexOf(int branchIndex) {
    final i = _branchSlots.indexOf(branchIndex);
    return i == -1 ? 0 : i;
  }
}
