// 反馈⑥(桌面文本体验)regression:MaterialApp.builder 层 AppChrome 的
// 全局 SelectionArea —— 展示类文本(金额/摘要/标签/报告正文)可选/可复制。
//
// 断言四件事:
// 1. 展示 Text 落在 SelectionArea 内,select-all 选区 API 真的收集到文本,
//    copySelection 真的落到剪贴板(选区存在性 + 复制链路);
// 2. 桌面右键(secondary mouse tap)弹内建 context menu,点 Copy 落剪贴板
//    (Flutter 3.44 SelectionArea 自带 adaptiveTextSelectionToolbar,无三方);
// 3. 副作用回归:按钮 tap 与 TextField 输入在全局 SelectionArea 内不受干扰
//    (TextField 不消费祖先 SelectionRegistrar,自持选择系统);
// 4. 标题栏(Windows chrome)在 SelectionArea 之外 —— 拖拽/双击手势不同场。
//
// 无 gRPC/无 DI:AppChrome 是纯布局 chrome,host = MaterialApp 即可。
// window_manager MethodChannel 需 mock:Windows 宿主上 AppTitleBar
// initState 即调 isMaximized()(非 Windows 宿主 mock 挂着无害)。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/core/widgets/app_chrome.dart';
import 'package:yucai_client/core/widgets/app_title_bar.dart';

const _amountText = '净流入 ¥12,345.67';
const _summaryText = '本月支出以住房与餐饮为主,储蓄率 31.2%';

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

/// SystemChannels.platform 剪贴板双向 mock:flutter_test 无 getClipboardData
/// 助手,自持一份内存剪贴板,setData 记录 / getData 回放。
String? _clipboardData;

void _mockClipboard(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          _clipboardData = (call.arguments as Map?)?['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return _clipboardData == null
              ? null
              : <String, Object>{'text': _clipboardData!};
      }
      return null;
    },
  );
}

String? _readClipboard() => _clipboardData;

void main() {
  testWidgets('展示文本在全局 SelectionArea 内,select-all 后选区含文本且可复制到剪贴板', (tester) async {
    _mockWindowManager(tester);
    await tester.pumpWidget(_host(const Scaffold(
      body: Center(
        child: Column(
          children: [
            Text(_amountText, key: Key('amount')),
            Text(_summaryText, key: Key('summary')),
          ],
        ),
      ),
    )));

    // 1) 全局 SelectionArea 存在,两处展示文本均落其内。
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(
      find.descendant(
          of: find.byType(SelectionArea), matching: find.text(_amountText)),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: find.byType(SelectionArea), matching: find.text(_summaryText)),
      findsOneWidget,
    );

    // 2) 选区 API 真收集到展示文本:selectAll 后选区几何存在(start/end
    //    两个端点),context menu 备选项出现 Copy(有选中内容才有 Copy)。
    final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion).first);
    region.selectAll();
    await tester.pump();
    expect(region.selectionEndpoints.length, 2);
    expect(
      region.contextMenuButtonItems
          .any((i) => i.type == ContextMenuButtonType.copy),
      isTrue,
    );

    // 3) 复制链路:走 context menu 的 Copy 按钮 onPressed(与用户点菜单
    //    同一入口;copySelection 直调已 deprecated)→ 系统剪贴板。
    _mockClipboard(tester);
    region.contextMenuButtonItems
        .firstWhere((i) => i.type == ContextMenuButtonType.copy)
        .onPressed!();
    await tester.pump();
    expect(_readClipboard(), contains('12,345.67'));
    expect(_readClipboard(), contains('储蓄率 31.2%'));
  });

  testWidgets('桌面右键弹内建 context menu,点 Copy 落剪贴板(反馈⑥核心交互)', (tester) async {
    _mockWindowManager(tester);
    _mockClipboard(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(_host(const Scaffold(
      body: Center(child: Text(_amountText, key: Key('amount'))),
    )));

    // 先有选区(selectAll),右键点在选区内 → Windows 分支保留选区并弹菜单。
    final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion).first);
    region.selectAll();
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('amount'))),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 内建 adaptive 菜单弹出,含 Copy(MaterialApp 默认英文 locale)。
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_readClipboard(), contains('12,345.67'));
    // 复位须在测试体内完成(框架在 teardown 校验 debug 全局变量未被污染)。
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('副作用回归:全局 SelectionArea 不干扰按钮 tap、图表悬停与 TextField 输入', (tester) async {
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
            // fl_chart 悬停同构体:MouseRegion onEnter(无指针按键,不进
            // 手势竞技场,与选区识别器无争用)。
            MouseRegion(
              key: const Key('chart'),
              onEnter: (_) => hovered++,
              child: const SizedBox(width: 120, height: 60),
            ),
            const Text(_summaryText),
          ],
        ),
      ),
    )));

    // 按钮 tap:内层 InkWell 的 TapGestureRecognizer 在手势竞技场先入,不被
    // 全局 SelectionArea 抢走。
    await tester.tap(find.byKey(const Key('btn')));
    await tester.pump();
    expect(tapped, 1);

    // 表单输入:TextField 自持选择系统,与祖先 SelectionArea 无涉。
    await tester.enterText(find.byKey(const Key('field')), '99.9');
    await tester.pump();
    expect(controller.text, '99.9');

    // 图表悬停:鼠标移入(MouseRegion onEnter)不受选区手势影响。
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('chart'))));
    await tester.pump();
    expect(hovered, 1);
  });

  testWidgets('标题栏(Windows chrome)在 SelectionArea 之外', (tester) async {
    _mockWindowManager(tester);
    await tester.pumpWidget(_host(
        const Scaffold(body: Center(child: Text(_amountText)))));

    if (!kIsWeb && Platform.isWindows) {
      // 标题栏存在(builder 层挂,F29),但不是 SelectionArea 子树 ——
      // 其拖拽/双击最大化手势不与文本选手势同场。
      expect(find.byType(AppTitleBar), findsOneWidget);
      expect(
        find.descendant(
            of: find.byType(SelectionArea), matching: find.byType(AppTitleBar)),
        findsNothing,
      );
    } else {
      // 非 Windows 宿主:无标题栏分支,内容仍可选。
      expect(find.byType(AppTitleBar), findsNothing);
      expect(find.byType(SelectionArea), findsOneWidget);
    }
  });
}
