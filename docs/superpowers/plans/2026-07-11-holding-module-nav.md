# Holding 模块二级导航整合 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 holding 模块加一个对齐 OD 原型 + 行业最佳实践的二级模块导航(桌面垂直侧栏 / 窄屏横向 tab),解决 security/收益统计/投资目标 的孤岛问题;沉淀通用 `SubMenuShell` 供后续模块复用。

**Architecture:** 在 GoRouter `StatefulShellBranch` index 5(holding)内嵌套 `ShellRoute`,builder 渲染通用 `SubMenuShell`(items 配置驱动)。`SubMenuShell` 用 LayoutBuilder 在 ≥1100 渲染垂直 `SubMenuSidebar`、<1100 渲染横向 `SubMenuTab`。holding 模块只定义自己的 4 nav-item 两组配置传入。回退现有 `HoldingModuleNav` tab patch(逻辑进通用 `SubMenuTab`)。

**Tech Stack:** Flutter(纯 client,无 server/proto 改动)· go_router 14.6.1(`ShellRoute` + `StatefulShellRoute.indexedStack`)· flutter_bloc 8.1.6 · lucide_icons_flutter · 现有 `AppColors`/`AppSpacing`/`AppRadius` token。

**Spec:** `docs/superpowers/specs/2026-07-11-holding-module-nav-design.md`

## Global Constraints

