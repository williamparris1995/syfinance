import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// Branch 元数据:面包屑(section › page)+ list 页创建按钮(label + route)。
/// [_TopBar] 按 branchIndex 取 meta,按 location 区分 list(显创建按钮)vs
/// detail/form/new/edit(不显)。对齐 OD .topbar(面包屑 .crumbs + 创建 .btn-primary)。
({String section, String page, String rootPath, String? createLabel, String? createRoute})
    _branchMetaOf(int index) {
  switch (index) {
    case 0:
      return (section: '', page: '仪表盘', rootPath: '/home', createLabel: null, createRoute: null);
    case 1:
      // accounts 无 /accounts/new route(client 创建入口待 account 模块补全);
      // topbar 暂不显创建按钮,避免 push 不存在路由。
      return (section: '财务', page: '账户管理', rootPath: '/accounts', createLabel: null, createRoute: null);
    case 2:
      return (
        section: '财务', page: '交易管理', rootPath: '/transactions',
        createLabel: '新增交易', createRoute: '/transactions/new',
      );
    case 3:
      return (
        section: '财务', page: '债务管理', rootPath: '/debts',
        createLabel: '新增债务', createRoute: '/debts/new',
      );
    case 4:
      return (
        section: '财务', page: '债权管理', rootPath: '/receivables',
        createLabel: '创建债权', createRoute: '/receivables/new',
      );
    case 5:
      return (
        section: '财务', page: '持仓管理', rootPath: '/holdings',
        createLabel: '买入持仓', createRoute: '/holdings/trade',
      );
    case 6:
      return (
        section: '财务', page: '预算管理', rootPath: '/budgets',
        createLabel: '新建预算', createRoute: '/budgets/new',
      );
    case 7:
      return (
        section: '规划', page: '目标管理', rootPath: '/goals',
        createLabel: '新建目标', createRoute: '/goals/new',
      );
    case 8:
      return (section: '系统', page: '设置', rootPath: '/settings', createLabel: null, createRoute: null);
    default:
      return (section: '', page: '御财', rootPath: '/', createLabel: null, createRoute: null);
  }
}

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
    final location = GoRouterState.of(context).uri.toString();

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
                      _TopBar(
                        branchIndex: navigationShell.currentIndex,
                        location: location,
                      ),
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
            child: _TopBar(
              branchIndex: navigationShell.currentIndex,
              location: location,
              compact: true,
            ),
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

  // branch 元数据(面包屑 section › page + list 页创建按钮)见顶层 _branchMetaOf。
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
    _NavItem('仪表盘', LucideIcons.layoutDashboard, 0),
  ]),
  _NavGroup('财务', [
    _NavItem('账户管理', LucideIcons.wallet, 1),
    _NavItem('预算管理', LucideIcons.piggyBank, 6, route: '/budgets'),
    _NavItem('目标追踪', LucideIcons.target, 7, route: '/goals'),
  ]),
  _NavGroup('交易', [
    _NavItem('分类管理', LucideIcons.tags, null, route: '/categories'),
  ]),
  _NavGroup('投资', [
    _NavItem('投资组合', LucideIcons.lineChart, 5, route: '/holdings'),
    _NavItem('交易记录', LucideIcons.receipt, 2),
  ]),
  _NavGroup('借贷', [
    _NavItem('债务管理', LucideIcons.landmark, 3, route: '/debts'),
    _NavItem('债权管理', LucideIcons.arrowUpRight, 4, route: '/receivables'),
  ]),
  _NavGroup('工具', [
    _NavItem('报表分析', LucideIcons.barChart, null),
    _NavItem('设置', LucideIcons.settings, 8),
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
                child: const Icon(LucideIcons.gem,
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
                          : item.branchIndex == currentIndex &&
                              !GoRouterState.of(context)
                                  .matchedLocation
                                  .startsWith('/categories'),
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
                icon: const Icon(LucideIcons.logOut,
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
  const _TopBar({
    required this.branchIndex,
    required this.location,
    this.compact = false,
  });

  final int branchIndex;
  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final meta = _branchMetaOf(branchIndex);
    // 创建按钮仅 list 页显(location == rootPath;detail/form/new/edit 不显)。
    final showCreate = meta.createLabel != null && location == meta.rootPath;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          // OD .topbar: rgba(247,246,242,.85)
          color: const Color(0xFFF7F6F2).withValues(alpha: 0.85),
          child: Row(children: [
            // 面包屑:section › page(对齐 OD .crumbs)。
            _BreadCrumb(section: meta.section, page: meta.page),
            const Spacer(),
            if (!compact)
              SizedBox(
                width: 220,
                child: TextField(
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '搜索交易、账户…',
                    isDense: true,
                    prefixIcon: const Icon(LucideIcons.search,
                        size: 16, color: AppColors.muted),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    // 高度收紧(vertical 6 + isDense),对齐 OD .tb-search 紧凑。
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ),
            if (!compact) const SizedBox(width: AppSpacing.sm),
            _TopBarIcon(LucideIcons.bell, '通知', () {}),
            if (!compact)
              _TopBarIcon(
                  LucideIcons.settings, '设置', () => context.go('/settings')),
            // 创建按钮(list 页,对齐 OD .topbar .btn-primary gold)—— 最右。
            if (showCreate) ...[
              const SizedBox(width: AppSpacing.sm),
              _TopBarCreate(label: meta.createLabel!, route: meta.createRoute!),
            ],
          ]),
        ),
      ),
    );
  }
}

