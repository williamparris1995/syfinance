import 'dart:async' show unawaited;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/app/nav_settings.dart';
import 'package:yucai_client/app/widgets/command_palette.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/binding/presentation/bloc/sync_coordinator_bloc.dart';
import 'package:yucai_client/binding/presentation/widgets/sync_status_badge.dart';
import 'package:yucai_client/core/connectivity/connectivity_gateway.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/feedback/feedback_launcher.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// Branch 元数据:面包屑(section › page)+ list 页创建按钮(label + route)。
/// [_TopBar] 按 branchIndex 取 meta,按 location 区分 list(显创建按钮)vs
/// detail/form/new/edit(不显)。对齐 OD .topbar(面包屑 .crumbs + 创建 .btn-primary)。
///
/// [location] 参与 meta 解析:branch 子路由的面包屑可能偏离 branch 元数据
/// (如 /accounts/templates 在 accounts branch,但入口在侧栏「交易」组,
/// 面包屑须显「交易 › 订阅管理」,否则残留上一模块的「财务 › 账户管理」)。
({String section, String page, String rootPath, String? createLabel, String? createRoute})
    _branchMetaOf(int index, String location) {
  if (_isSubscriptionManagement(location)) {
    // v6:右侧创建按钮与其他列表页同款(shell topbar);新建订阅落到
    // 模板页的「新建模板」表单(订阅 = 周期支出模板)。
    return (section: '交易', page: '订阅管理', rootPath: '/accounts/subscriptions', createLabel: '新建订阅', createRoute: '/accounts/templates');
  }
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
    case 9:
      // 提醒中心 / 收件箱(2026-09 到期常显提醒 T4):无侧栏/底栏入口
      // (spec FR-7 入口唯二 = 聚合条「查看全部」+ 托盘),仅面包屑按
      // branch 元数据呈现;section 空 → 单级面包屑(对齐仪表盘先例)。
      return (section: '', page: '提醒中心', rootPath: '/inbox', createLabel: null, createRoute: null);
    case 10:
      // 报表分析 branch(branch 10 = /reports 索引页 + /reports/full 子路由,
      // 本票两页并入同一 branch):location 区分两级面包屑 —— 索引页单级
      // 「报表分析」(section 空,对齐仪表盘/提醒中心先例),财务报告页
      // 两级「报表分析 › 财务报告」(F43 FR-1,原型 v9 .crumb 同串)。
      // 列表页创建按钮语义不适用(rootPath 仅为 create 按钮的显隐判定,
      // 无按钮)。
      if (location.startsWith('/reports/full')) {
        return (section: '报表分析', page: '财务报告', rootPath: '/reports/full', createLabel: null, createRoute: null);
      }
      return (section: '', page: '报表分析', rootPath: '/reports', createLabel: null, createRoute: null);
    default:
      return (section: '', page: '御财', rootPath: '/', createLabel: null, createRoute: null);
  }
}

/// receivable detail(/receivables/:id,非 new/edit)用专属 topbar,全局 _TopBar 隐藏。
bool _isReceivableDetail(String location) {
  if (!location.startsWith('/receivables/')) return false;
  final segs = location.split('/');
  if (segs.length != 3) return false; // /receivables/:id(2 段后)
  final last = segs[2];
  return last != 'new' && last != 'edit';
}

/// 分类管理页(/categories)用专属 OD 风格 topbar(crumb + h1 + sub + 导入模板 +
/// 新建分类),全局 _TopBar 隐藏 —— 与 receivable detail 同模式。分类管理位于
/// transactions branch 内,但 branch 元数据为「交易管理」,面包屑会失真;且 OD
/// topbar 富含操作按钮(导入模板/新建),非 shell topbar 可表达。
bool _isCategoryManagement(String location) => location == '/categories';

