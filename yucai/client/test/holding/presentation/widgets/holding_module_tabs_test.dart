import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_module_tabs.dart';

Widget _routed(String initial) => MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(path: '/holdings', builder: (_, __) => const Column(children: [HoldingModuleTabs(), Expanded(child: SizedBox())])),
          GoRoute(path: '/holdings/security', builder: (_, __) => const Column(children: [HoldingModuleTabs(), Expanded(child: SizedBox())])),
          GoRoute(path: '/holdings/performance', builder: (_, __) => const Column(children: [HoldingModuleTabs(), Expanded(child: SizedBox())])),
          GoRoute(path: '/holdings/goals', builder: (_, __) => const Column(children: [HoldingModuleTabs(), Expanded(child: SizedBox())])),
        ],
      ),
    );

void main() {
  testWidgets('渲染 4 个 tab', (tester) async {
    await tester.pumpWidget(_routed('/holdings'));
    expect(find.text('持仓列表'), findsOneWidget);
    expect(find.text('Security 管理'), findsOneWidget);
    expect(find.text('收益统计'), findsOneWidget);
    expect(find.text('投资目标'), findsOneWidget);
  });

  testWidgets('当前路由 tab active(金下划线)', (tester) async {
    await tester.pumpWidget(_routed('/holdings/security'));
    // active tab 文字加粗(fontWeight w600);非 active w500。
    final secText = tester.widget<Text>(find.text('Security 管理'));
    expect(secText.style?.fontWeight, FontWeight.w600);
    final listText = tester.widget<Text>(find.text('持仓列表'));
    expect(listText.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('点击 tab 触发 context.go', (tester) async {
    await tester.pumpWidget(_routed('/holdings'));
    await tester.tap(find.text('投资目标'));
    await tester.pumpAndSettle();
    expect(GoRouterState.of(tester.element(find.text('投资目标'))).matchedLocation, '/holdings/goals');
  });
}