/// topbar 图标按钮(通知/设置):透明底(去默认 fill/highlight 白底),hover accentSoft。
class _TopBarIcon extends StatelessWidget {
  const _TopBarIcon(this.icon, this.tooltip, this.onTap);
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 20, color: AppColors.muted),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: AppColors.accentSoft.withValues(alpha: 0.4),
        padding: EdgeInsets.zero,
        minimumSize: const Size(36, 36),
      ),
      onPressed: onTap,
    );
  }
}

/// 面包屑:section › page(section 空 → 仅 page,如仪表盘)。对齐 OD .crumbs。
class _BreadCrumb extends StatelessWidget {
  const _BreadCrumb({required this.section, required this.page});
  final String section;
  final String page;

  @override
  Widget build(BuildContext context) {
    final pageStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.fg,
      fontFamily: AppTypography.displayFamily,
      fontFamilyFallback: AppTypography.displayFallback,
    );
    if (section.isEmpty) {
      return Text(page, style: pageStyle);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(section,
          style: const TextStyle(fontSize: 14, color: AppColors.muted)),
      const SizedBox(width: 6),
      const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.muted),
      const SizedBox(width: 6),
      Text(page, style: pageStyle),
    ]);
  }
}

/// topbar 创建按钮(gold,对齐 OD .btn-primary)。push 到 create route。
class _TopBarCreate extends StatelessWidget {
  const _TopBarCreate({required this.label, required this.route});
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: AppRadius.smBorder,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33B08D57),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.plus, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
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
    // 底栏映射已实现的分支：仪表盘(0) / 交易(2) / 账户(1) / 债务(3) / 债权(4) / 退出
    // 五个分支索引 0/2/1/3/4 + 退出（末位），用 _branchSlots 把底栏位序 → 分支索引。
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
            icon: Icon(LucideIcons.layoutDashboard), label: '仪表盘'),
        NavigationDestination(
            icon: Icon(LucideIcons.receipt), label: '交易'),
        NavigationDestination(
            icon: Icon(LucideIcons.wallet),
            label: '账户'),
        NavigationDestination(
            icon: Icon(LucideIcons.landmark), label: '债务'),
        NavigationDestination(
            icon: Icon(LucideIcons.arrowUpRight), label: '债权'),
        NavigationDestination(
            icon: Icon(LucideIcons.lineChart), label: '持仓'),
        NavigationDestination(icon: Icon(LucideIcons.logOut), label: '退出'),
      ],
    );
  }

  /// 底栏位序 → 分支索引。底栏顺序为 仪表盘/交易/账户/债务/债权/持仓/退出，
  /// 对应分支 0/2/1/3/4/5，退出单独处理。未匹配的分支（如未来新增）回退到 0。
  static const _branchSlots = [0, 2, 1, 3, 4, 5];

  static int _slotIndexOf(int branchIndex) {
    final i = _branchSlots.indexOf(branchIndex);
    return i == -1 ? 0 : i;
  }
}
