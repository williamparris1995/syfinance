// ⑨ 导航增强 B:命令面板(CommandPalette)组件测。
// 面板组件独立挂载于极简 GoRouter 之下(InheritedGoRouter 可达 →
// context.go 生效),路由断言直读 routerDelegate —— 不挂全 AppShell
// (Ctrl+K 全局唤起的 shell 级挂载见 app_shell_test)。
// 数据为 v1 硬编码静态清单(页面 = 路由静态表;操作 = 记一笔/生成财务
// 报告/导出报告/AI 解读),不留插件面(任务书 B4)。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:yucai_client/app/widgets/command_palette.dart';

/// 测试路由清单 = 面板目标路由全集(每路由落一页地标文本)。
const _kRoutes = [
  '/home',
  '/reports',
  '/reports/full',
  '/transactions',
  '/transactions/new',
  '/budgets',
  '/holdings',
  '/accounts',
  '/accounts/subscriptions',
  '/debts',
  '/receivables',
  '/goals',
  '/categories',
  '/settings',
];

void main() {
  late GoRouter router;
  late _PaletteHostState host;

  Future<void> pumpPalette(WidgetTester tester) async {
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => _PaletteHost(onInit: (h) => host = h),
        ),
        for (final r in _kRoutes.where((r) => r != '/home'))
          GoRoute(
            path: r,
            builder: (_, __) => Scaffold(body: Center(child: Text('route:$r'))),
          ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('挂载即显全量清单,分组「页面/操作」,搜索框 autofocus',
      (tester) async {
    // 高视口:17 行 + 组头超出 52vh(600 高)懒折叠线,1600 高全量入树。
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPalette(tester);

    expect(find.byType(CommandPalette), findsOneWidget);
    // 组头:页面 · 13 / 操作 · 4。
    expect(find.text('页面 · 13'), findsOneWidget);
    expect(find.text('操作 · 4'), findsOneWidget);
    // 抽样断言条目存在(页面 + 操作)。
    expect(find.text('财务报告'), findsOneWidget);
    expect(find.text('订阅管理'), findsOneWidget);
    expect(find.text('记一笔'), findsOneWidget);
    expect(find.text('AI 解读'), findsOneWidget);
    // 搜索框 autofocus。
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isTrue);
  });

  testWidgets('输入实时过滤(contains):「预」只剩预算管理,选择复位首项',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPalette(tester);

    await tester.enterText(find.byType(TextField), '预');
    await tester.pump();

    expect(find.text('预算管理'), findsOneWidget);
    expect(find.text('仪表盘'), findsNothing);
    expect(find.text('记一笔'), findsNothing);
    expect(find.text('页面 · 1'), findsOneWidget);
    // 过滤后选择复位到唯一结果。
    expect(_rowColor(tester, '预算管理'), isNot(equals(Colors.transparent)));
  });

  testWidgets('无匹配显示「无匹配」空态', (tester) async {
    await pumpPalette(tester);

    await tester.enterText(find.byType(TextField), '不存在的词条');
    await tester.pump();

    expect(find.text('无匹配'), findsOneWidget);
    expect(find.text('仪表盘'), findsNothing);
  });

  testWidgets('↑↓ 键盘高亮循环(末项下越回首)', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPalette(tester);

    // 初始高亮 = 首项(仪表盘)。
    expect(_rowColor(tester, '仪表盘'), isNot(equals(Colors.transparent)));

    // ↓ → 报表分析。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_rowColor(tester, '报表分析'), isNot(equals(Colors.transparent)),
        reason: '↓ 后第二项应高亮');
    expect(_rowColor(tester, '仪表盘'), equals(Colors.transparent));

    // 复位选择:输入再清空(过滤复位把 index 拉回首项)。
    await tester.enterText(find.byType(TextField), '设置');
    await tester.pump();
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    // 首项 ↑ wrap → 末项(AI 解读)。
    expect(_rowColor(tester, 'AI 解读'), isNot(equals(Colors.transparent)),
        reason: '首项 ↑ 应 wrap 到末项');
  });

  testWidgets('Enter 执行选中项:记一笔 → /transactions/new,面板关闭',
      (tester) async {
    await pumpPalette(tester);

    await tester.enterText(find.byType(TextField), '记一笔');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/transactions/new');
    expect(host.closedCount, 1, reason: '执行后面板应关闭');
  });

  testWidgets('Esc 关闭面板(onClose)', (tester) async {
    await pumpPalette(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(host.closedCount, 1);
  });

  testWidgets('操作项语境取舍(钉):生成财务报告/导出报告/AI 解读 → /reports/full',
      (tester) async {
    // 导出报告/AI 解读仅在报告页上下文有真实 handler(F45 导出为页面级
    // _export、F46 AI 为页面 _narrate;bloc/handler 均路由子树内)—— 面板
    // 层不可达,v1 统一跳报告页(原型操作组后两者 href 即财务报告页);
    // 置灰分支留 handler 提升后启用。
    await pumpPalette(tester);

    await tester.enterText(find.byType(TextField), '生成财务报告');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/reports/full');

    // 重开(宿主 onClose 已隐藏 → 复位)面板,导出报告同口径。
    host.reopen();
    await tester.pump();
    await tester.enterText(find.byType(TextField), '导出报告');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/reports/full');
  });

  testWidgets('点击行执行(指针路径与键盘路径同源)', (tester) async {
    await pumpPalette(tester);

    await tester.tap(find.text('预算管理'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
        router.routerDelegate.currentConfiguration.uri.toString(), '/budgets');
    expect(host.closedCount, 1);
  });
}

/// 读取行容器的面色(高亮 = 主题 sidebarActiveBg;未选 = transparent)。
Color? _rowColor(WidgetTester tester, String label) =>
    (tester
            .widget<Container>(find.byKey(ValueKey('paletteRow-$label')))
            .decoration as BoxDecoration?)
        ?.color;

/// 宿主:承载面板开合态 + 关闭计数;reopen 供多段测试复位。
class _PaletteHost extends StatefulWidget {
  const _PaletteHost({required this.onInit});
  final void Function(_PaletteHostState) onInit;
  @override
  State<_PaletteHost> createState() => _PaletteHostState();
}

class _PaletteHostState extends State<_PaletteHost> {
  bool _open = true;
  int closedCount = 0;

  @override
  void initState() {
    super.initState();
    widget.onInit(this);
  }

  void reopen() => setState(() => _open = true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const SizedBox.expand(),
        if (_open)
          // 遮罩需满屏约束(AppShell 生产挂载 = Stack Positioned.fill)。
          SizedBox.expand(
            child: CommandPalette(onClose: () {
              closedCount++;
              setState(() => _open = false);
            }),
          ),
      ]),
    );
  }
}