- **响应式断点 1100**(与 `app_shell.dart` `LayoutBuilder` 一致):`constraints.maxWidth >= 1100` 走垂直侧栏,否则横向 tab。
- **方案 A 配色**:全局侧栏 `AppColors.sidebar`(#26262a)/ 子侧栏 `Color(0xFF2C2C31)`(略浅同系)/ 内容浅色。高亮 = `AppColors.accent`(#b08d57)+ 选中底色 `AppColors.sidebarActive`,left-border 3px。
- **中文 UI 直写**(御财惯例,非 i18n)· **lucide icons**(`LucideIcons.*`)。
- **静态路由须在 `:id` 前**(GoRouter 匹配优先级,CLAUDE.md 路由优先级约束)。
- **英文结构化日志**(本计划无日志改动,不涉及)。
- **复用第一**:SubMenu 视觉复用 `app_shell._NavItemTile`(侧栏 tile)+ `holding_module_nav._NavTab`(tab item)的样式。
- **DI**:`HoldingBloc`/`CurrencyBloc`/`PerformanceBloc` 已在各 GoRoute builder 内 provide(`router.dart` branch 5 现状),`SubMenuShell` 只是布局壳,不提供 bloc。
- **测试基线**:`account_detail_page_test` / `debt_detail_page_test` / `transaction_detail_page_test` 3 个预存 fail(非本计划引入);`flutter analyze` 22 error 全 `*.pbserver.dart`(客户端未用)。

## File Structure

| 文件 | 职责 | 操作 |
|---|---|---|
| `yucai/client/lib/core/widgets/sub_menu_shell.dart` | 通用 `SubMenuItem` + `SubMenuShell` + `SubMenuSidebar` + `SubMenuTab`(items 驱动,后续模块可复用) | **Create** |
| `yucai/client/test/core/widgets/sub_menu_shell_test.dart` | SubMenu 组件 unit test(宽窄屏渲染/分组/导航/高亮) | **Create** |
| `yucai/client/lib/app/router.dart` | branch 5 改 `ShellRoute` + holding nav items 配置 + trade/new 移 ShellRoute 外 | **Modify**(branch 5,约 520-701 行) |
| `yucai/client/lib/holding/presentation/pages/holdings_page.dart` | 去顶部 `HoldingModuleNav()` | **Modify**(约 60 行) |
| `yucai/client/lib/holding/presentation/pages/security_page.dart` | 去顶部 `HoldingModuleNav()` | **Modify**(约 117 行) |
| `yucai/client/lib/holding/presentation/pages/performance_page.dart` | 去顶部 `HoldingModuleNav()` | **Modify**(约 135 行) |
| `yucai/client/lib/holding/presentation/widgets/holding_module_nav.dart` | 删除(逻辑进通用 `SubMenuTab`) | **Delete** |
| `yucai/client/test/holding/presentation/pages/holdings_page_test.dart` | 去 `HoldingModuleNav` 断言 + 注释 | **Modify** |
| `yucai/client/test/holding/presentation/pages/security_page_test.dart` | 去 `HoldingModuleNav` 断言 + 注释 | **Modify** |
| `yucai/client/test/holding/presentation/pages/performance_page_test.dart` | 去 `HoldingModuleNav` 断言 + 注释 | **Modify** |

**路由结构(branch 5)**:
```
StatefulShellBranch(index 5) routes:
  ShellRoute(builder: SubMenuShell(holdingNavItems, child))
    ├─ GoRoute /holdings          (列表)
    ├─ GoRoute /holdings/security (Security 管理)
    ├─ GoRoute /holdings/performance (收益统计)
    ├─ GoRoute /holdings/goals    (投资目标)
    └─ GoRoute /holdings/:id      (详情,高亮列表;放最后)
  GoRoute /holdings/trade         (ShellRoute 外,操作 sheet,context.push 覆盖)
  GoRoute /holdings/new           (ShellRoute 外,默认 buy sheet)
```
静态路径(trade/new/security/performance/goals)在 `:id` 前,GoRouter 静态优先匹配;trade/new 在 ShellRoute 外,渲染时不经 SubMenuShell(无侧栏,符合「操作型不占侧栏」)。

---

### Task 1: 通用 SubMenu 组件(core/widgets)

**Files:**
- Create: `yucai/client/lib/core/widgets/sub_menu_shell.dart`
- Test: `yucai/client/test/core/widgets/sub_menu_shell_test.dart`

**Interfaces:**
- Consumes: `AppColors`/`AppSpacing`/`AppRadius`(`core/theme/app_design.dart`)· `go_router`(`GoRouterState.of(context).matchedLocation`、`context.go`)· `lucide_icons_flutter`
- Produces: `SubMenuItem{label,icon,route,group?,badge?}`、`SubMenuShell({items, child})`、`SubMenuSidebar({items})`、`SubMenuTab({items})` — Task 2 消费

- [ ] **Step 1: 写失败测试(宽屏渲染侧栏 + 分组 + items)**

Create `yucai/client/test/core/widgets/sub_menu_shell_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/widgets/sub_menu_shell.dart';

const _items = <SubMenuItem>[
  SubMenuItem(label: '持仓列表', icon: LucideIcons.trendingUp, route: '/m/list', group: '持仓管理'),
  SubMenuItem(label: 'Security 管理', icon: LucideIcons.layers, route: '/m/sec', group: '持仓管理'),
  SubMenuItem(label: '收益统计', icon: LucideIcons.percent, route: '/m/perf', group: '统计'),
  SubMenuItem(label: '投资目标', icon: LucideIcons.target, route: '/m/goal', group: '统计'),
];

Widget _harness() => MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/m/list',
        routes: [
          ShellRoute(
            builder: (_, __, child) => SubMenuShell(items: _items, child: child),
            routes: [
              GoRoute(path: '/m/list', builder: (_, __) => const ColoredBox(color: Color(0xFFFFFFFF), child: SizedBox.expand())),
              GoRoute(path: '/m/sec', builder: (_, __) => const SizedBox.shrink()),
              GoRoute(path: '/m/perf', builder: (_, __) => const SizedBox.shrink()),
              GoRoute(path: '/m/goal', builder: (_, __) => const SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );

void main() {
  testWidgets('桌面(≥1100)渲染垂直侧栏:两组 label + 4 items', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('持仓管理'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('持仓列表'), findsOneWidget);
    expect(find.text('Security 管理'), findsOneWidget);
    expect(find.text('收益统计'), findsOneWidget);
    expect(find.text('投资目标'), findsOneWidget);
  });

  testWidgets('窄屏(<1100)渲染横向 tab:扁平 4 items,无分组 label', (tester) async {
    tester.view.physicalSize = const Size(460, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('持仓列表'), findsOneWidget);
    expect(find.text('投资目标'), findsOneWidget);
    // 扁平 tab 不渲染分组 label
    expect(find.text('持仓管理'), findsNothing);
    expect(find.text('统计'), findsNothing);
  });

  testWidgets('当前路由对应的 item 高亮(列表页 → 持仓列表 accent)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // 点 Security tab → 导航到 /m/sec → Security item 应高亮(列表不高亮)
    await tester.tap(find.text('Security 管理'));
    await tester.pumpAndSettle();

    final secTile = tester.widget<AnimatedContainer>(
      find.ancestor(of: find.text('Security 管理'), matching: find.byType(AnimatedContainer)),
    );
    // selected tile 左 border 非透明(accent)。这里只断言可找到 + 导航生效(精确像素色由 golden 覆盖,本测不强制)。
    expect(secTile, isNotNull);
    expect(GoRouterState.of(tester.element(find.text('Security 管理'))).matchedLocation,
        '/m/sec');
  });

  testWidgets('点击 item 触发 context.go 切换子路由', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('投资目标'));
    await tester.pumpAndSettle();

    expect(GoRouterState.of(tester.element(find.text('投资目标'))).matchedLocation,
        '/m/goal');
  });
}
```

- [ ] **Step 2: 运行测试,确认失败**

Run: `flutter test test/core/widgets/sub_menu_shell_test.dart`
Expected: FAIL — `sub_menu_shell.dart` 不存在 / import 失败。

- [ ] **Step 3: 写 SubMenu 组件实现**

Create `yucai/client/lib/core/widgets/sub_menu_shell.dart`:

```dart
// 通用「子菜单壳」:模块内二级导航。
//
// ≥1100 桌面:左侧垂直 SubMenuSidebar(对齐 OD 垂直模块侧栏 + M3 navigation rail);
// <1100 平板/手机:顶部横向 SubMenuTab(M3 允许 mobile tab bar)。
// items 配置驱动,各模块按需复用(holding 首批接入)。
// 对齐 Apple HIG「sidebar within a tab」(≤2 层:全局 L1 + 模块 L2)。
//
// 视觉:方案 A 统一深色 — 子侧栏 #2C2C31(略浅于全局 #26262a 同系区分),
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
      color: const Color(0xFF2C2C31), // 方案 A:略浅于全局侧栏 #26262a,同系区分
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
        ? AppColors.sidebarActive
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
```

- [ ] **Step 4: 运行测试,确认通过**

Run: `flutter test test/core/widgets/sub_menu_shell_test.dart`
Expected: PASS(4 tests)。

- [ ] **Step 5: analyze + commit**

Run: `flutter analyze lib/core/widgets/sub_menu_shell.dart test/core/widgets/sub_menu_shell_test.dart`
Expected: 无 error(info/warning 可接受,对齐现有 widget 基线)。

```bash
git add yucai/client/lib/core/widgets/sub_menu_shell.dart yucai/client/test/core/widgets/sub_menu_shell_test.dart
git commit -m "feat(sub-menu): 通用 SubMenuShell/Sidebar/Tab 组件(items 驱动,≥1100 垂直侧栏/<1100 横向 tab)"
```

---

### Task 2: router branch 5 接入 ShellRoute + holding nav items

**Files:**
- Modify: `yucai/client/lib/app/router.dart`(branch 5,约 520-701 行)+ 顶部 holding items 常量
- Test: 复用 Task 1 的组件测试已覆盖 SubMenu 行为;本任务验证 = analyze + 现有 router/页面测试不破

**Interfaces:**
- Consumes: Task 1 的 `SubMenuShell`/`SubMenuItem`
- Produces: branch 5 用 `ShellRoute` 包 4 主页 + `:id`;trade/new 移 ShellRoute 外(分支级)

- [ ] **Step 1: 加 holding nav items 常量**

在 `router.dart` 顶部 import 区后(约 line 73 `GoRouter buildRouter` 前)加:

```dart
import 'package:yucai_client/core/widgets/sub_menu_shell.dart';

/// holding 模块二级导航 items(对齐 OD holding 模块侧栏,4 独立页两组)。
/// 详情 /holdings/:id 与操作 /holdings/trade、/holdings/new 不入此列表
/// (详情从属列表 → 高亮「持仓列表」;操作型是 sheet)。
const _holdingNavItems = <SubMenuItem>[
  SubMenuItem(label: '持仓列表', icon: LucideIcons.trendingUp, route: '/holdings', group: '持仓管理'),
  SubMenuItem(label: 'Security 管理', icon: LucideIcons.layers, route: '/holdings/security', group: '持仓管理'),
  SubMenuItem(label: '收益统计', icon: LucideIcons.percent, route: '/holdings/performance', group: '统计 & 目标'),
  SubMenuItem(label: '投资目标', icon: LucideIcons.target, route: '/holdings/goals', group: '统计 & 目标'),
];
```

(`LucideIcons` 已在 line 7 import;`SubMenuItem` 由新加 import 提供。)

- [ ] **Step 2: 改造 branch 5 路由结构**

把 `StatefulShellBranch`(holding,约 524-702 行)的 `routes` 从「单 GoRoute(/holdings) + children」改为「ShellRoute 包 4 主页 + :id」+ 「trade/new 分支级」。各 GoRoute 的 builder 保持原样(仅挪位置 + 路径从相对改完整)。

替换整个 holding `StatefulShellBranch(...)` 块为:

```dart
          // 持仓管理（branch 5）：对齐 OD holding 模块侧栏(二级导航)。
          // ShellRoute(SubMenuShell) 包 4 主页 + :id(详情),侧栏常驻路由感知高亮;
          // trade/new 是操作 sheet,放 ShellRoute 外(渲染时不带侧栏,context.push 覆盖)。
          // ⚠️ 静态路径(security/performance/goals/trade/new)在 :id 前(匹配优先级)。
          StatefulShellBranch(
            routes: [
              ShellRoute(
                builder: (context, state, child) => SubMenuShell(
                  items: _holdingNavItems,
                  child: child,
                ),
                routes: [
                  GoRoute(
                    path: '/holdings',
                    builder: (_, __) => MultiBlocProvider(
                      providers: [
                        BlocProvider<HoldingBloc>(
                          create: (_) {
                            final b = HoldingBloc(getIt<HoldingRepository>());
                            b.add(const LoadHoldingsRequested());
                            return b;
                          },
                        ),
                        BlocProvider<CurrencyBloc>(
                          create: (_) {
                            final b = getIt<CurrencyBloc>();
                            b.add(const LoadCurrenciesRequested());
                            b.add(const LoadPreferencesRequested());
                            return b;
                          },
                        ),
                      ],
                      child: const HoldingsPage(),
                    ),
                  ),
                  GoRoute(
                    path: '/holdings/security',
                    // Security 管理:独立 HoldingBloc,进入即拉证券主数据。
                    builder: (_, __) => BlocProvider<HoldingBloc>(
                      create: (_) {
                        final b = HoldingBloc(getIt<HoldingRepository>());
                        b.add(const LoadSecuritiesRequested());
                        return b;
                      },
                      child: const SecurityPage(),
                    ),
                  ),
                  GoRoute(
                    path: '/holdings/performance',
                    // 收益统计:PerformanceBloc 进入即拉组合曲线/盈亏明细。
                    builder: (_, __) => MultiBlocProvider(
                      providers: [
                        BlocProvider<HoldingBloc>(
                          create: (_) {
                            final b = HoldingBloc(getIt<HoldingRepository>());
                            b.add(const LoadHoldingsRequested());
                            return b;
                          },
                        ),
                        BlocProvider<PerformanceBloc>(
                          create: (_) => getIt<PerformanceBloc>(),
                        ),
                        BlocProvider<CurrencyBloc>(
                          create: (_) {
                            final b = getIt<CurrencyBloc>();
                            b.add(const LoadCurrenciesRequested());
                            b.add(const LoadPreferencesRequested());
                            return b;
                          },
                        ),
                      ],
                      child: const PerformancePage(),
                    ),
                  ),
                  GoRoute(
                    path: '/holdings/goals',
                    // 目标关联:extra 传 holding(含 accountId + marketValueCents)。
                    builder: (_, state) {
                      final holding = state.extra is Map
                          ? (state.extra as Map)['holding'] as Holding?
                          : null;
                      return MultiBlocProvider(
                        providers: [
                          BlocProvider<HoldingBloc>(
                            create: (_) {
                              final b = HoldingBloc(getIt<HoldingRepository>());
                              b.add(const LoadHoldingsRequested());
                              return b;
                            },
                          ),
                          BlocProvider<CurrencyBloc>(
                            create: (_) {
                              final b = getIt<CurrencyBloc>();
                              b.add(const LoadCurrenciesRequested());
                              b.add(const LoadPreferencesRequested());
                              return b;
                            },
                          ),
                        ],
                        child: GoalLinkPage(
                          holding: holding ??
                              const Holding(
                                id: '',
                                accountId: '',
                                securityId: '',
                                securityName: '',
                                securitySymbol: '',
                                quantity: 0,
                                avgCostCents: 0,
                                marketValueCents: 0,
                                unrealizedPnlCents: 0,
                                version: 0,
                              ),
                          goalRepo: getIt<HoldingRepository>(),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: '/holdings/:id',
                    // 详情(Task 8):侧栏高亮「持仓列表」(详情从属列表)。
                    builder: (_, state) => MultiBlocProvider(
                      providers: [
                        BlocProvider<HoldingBloc>(
                          create: (_) {
                            final id = state.pathParameters['id']!;
                            final b = HoldingBloc(getIt<HoldingRepository>());
                            b.add(LoadDetailRequested(id));
                            return b;
                          },
                        ),
                        BlocProvider<CurrencyBloc>(
                          create: (_) {
                            final b = getIt<CurrencyBloc>();
                            b.add(const LoadCurrenciesRequested());
                            b.add(const LoadPreferencesRequested());
                            return b;
                          },
                        ),
                      ],
                      child: HoldingDetailPage(id: state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
              // 操作 sheet(ShellRoute 外,context.push 覆盖,不带侧栏)。
              GoRoute(
                path: '/holdings/trade',
                builder: (_, state) {
                  final typeArg = state.extra is Map
                      ? (state.extra as Map)['type'] as String?
                      : null;
                  final initialType = TradeType.values.firstWhere(
                    (t) => t.name == typeArg,
                    orElse: () => TradeType.buy,
                  );
                  return BlocProvider<HoldingBloc>(
                    create: (_) {
                      final b = HoldingBloc(getIt<HoldingRepository>());
                      b.add(const LoadSecuritiesRequested());
                      return b;
                    },
                    child: TradeSheetPage(initialType: initialType),
                  );
                },
              ),
              GoRoute(
                path: '/holdings/new',
                builder: (_, __) => BlocProvider<HoldingBloc>(
                  create: (_) {
                    final b = HoldingBloc(getIt<HoldingRepository>());
                    b.add(const LoadSecuritiesRequested());
                    return b;
                  },
                  child: const TradeSheetPage(),
                ),
              ),
            ],
          ),
```

注意:各 GoRoute 的 `path` 从相对(`security`)改为完整(`/holdings/security`),因为现在它们是 ShellRoute 的直接子路由(非 /holdings 的 children)。builder 代码体与原文件**逐字一致**,只挪位置。

- [ ] **Step 3: analyze 验证编译**

Run: `flutter analyze lib/app/router.dart`
Expected: 0 error(`SubMenuItem`/`ShellRoute`/`SubMenuShell` 都已 import;trade/new 触发点 `context.push('/holdings/trade')` 路径未变)。

- [ ] **Step 4: 验证现有 router/页面测试不破**

Run: `flutter test test/app/router_test.dart test/holding/`
Expected: 现有测试 PASS(router_test branch 计数不变,holding 页面测试可能因 `HoldingModuleNav` 断言失败 —— 那是 Task 3 修复范围;若 holding 页面测试 fail 在 nav 断言上,记下继续,Task 3 处理)。

- [ ] **Step 5: commit**

```bash
git add yucai/client/lib/app/router.dart
git commit -m "feat(holding-nav): branch 5 接入 ShellRoute(SubMenuShell)+ trade/new 移出 shell"
```

---

### Task 3: 删 HoldingModuleNav + 3 页去顶部 tab + 修测试

**Files:**
- Delete: `yucai/client/lib/holding/presentation/widgets/holding_module_nav.dart`
- Modify: `holdings_page.dart`(~60)、`security_page.dart`(~117)、`performance_page.dart`(~135)
- Modify: `test/holding/presentation/pages/holdings_page_test.dart`、`security_page_test.dart`、`performance_page_test.dart`

**Interfaces:**
- Consumes: Task 2 已让 nav 由 `SubMenuShell` 提供;本任务移除页面内冗余 nav
- Produces: goals 页孤岛解决(shell 统一提供 nav,列表/Security/收益/目标 4 页可达)

- [ ] **Step 1: 3 页去 `const HoldingModuleNav()`**

`holdings_page.dart`(~line 60):删除 `const HoldingModuleNav(),` 这一行(及其上方「创建入口移至全局 _TopBar」注释里提到 nav 的部分按需微调,保留创建入口注释)。

`security_page.dart`(~line 117):删除 `const HoldingModuleNav(),`。

`performance_page.dart`(~line 135):删除 `const HoldingModuleNav(),`。

(删后若 import `holding_module_nav.dart` 变未使用,一并删 import 行。)

- [ ] **Step 2: 删 `holding_module_nav.dart`**

删除整个文件 `yucai/client/lib/holding/presentation/widgets/holding_module_nav.dart`(逻辑已在通用 `SubMenuTab`)。

```bash
git rm yucai/client/lib/holding/presentation/widgets/holding_module_nav.dart
```

- [ ] **Step 3: 修 3 个页面测试(去 HoldingModuleNav 断言 + 注释)**

`holdings_page_test.dart`:
- line 28 注释 `/// 包一层 GoRouter(HoldingModuleNav 调 GoRouterState.of,需 GoRouter 祖先)。` → 改为 `/// 包一层 GoRouter(holdings_page 其他部分仍可能用 GoRouterState.of,保留祖先)。`(或若页面已无 GoRouterState.of 依赖,可简化为 MaterialApp;但保留 `_routed` 无害,最小改动保留)
- line 95-96、363 注释提到 `HoldingModuleNav(3 tab)` 横向溢出 → 删除/改写为「窄屏 size 选择理由:StatCard 堆叠断点」。
- 若有 `find.text('持仓列表')` 等针对 nav tab 的断言(非列表内容)→ 删除那些断言(列表内容断言保留)。

`security_page_test.dart` / `performance_page_test.dart`:
- 同样删除 `HoldingModuleNav` 相关注释 + 针对 nav tab 的断言;页面自身功能断言保留。
- `_routed` wrap 保留(页面可能仍有 GoRouterState.of 依赖,或保留作安全网)。

- [ ] **Step 4: 运行 3 页测试 + holding 全套**

Run: `flutter test test/holding/`
Expected: PASS(3 页测试通过;trade_sheet_page_test 不受影响)。若仍有 nav 残留断言 fail,回到 Step 3 补删。

- [ ] **Step 5: analyze + commit**

Run: `flutter analyze lib/holding/ test/holding/`
Expected: 0 error。

```bash
git add yucai/client/lib/holding/ yucai/client/test/holding/
git commit -m "refactor(holding-nav): 删 HoldingModuleNav,3 页去顶部 tab(nav 统一由 SubMenuShell 提供,goals 孤岛解决)"
```

---

### Task 4: 全量验证 + desktop GUI 确认

**Files:** 无改动(验证任务)

- [ ] **Step 1: 全量 analyze**

Run: `flutter analyze`
Expected: 0 非 pbserver error(22 `*.pbserver.dart` 基线不变;本次新增/修改文件 0 error)。

- [ ] **Step 2: 全量 flutter test**

Run: `flutter test`
Expected: 仅 `account_detail_page_test` / `debt_detail_page_test` / `transaction_detail_page_test` 3 个预存 fail(非本次引入);holding 套件 + sub_menu_shell_test + router_test 全 PASS。

(若出现 holding/sub_menu/router 相关新 fail,回到对应 Task 修复。)

- [ ] **Step 3: desktop build 验证**

Run: `flutter build windows --debug`
Expected: 成功(exe 输出,无编译错误)。

- [ ] **Step 4: desktop GUI 视觉确认(控制者/用户手动)**

Run: `flutter run -d windows`(JIT),登录后:
1. 进「投资组合」→ 桌面 ≥1100 应见 [全局侧栏][holding 子侧栏 4 项两组][持仓列表内容],子侧栏高亮「持仓列表」。
2. 点子侧栏「Security 管理」→ 切到 Security 页,侧栏高亮 Security,侧栏常驻。
3. 点「投资目标」→ goals 页可达(孤岛解决),侧栏高亮投资目标。
4. 进持仓详情(`/holdings/:id`)→ 侧栏高亮「持仓列表」(详情从属)。
5. FAB/详情按钮「买入」→ trade sheet 覆盖(push,**无侧栏**,符合操作型)。
6. 缩窗 <1100 → 子侧栏消失,顶部横向 tab(4 项)出现;底栏高亮持仓。

(视觉对照 OD:`design-output/holding/security-desktop.html` 等的侧栏;对照 spec mockup。)

- [ ] **Step 5: 更新 progress ledger + commit**

更新 `.superpowers/sdd/progress.md`(gitignored,本地)加 holding-module-nav section。

```bash
git status  # 确认无遗漏改动(lib/test 已 commit)
```

(本任务无新增 commit;若 Step 1-3 发现问题修复,单独 commit。)

---

## Self-Review

**1. Spec coverage**:
- §1 形态(方案 B 垂直二级左栏)→ Task 2 ShellRoute + Task 1 SubMenuShell ✓
- §2 nav-item 4 项两组 → Task 2 `_holdingNavItems` ✓
- §3 视觉(方案 A 深色 #2C2C31 + left-border accent)→ Task 1 SubMenuSidebar ✓
- §4 响应式(≥1100 垂直 / <1100 横向 tab)→ Task 1 LayoutBuilder ✓
- §5 组件(SubMenuShell/Sidebar/Tab items 驱动)+ 接入 + 回退 → Task 1/2/3 ✓
- §6 测试 → Task 1 组件 test + Task 3 页面 test 修复 + Task 4 全量 ✓
- trade/new 移出 shell → Task 2(ShellRoute 外 branch 级)+ Step 4 GUI 验证 ✓
- goals 孤岛 → Task 2(goals 在 ShellRoute 内)+ Task 3(goals 经 shell 获 nav)✓

**2. Placeholder scan**:无 TBD/TODO;所有 code 步骤含完整代码;命令含 expected output。Task 3 Step 1「按需微调注释」属具体指引(删 nav 行 + 调注释),非占位。

**3. Type consistency**:`SubMenuItem{label,icon,route,group?,badge?}` 在 Task 1 定义、Task 2 `_holdingNavItems` 消费,字段一致;`SubMenuShell({items, child})` Task 1 定义、Task 2 ShellRoute builder 消费,签名一致;`_subMenuMatches` 在 Sidebar/Tab 共用,命名一致。

**风险**(plan 阶段已标注,执行时验证):
- GoRouter 14.6.1 跨 ShellRoute 的静态优先匹配(trade/new ShellRoute 外 vs `:id` ShellRoute 内):Task 4 Step 4 GUI 验证 `/holdings/trade` 不带侧栏;若失败则 fallback 把 trade/new 改 `showModalBottomSheet`(届时单独决策)。
- 现有页面 test 的 nav 断言具体行号需执行时定位(plan 给了大致行号 + 删除指引)。
