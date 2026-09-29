// 反馈⑥ → 反馈1a regression:AppChrome 的契约变迁。
//
// 反馈⑥ 曾在 AppChrome(builder 层)全局包 SelectionArea;反馈1a 真机
// 实测**鼠标拖选完全无效**,诊断(2026-09-29,integration e2e + widget
// 诊断矩阵)定位根因:单一选区 scope 内并存多个可见滚动容器(侧栏
// ListView + 页面滚动 + shell 外报表页)时,选区边沿更新在
// SelectionContainer 层级间被静默丢弃 —— 手势竞技场全胜但 forEnd 派发
// 零效果(Flutter 上游开放缺陷 #153004)。修复 = scope 下沉到内容区唯一:
// - AppShell 内容区(desktop Expanded(navigationShell) / mobile body);
// - shell 外报表页(/reports,/reports/full)页身自包。
//
// 本文件钉住新契约(4 测):
// 1. builder 层**无**全局 SelectionArea(根因回归锚:它一回来拖选就全废);
// 2. chrome 不干扰内容交互(按钮 tap / TextField 输入 / MouseRegion 悬停);
// 3. Windows 标题栏在位(F29),child 透传不失;
// 4. 标题栏文本不在任何选区 scope(标题栏是 chrome,取舍同侧栏/顶栏)。
//
// 选区正向契约(拖选/右键复制)由 app_shell_test(内容区 scope,真路由
// 真手势)与 integration_test/text_selection_drag_e2e_test(真机链路)钉。
//
// 无 gRPC/无 DI:AppChrome 是纯布局 chrome,host = MaterialApp 即可。
// window_manager MethodChannel 需 mock:Windows 宿主上 AppTitleBar
// initState 即调 isMaximized()(非 Windows 宿主 mock 挂着无害)。
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/core/widgets/app_chrome.dart';
import 'package:yucai_client/core/widgets/app_title_bar.dart';

const _amountText = '净流入 ¥12,345.67';

Widget _host(Widget home) => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => AppChrome(child: child),
      home: home,
    );

void _mockWindowManager(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('window_manager'),
    (call) async {
      if (call.method == 'isMaximized') return false;
      return null;
    },
  );
}

void main() {
  testWidgets('反馈1a 根因回归锚:builder 层不再有全局 SelectionArea', (tester) async {
    _mockWindowManager(tester);
    await tester.pumpWidget(_host(const Scaffold(
      body: Center(child: Text(_amountText, key: Key('amount'))),
    )));

    // 内容在;全局 scope 不在(选区由 AppShell 内容区/报表页 scope 提供)。
    expect(find.text(_amountText), findsOneWidget);
    expect(find.byType(SelectionArea), findsNothing,
        reason: '反馈1a:全局 scope 与多滚动容器并存 = 拖选边沿更新被静默'
            '丢弃(Flutter #153004);scope 须留在内容区(AppShell/报表页)');
  });

  testWidgets('chrome 不干扰内容交互:按钮 tap、图表悬停与 TextField 输入', (tester) async {
    _mockWindowManager(tester);
    var tapped = 0;
    var hovered = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(Scaffold(
      body: Center(
        child: Column(
          children: [
            TextButton(
              onPressed: () => tapped++,
              child: const Text('跳转账户', key: Key('btn')),
            ),
            TextField(
              key: const Key('field'),
              controller: controller,
              decoration: const InputDecoration(hintText: '输入金额'),
            ),
            // fl_chart 悬停同构体:MouseRegion onEnter。
            MouseRegion(
              key: const Key('chart'),
              onEnter: (_) => hovered++,
              child: const SizedBox(width: 120, height: 60),
            ),
          ],
        ),
      ),
    )));

    await tester.tap(find.byKey(const Key('btn')));
    await tester.pump();
    expect(tapped, 1);

    await tester.enterText(find.byKey(const Key('field')), '99.9');
    await tester.pump();
    expect(controller.text, '99.9');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('chart'))));
    await tester.pump();
    expect(hovered, 1);
  });

  testWidgets('child 透传:非 SelectionArea 包裹也不吃 child(反馈1a 后 chrome 更薄)',
      (tester) async {
    _mockWindowManager(tester);
    await tester.pumpWidget(_host(const Scaffold(
      body: Center(child: Text(_amountText, key: Key('amount'))),
    )));
    expect(find.byKey(const Key('amount')), findsOneWidget);
    expect(
      find.descendant(
          of: find.byType(AppChrome), matching: find.byKey(const Key('amount'))),
      findsOneWidget,
      reason: 'builder child(整个 Navigator)仍完整落在 chrome 内',
    );
  });

  testWidgets('标题栏(Windows chrome)在位且不在任何选区 scope', (tester) async {
    _mockWindowManager(tester);
    await tester.pumpWidget(_host(
        const Scaffold(body: Center(child: Text(_amountText)))));

    if (!kIsWeb && Platform.isWindows) {
      expect(find.byType(AppTitleBar), findsOneWidget);
    } else {
      expect(find.byType(AppTitleBar), findsNothing);
    }
    // 全局 scope 已移除(反馈1a)→ 标题栏(及其一切文本)自然不在选区内。
    expect(
      find.descendant(
          of: find.byType(SelectionArea), matching: find.byType(AppTitleBar)),
      findsNothing,
    );
  });
}