/// 订阅管理页(/accounts/templates):accounts branch 子路由,与 /categories
/// 同为 branch 内自定义路由,但页面自带 header 只是「周期模板」+ 返回的轻条,
/// 全局 _TopBar 保留(离线/同步徽章与顶栏搜索不丢)—— 面包屑按 location
/// 覆盖 branch 元数据(见 _branchMetaOf),否则顶部残留「财务 › 账户管理」。
bool _isSubscriptionManagement(String location) =>
    location == '/accounts/templates' ||
    location.startsWith('/accounts/templates/') ||
    location == '/accounts/subscriptions' ||
    location.startsWith('/accounts/subscriptions/');

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
    // receivable detail / 分类管理 用专属 topbar,隐藏全局 _TopBar。
    final hideTopBar = _isReceivableDetail(location) || _isCategoryManagement(location);
    // v2 主题语义令牌(R8 F1):亮=晨白 / 暗=墨鎏金。
    final t = context.yucai;

    final shell = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1100) {
          return Scaffold(
            backgroundColor: t.bg,
            body: Row(
              children: [
                _Sidebar(
                  currentIndex: navigationShell.currentIndex,
                  userName: userName,
                  onSelect: (i) => navigationShell.goBranch(i,
                      initialLocation: i == navigationShell.currentIndex),
                  // F42: the shared entry now opens the FeedbackFormDialog (dual
                  // bottom-nav destination and the settings row.
                  onFeedback: () => FeedbackEntry.launch(context),
                  onLogout: () =>
                      context.read<AuthBloc>().add(LogoutRequested()),
                ),
                VerticalDivider(width: 1, color: t.border),
                Expanded(
                  child: Column(
                    children: [
                      // Startup integrity banner (R6 F): null = hidden.
                      // Guarded getIt: test harnesses mount AppShell without
                      // the full DI graph.
                      getIt.isRegistered<ValueNotifier<String?>>()
                          ? ValueListenableBuilder<String?>(
                              valueListenable:
                                  getIt<ValueNotifier<String?>>(),
                              builder: (context, message, _) => message == null
                                  ? const SizedBox.shrink()
                                  : IntegrityBanner(message: message),
                            )
                          : const SizedBox.shrink(),
                      if (!hideTopBar)
                        _TopBar(
                          branchIndex: navigationShell.currentIndex,
                          location: location,
                        ),
                      if (!hideTopBar)
                        Divider(height: 1, color: t.border),
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
          backgroundColor: t.bg,
          appBar: hideTopBar
              ? null
              : PreferredSize(
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
            // F42 feedback entry (8th destination, not a branch slot) → form dialog.
            onFeedback: () => FeedbackEntry.launch(context),
            onLogout: () =>
                context.read<AuthBloc>().add(LogoutRequested()),
          ),
        );
      },
    );

    // F12 T2:为顶栏 SyncStatusBadge 提供 SyncCoordinatorBloc —— 这是 F10 注册
    // lazySingleton 以来的**首个生产 resolve 点**,且为条件注入(仅绑定会话,
    // review 观察 B 根治):guest 会话不 resolve 不构造,恢复 T1「构造即
    // bound」前提;登录后 shell 随 AuthBloc 发射重建(顶部 context.watch
    // 驱动,tracker 旗标已由 AuthBloc 处理器同步先置位)→ 此时注入 → 构造期
    // 补扫(F12 T1,spec FR-3)随首个绑定帧生效。边界:lazySingleton 全程
    // 同例 —— 登出回 guest 再登录,注入的是已构造实例,不再补扫;该路径由
    // T1 惰性重订(_onTriggered 顶部 _ensurePendingWatch)覆盖,回网边沿/
    // 手动重试自然收敛。guest 期万一被构造(测试直构等)亦不订阅计数流、
    // 不补扫 —— onlineStream 订阅无条件建立,guest 下事件到达即被
    // _onTriggered 顶部的 guest 检查丢弃(review 观察 A 消歧)。
    // Provider 形态照 app.dart AuthBloc 先例(非路由 bloc:上层
    // BlocProvider.value + 消费侧 context 定位);两守卫各护一轴(review
    // 观察 C 的准确表述):
    // - 此处守 bloc 轴 —— isRegistered 只探注册不构造,未注册(测试挂
    //   AppShell 无 DI 图)不 resolve 不包 provider;
    // - badge 守 tracker 轴 —— tracker 未注册/guest 在 BlocBuilder 之前
    //   shrink,不进 bloc 查找。
    // 生产 DI 两注册恒成对(injection.dart 1e/1h 于 UI 前完成),本仓全部
    // 挂载形态下「tracker 绑定 ⇒ provider 存在」不变式成立。
    final syncTracker = getIt.isRegistered<SessionModeTracker>()
        ? getIt<SessionModeTracker>()
        : null;
    final wrapped = (syncTracker != null &&
            !syncTracker.isGuest &&
            getIt.isRegistered<SyncCoordinatorBloc>())
        ? BlocProvider<SyncCoordinatorBloc>.value(
            value: getIt<SyncCoordinatorBloc>(),
            child: shell,
          )
        : shell;
    // ⑨ 导航增强 B:Ctrl+K 全局命令面板挂载(Shortcuts/Actions + 遮罩
    // Stack),包裹整个 shell(宽/窄两形态均可唤起)。
    return _ShellCommandSurface(child: wrapped);
  }

  // branch 元数据(面包屑 section › page + list 页创建按钮)见顶层 _branchMetaOf。
}

/// ⑨ 导航增强 B:shell 级命令面板面(机制取舍见任务书 B1:Flutter 内建
/// Shortcuts/Actions 优先于 window_manager 键盘钩子 —— 路由/焦点链内即可
/// 达,免平台通道)。Ctrl+K(Win/Linux)与 Cmd+K(mac 等价键)挂同一
/// intent;开面板态再触发 = 关闭(原型 toggle)。[Focus] autofocus 兜底
/// 启动零焦点期(无焦点时键事件自根 scope 起泡不经子树;持有焦点后事件
/// 自本节点向上可达 Shortcuts,页面控件聚焦时本节点为其祖先,链路同通)。
class _ShellCommandSurface extends StatefulWidget {
  const _ShellCommandSurface({required this.child});

  final Widget child;

  @override
  State<_ShellCommandSurface> createState() => _ShellCommandSurfaceState();
}

class _ShellCommandSurfaceState extends State<_ShellCommandSurface> {
  bool _paletteOpen = false;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            OpenCommandPaletteIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            OpenCommandPaletteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          OpenCommandPaletteIntent:
              CallbackAction<OpenCommandPaletteIntent>(
            onInvoke: (_) {
              setState(() => _paletteOpen = !_paletteOpen);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: widget.child),
              if (_paletteOpen)
                Positioned.fill(
                  child: CommandPalette(
                    onClose: () => setState(() => _paletteOpen = false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
    _NavItem('仪表盘', LucideIcons.layoutDashboard, 0),
  ]),
  _NavGroup('资产', [
    _NavItem('账户管理', LucideIcons.wallet, 1),
    _NavItem('投资组合', LucideIcons.lineChart, 5, route: '/holdings'),
  ]),
  _NavGroup('交易', [
    _NavItem('交易记录', LucideIcons.receipt, 2),
    _NavItem('分类管理', LucideIcons.tags, null, route: '/categories'),
    // 订阅中心(v6):订阅管理改指订阅视图页;周期模板页在
    // /accounts/templates(订阅中心「模板管理」入口可达)。
    _NavItem('订阅管理', LucideIcons.repeat, null, route: '/accounts/subscriptions'),
  ]),
  _NavGroup('规划', [
    _NavItem('预算管理', LucideIcons.piggyBank, 6, route: '/budgets'),
    _NavItem('目标追踪', LucideIcons.target, 7, route: '/goals'),
  ]),
  _NavGroup('借贷', [
    _NavItem('债务管理', LucideIcons.landmark, 3, route: '/debts'),
    _NavItem('债权管理', LucideIcons.arrowUpRight, 4, route: '/receivables'),
  ]),
  _NavGroup('工具', [
    // branch 10 + route(本票 /reports 挂回 shell,对齐投资组合/预算管理
    // 「branchIndex + route」双字段先例):tap 走 context.go('/reports')
    // = shell 内 branch 导航;高亮走 route startsWith —— /reports/full
    // 下「报表分析」保持高亮(F43 原设计语义)。
    _NavItem('报表分析', LucideIcons.barChart, 10, route: '/reports'),
    _NavItem('设置', LucideIcons.settings, 8),
  ]),
];

/// route-only 导航项(branchIndex 为 null,自定义 route:分类管理/订阅
/// 管理等他 branch 内自定义页)声称的路径前缀下,branch 索引项不高亮
/// (route 项自身按 startsWith 高亮)—— 否则同屏双高亮:/accounts/
/// templates 在 accounts branch,「账户管理」与「订阅管理」会同时亮;
/// /categories 同理(原 /categories 特判的泛化)。注:报表分析自本票
/// 起为 branch 10 索引项(非 route-only),高亮走 route startsWith,
/// /reports* 下无双亮(branch 10 无第二个 nav 项)。
bool _claimedByRouteOnlyNav(String location) => _navGroups
    .expand((g) => g.items)
    .any((i) =>
        i.branchIndex == null &&
        i.route != null &&
        location.startsWith(i.route!)) ||
    // v6:订阅管理改指 /accounts/subscriptions,模板页 /accounts/templates
    // 仍属其下钻范围,继续让位 branch 高亮(防「账户管理」双亮)。
    _isSubscriptionManagement(location);

/// ⑨ 导航增强 A:侧栏分组可折叠 + 折叠态记忆(NavSettings 家法持久化)。
/// 记忆通道 = getIt 注入缝(guarded,照 OfflineBadge 先例):测试 stripped
/// harness 未注册 NavSettings 时退化为会话内状态(不落盘),生产恒注册
/// (injection.dart 1j + 2e load)。
class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.currentIndex,
    required this.userName,
    required this.onSelect,
    required this.onFeedback,
    required this.onLogout,
  });

  final int currentIndex;
  final String userName;
  final ValueChanged<int> onSelect;

  /// F41 feedback entry (nav list tail row, fix-2).
  final VoidCallback onFeedback;
  final VoidCallback onLogout;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  Set<String> _collapsed = {};
  NavSettings? _navSettings;

  @override
  void initState() {
    super.initState();
    if (getIt.isRegistered<NavSettings>()) {
      _navSettings = getIt<NavSettings>();
      _collapsed = Set<String>.of(_navSettings!.collapsedGroups);
    }
  }

  void _toggleGroup(String title) {
    setState(() {
      final next = Set<String>.of(_collapsed);
      if (!next.add(title)) next.remove(title);
      _collapsed = next;
    });
    // 家法通道落盘(fire-and-forget;写入集恒由现行组名构成 → 陈旧
    // 组名残留自愈)。未注册(测试)时纯会话内。
    unawaited(_navSettings?.setCollapsed(_collapsed));
  }

  /// 项选中判定(route 项:当前路径在其前缀下时高亮(非 branch index);
  /// branch 项在 route-only 项声称的路径下让位(防双高亮))—— 原 build
  /// 内联逻辑提取,分组头 hasActive(⑨A 活动组高亮)与项 tile 共用同源。
  bool _isSelected(BuildContext context, _NavItem item) {
    final location = GoRouterState.of(context).matchedLocation;
    if (item.route != null) {
      // v6:订阅管理在模板下钻页 /accounts/templates 也保持高亮
      // (同一功能的两个视图)。
      return location.startsWith(item.route!) ||
          (item.route == '/accounts/subscriptions' &&
              _isSubscriptionManagement(location));
    }
    return item.branchIndex == widget.currentIndex &&
        !_claimedByRouteOnlyNav(location);
  }

  void _onItemTap(_NavItem item) {
    if (item.route != null) {
      context.go(item.route!);
    } else if (item.branchIndex != null) {
      widget.onSelect(item.branchIndex!);
    }
  }

  /// ⑨A 常用置顶钉位:v1 硬编码三钉(仪表盘/交易记录/报表分析;拖拽自定义
  /// = backlog)—— 按标签从 [_navGroups] 查**同源** [_NavItem](名/图标/
  /// 导航语义与分组项一致,避免双源漂移),钉位不参与折叠、不显选中态
  /// (原型 v10 nav-sidebar .pin-block 形态:选中态在分组项)。
  static const _pinnedLabels = ['仪表盘', '交易记录', '报表分析'];

  List<_NavItem> _pinnedNavItems() => [
        for (final label in _pinnedLabels)
          _navGroups
              .expand((g) => g.items)
              .firstWhere((i) => i.label == label),
      ];

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Container(
      width: 240,
      color: t.sidebarBg,
      child: Column(
        children: [
          // 品牌区
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
            child: Row(children: [
              // 品牌徽标(review P2 统一):与标题栏/F23 图标同源——「御」金渐变
              // 圆角方块(此前为 gem 图标实色版,同窗双徽标口径割裂)。
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [t.accent, t.accentDeep],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text('御',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: t.onAccent,
                      )),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '御财',
                    style: TextStyle(
                      color: t.fg,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback,
                    ),
                  ),
                  Text('财务管家',
                      style: TextStyle(
                          color: t.sidebarFg.withValues(alpha: 0.8),
                          fontSize: 11)),
                ],
              ),
            ]),
          ),
          // 常用置顶区(⑨A)固定区:不随列表滚动 —— 原型 v10 明示「滚动与
          // 折叠状态下始终可见」,高频路径点击成本恒定一次;亦规避懒构建
          // ListView 深滚后置顶钉位离树(视口短于列表是 720p 常态)。
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: _PinBlock(
              items: _pinnedNavItems(),
              onItemTap: _onItemTap,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                for (final g in _navGroups)
                  _NavGroupSection(
                    group: g,
                    collapsed: _collapsed.contains(g.title),
                    hasActive: g.items.any((item) => _isSelected(context, item)),
                    isSelected: (item) => _isSelected(context, item),
                    onToggleHead: () => _toggleGroup(g.title),
                    onItemTap: _onItemTap,
                  ),
                // F41 反馈行(fix-2):导航列表尾部,随列表滚动 —— 固定区增高
                // 会把债务/债权等导航项挤出 720p 视口;入列表尾后固定区零
                // 增高,1080p+ 全列表可见即常驻。与最后一组以小顶距分隔。
                const SizedBox(height: AppSpacing.xs),
                _SidebarFeedbackRow(onTap: widget.onFeedback),
              ],
            ),
          ),
          // 用户区
          Container(
            decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: t.sidebarBorder))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: t.accentSoft,
                child: Text(
                  widget.userName.isNotEmpty
                      ? widget.userName.characters.first
                      : '财',
                  style: TextStyle(color: t.sidebarActiveFg, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.userName,
                        style: TextStyle(
                            color: t.fg,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    Text('高级会员',
                        style: TextStyle(
                            color: t.sidebarFg, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                tooltip: '退出登录',
                icon: Icon(LucideIcons.logOut,
                    color: t.sidebarFg, size: 18),
                onPressed: widget.onLogout,
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// ⑨ 导航增强 A:常用置顶区(原型 v10 .pin-block)—— 「常用」标签 +
/// 三钉(复用 [_NavItemTile] 样式语言,恒常可见、不参与折叠)+ 底部
/// 分隔线(原型为 dashed;Flutter 无内建虚线,v1 以 1px 实线近似)。
class _PinBlock extends StatelessWidget {
  const _PinBlock({required this.items, required this.onItemTap});

  final List<_NavItem> items;
  final void Function(_NavItem) onItemTap;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Text(
            '常用',
            style: TextStyle(
              color: t.sidebarFg.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        for (final item in items)
          _NavItemTile(
            item: item,
            // 钉位不承载选中态(原型形态);导航语义与分组项同源。
            selected: false,
            onTap: () => onItemTap(item),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(8, 6, 8, 2),
          height: 1,
          color: t.sidebarBorder,
        ),
      ],
    );
  }
}

/// ⑨ 导航增强 A:分组段 = 可点组头(折叠箭头 + 组内项数徽标,原型 v10
/// nav-sidebar .grp-head 形态)+ 高度动画组体(250ms ease,原型 grid-rows
/// 1fr→0fr 过渡的 Flutter 等价:ClipRect + Align heightFactor)。
/// 折叠完成(controller.value == 0)后组体换 SizedBox.shrink —— 组内项
/// **离开元素树**(不可见/不可点,find.text 亦不可达),与原型 display
/// 语义对齐且免零高 hit-test 假命中。
class _NavGroupSection extends StatefulWidget {
  const _NavGroupSection({
    required this.group,
    required this.collapsed,
    required this.hasActive,
    required this.isSelected,
    required this.onToggleHead,
    required this.onItemTap,
  });

  final _NavGroup group;
  final bool collapsed;

  /// 组内含当前项(⑨A 活动组高亮:组头标签与项数徽标以强调色点亮,
  /// 原型 .has-active 形态)。
  final bool hasActive;
  final bool Function(_NavItem) isSelected;
  final VoidCallback onToggleHead;
  final void Function(_NavItem) onItemTap;

  @override
  State<_NavGroupSection> createState() => _NavGroupSectionState();
}

class _NavGroupSectionState extends State<_NavGroupSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: widget.collapsed ? 0 : 1,
  );

  @override
  void didUpdateWidget(_NavGroupSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsed != oldWidget.collapsed) {
      widget.collapsed ? _controller.reverse() : _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupHead(
          // 态后缀 key(展开无后缀/折叠 -collapsed):测试与 e2e 断言折叠
          // 态的可观测契约(见 goPage 折叠感知适配)。
          key: ValueKey(
              'navGroupHead-${widget.group.title}${widget.collapsed ? '-collapsed' : ''}'),
          title: widget.group.title,
          count: widget.group.items.length,
          active: widget.hasActive,
          collapsed: widget.collapsed,
          onTap: widget.onToggleHead,
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.value == 0) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _controller.value,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in widget.group.items)
                      _NavItemTile(
                        item: item,
                        selected: widget.isSelected(item),
                        onTap:
                            item.branchIndex == null && item.route == null
                                ? null
                                : () => widget.onItemTap(item),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 组头行(原型 .grp-head):小标签 + [项数徽标 + 折叠箭头];hover 面色、
/// 活动组(组内含当前项)标签/徽标以 sidebarActive* 点亮。
class _GroupHead extends StatefulWidget {
  const _GroupHead({
    super.key,
    required this.title,
    required this.count,
    required this.active,
    required this.collapsed,
    required this.onTap,
  });

  final String title;
  final int count;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  State<_GroupHead> createState() => _GroupHeadState();
}

class _GroupHeadState extends State<_GroupHead> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    final fg = widget.active
        ? t.sidebarActiveFg
        : t.sidebarFg.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _hover ? t.sidebarHover : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: fg,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                // 项数徽标(原型 .cnt pill);活动组换用强调色底/字。
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: widget.active
                        ? t.sidebarActiveBg
                        : t.surfaceAlt.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: widget.active
                          ? Colors.transparent
                          : t.border,
                    ),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: TextStyle(
                      color: fg,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 折叠箭头(原型 .chev-sm):展开朝下(90°)/收起朝右(0°),
                // 220ms 旋转过渡。
                AnimatedRotation(
                  turns: widget.collapsed ? 0 : 0.25,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(LucideIcons.chevronRight,
                      size: 14, color: fg),
                ),
              ],
            ),
          ),
        ),
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
    final t = context.yucai;

    Color bg;
    if (selected) {
      bg = t.sidebarActiveBg;
    } else if (_hover && enabled) {
      bg = t.sidebarHover;
    } else {
      bg = Colors.transparent;
    }
    final fg = selected
        ? t.sidebarActiveFg
        : (enabled
            ? (_hover ? t.fg : t.sidebarFg)
            : t.sidebarFg.withValues(alpha: 0.4));
    final iconColor = selected
        ? t.sidebarActiveFg
        : (enabled
            ? (_hover ? t.fg : t.sidebarFg)
            : t.sidebarFg.withValues(alpha: 0.4));

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
                color: selected ? t.accent : Colors.transparent,
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
                  color: t.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(widget.item.badge!,
                    style: TextStyle(color: t.onAccent, fontSize: 10)),
              )
            else if (!enabled)
              Text('敬请期待',
                  style: TextStyle(
                      color: t.sidebarFg.withValues(alpha: 0.4),
                      fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── 顶栏 ─────────────────────────

/// F41 反馈行(侧栏导航列表尾部整行,fix-2):随列表滚动、与登录态无关
/// (1080p+ 常见桌面全列表可见即常驻)。视觉复用 [_NavItemTile] 样式语言
/// (leading icon + 13px label + hover 面色/圆角),但无 selected 态、无
/// badge —— 反馈不是导航目标。
class _SidebarFeedbackRow extends StatefulWidget {
  const _SidebarFeedbackRow({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SidebarFeedbackRow> createState() => _SidebarFeedbackRowState();
}

class _SidebarFeedbackRowState extends State<_SidebarFeedbackRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Padding(
      // fix-2/P-F1: no horizontal inset — the ListView itself already
      // pads horizontal 12, so the capsule aligns with the _NavItemTile
      // above (left edge 12px, not 24px). Vertical spacing kept.
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: _hover ? t.sidebarHover : Colors.transparent,
              borderRadius: AppRadius.smBorder,
            ),
            child: Row(children: [
              // P-F1b: 18px matches _NavItemTile's icon — adjacent rows
              // must not differ in icon size.
              Icon(LucideIcons.messageSquareHeart,
                  size: 18, color: _hover ? t.fg : t.sidebarFg),
              const SizedBox(width: 10),
              Expanded(
                child: Text('意见反馈',
                    style: TextStyle(
                        color: _hover ? t.fg : t.sidebarFg,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

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
    final meta = _branchMetaOf(branchIndex, location);
    final t = context.yucai;
    // 创建按钮仅 list 页显(location == rootPath;detail/form/new/edit 不显)。
    final showCreate = meta.createLabel != null && location == meta.rootPath;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          // v2 顶栏毛玻璃屏障(暗 rgba(11,14,19,.72) / 亮 rgba(255,255,255,.82))。
          color: t.topbarBarrier,
          child: Row(children: [
            // 面包屑:section › page(对齐 OD .crumbs)。
            _BreadCrumb(section: meta.section, page: meta.page),
            // 离线指示(R6 F):connectivity 网关驱动,在线零感知。
            const OfflineBadge(),
            // 同步状态指示(F12,spec FR-1):仅绑定态渲染(guest 静默);
            // bloc 由 AppShell 顶层 BlocProvider.value 提供(见 AppShell.build)。
            const SyncStatusBadge(),
            const Spacer(),
            if (!compact)
              SizedBox(
                width: 220,
                child: TextField(
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '搜索交易、账户…',
                    isDense: true,
                    prefixIcon: Icon(LucideIcons.search,
                        size: 16, color: t.muted),
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
    final t = context.yucai;
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 20, color: t.muted),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: t.accentSoft,
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
    final t = context.yucai;
    final pageStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: t.fg,
      fontFamily: AppTypography.displayFamily,
      fontFamilyFallback: AppTypography.displayFallback,
    );
    if (section.isEmpty) {
      return Text(page, style: pageStyle);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(section, style: TextStyle(fontSize: 14, color: t.muted)),
      const SizedBox(width: 6),
      Icon(LucideIcons.chevronRight, size: 14, color: t.muted),
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
    final t = context.yucai;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push(route),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: t.accent,
            borderRadius: AppRadius.smBorder,
            boxShadow: [
              BoxShadow(
                color: t.accent.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.plus, size: 15, color: t.onAccent),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: t.onAccent,
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
    required this.onFeedback,
    required this.onLogout,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// F41 feedback entry (8th destination, right after the branch slots —
  /// not part of [_branchSlots], handled before the trailing logout).
  final VoidCallback onFeedback;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    // 底栏映射已实现的分支：仪表盘(0) / 交易(2) / 账户(1) / 债务(3) / 债权(4) /
    // 持仓(5) 六个分支索引 + 反馈(F41,非 branch) + 退出（末位）。
    final t = context.yucai;
    return NavigationBar(
      backgroundColor: t.surface,
      indicatorColor: t.accentSoft,
      selectedIndex: _slotIndexOf(currentIndex),
      onDestinationSelected: (i) {
        if (i < _branchSlots.length) {
          onSelect(_branchSlots[i]);
        } else if (i == _branchSlots.length) {
          // F41 反馈位:branch 槽之后、退出之前的固定第 7 位。
          onFeedback();
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
        // F41 反馈:icon 与宽屏侧栏同源(未选 messageSquare,选中爱心款)。
        NavigationDestination(
            icon: Icon(LucideIcons.messageSquare),
            selectedIcon: Icon(LucideIcons.messageSquareHeart),
            label: '反馈'),
        NavigationDestination(icon: Icon(LucideIcons.logOut), label: '退出'),
      ],
    );
  }

  /// 底栏位序 → 分支索引。底栏分支顺序为 仪表盘/交易/账户/债务/债权/持仓,
  /// 对应分支 0/2/1/3/4/5;反馈(F41)与退出不在此表(反馈=第 7 位,退出=末位)。
  /// 未匹配的分支（如未来新增）回退到 0。
  static const _branchSlots = [0, 2, 1, 3, 4, 5];

  static int _slotIndexOf(int branchIndex) {
    final i = _branchSlots.indexOf(branchIndex);
    return i == -1 ? 0 : i;
  }
}


/// Offline indicator chip (R6 F): subscribes to the shared ConnectivityGateway;
/// invisible while online. getIt is resolved lazily in build so tests that
/// mount AppShell without DI can pass a registered fake first.
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final gateway = getIt.isRegistered<ConnectivityGateway>()
        ? getIt<ConnectivityGateway>()
        : null;
    if (gateway == null) return const SizedBox.shrink();
    return StreamBuilder<bool>(
      stream: gateway.online,
      initialData: gateway.current,
      builder: (context, snap) {
        if (snap.data ?? true) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .extension<YucaiTheme>()!
                  .muted
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.wifiOff,
                  size: 13,
                  color: Theme.of(context).extension<YucaiTheme>()!.muted),
              const SizedBox(width: 4),
              Text('离线',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .extension<YucaiTheme>()!
                          .muted)),
            ]),
          ),
        );
      },
    );
  }
}

/// Non-intrusive banner for local-db integrity problems found at startup
/// (R6 F): display-only, never blocks.
class IntegrityBanner extends StatelessWidget {
  const IntegrityBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Material(
      color: t.negative.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Icon(LucideIcons.triangleAlert, size: 14, color: t.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text('本地数据异常:$message(建议导出存档备份)',
                style: const TextStyle(fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}
