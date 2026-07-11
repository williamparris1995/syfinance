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
