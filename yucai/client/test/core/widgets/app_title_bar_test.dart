// TDD RED → GREEN:F29 自定义标题栏 AppTitleBar 的 widget 单测。
//
// channel mock 范式照 test/core/notifications/tray_controller_test.dart
// (window_manager MethodChannel 记录调用;is* 查询型返 bool 适配 ——
// isMaximized 按用例可拨,以覆盖 toggle 两分支)。窗口事件
// (maximize/unmaximize)照仓内先例直调注册 listener 的 onWindowEvent
// (channel→listener 派发归插件自身,此处只验本组件接线)。
//
// 覆盖映射(spec FR-2/3/4,design ADR-3/4):
// - FR-2:渲染(「御」徽标/「御财」/三钮/高 38)+ 拖拽 startDragging +
//   双击 toggle 最大化;
// - FR-3:三钮 channel 语义(minimize / isMaximized 两分支 / close ——
//   close 触发的关闭决策树归 F22 既有测试,此处只验调用);
// - ADR-3:maximize 图标态由 onWindowEvent 驱动(□↔❐);
// - FR-4/ADR-4:双主题探针 —— 底色=sidebarBg 令牌、关闭钮 hover=negative
//   派生、普通钮 hover=fg 派生(禁裸 hex)。
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/core/widgets/app_title_bar.dart';

/// window_manager channel 调用记录(照 tray_controller_test._ChannelLog)。
class _ChannelLog {
  final calls = <String>[];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ChannelLog windowLog;
  late bool isMaximizedResult;

  setUp(() {
    windowLog = _ChannelLog();
    isMaximizedResult = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (call) async {
        windowLog.calls.add(call.method);
        // 查询型方法(is* 系列)需 bool 返回,null 会使插件内部 cast 抛错
        // (tray_controller_test 同款适配);isMaximized 按用例拨开关。
        if (call.method == 'isMaximized') return isMaximizedResult;
        return call.method.startsWith('is') ? false : null;
      },
    );
    addTearDown(() => messenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'), null));
  });

  // 与生产接入同构:MaterialApp builder 层包 Column[AppTitleBar, child]
  // (app.dart,ADR-2)。
  Widget harness({ThemeData? theme}) => MaterialApp(
        theme: theme ?? AppTheme.light(),
        builder: (context, child) => Column(
          children: [const AppTitleBar(), Expanded(child: child!)],
        ),
        home: const Scaffold(),
      );

  /// 窗口事件注入:直调 window_manager 已注册 listener(仓内先例:
  /// tray_controller_test 用 controller.onWindowEvent('show'))。
  void sendWindowEvent(String name) {
    for (final listener in windowManager.listeners) {
      listener.onWindowEvent(name);
    }
  }

  /// [of] 祖先链上带指定底色的 Container(令牌/交互态探针断言面)。
  Finder ancestorContainerWithColor(Finder of, Color color) => find.ancestor(
        of: of,
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == color),
      );

  group('渲染(FR-2)', () {
    testWidgets('「御」徽标 +「御财」字样 + 三窗钮,高 38', (tester) async {
      await tester.pumpWidget(harness());

      expect(find.text('御'), findsOneWidget); // 徽标字形(F23 同源)
      expect(find.text('御财'), findsOneWidget);
      expect(find.byIcon(LucideIcons.minus), findsOneWidget);
      expect(find.byIcon(LucideIcons.square), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsOneWidget);
      expect(tester.getSize(find.byType(AppTitleBar)).height, 38);
    });

    testWidgets('卸载后注销 WindowListener(单例不残留跨用例)', (tester) async {
      await tester.pumpWidget(harness());
      expect(windowManager.hasListeners, isTrue);

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      expect(windowManager.hasListeners, isFalse);
    });
  });

  group('三钮语义(FR-3,channel mock)', () {
    testWidgets('最小化钮 → minimize', (tester) async {
      await tester.pumpWidget(harness());

      await tester.tap(find.byIcon(LucideIcons.minus));
      await tester.pump();

      expect(windowLog.calls, contains('minimize'));
      expect(windowLog.calls, isNot(contains('maximize')));
      expect(windowLog.calls, isNot(contains('close')));
    });

    testWidgets('最大化钮:isMaximized=false → maximize(未最大化)', (tester) async {
      await tester.pumpWidget(harness());

      await tester.tap(find.byIcon(LucideIcons.square));
      await tester.pump();

      expect(windowLog.calls, containsAllInOrder(['isMaximized', 'maximize']));
      expect(windowLog.calls, isNot(contains('unmaximize')));
    });

    testWidgets('最大化钮:isMaximized=true → unmaximize(已最大化)', (tester) async {
      isMaximizedResult = true;
      await tester.pumpWidget(harness());

      await tester.tap(find.byIcon(LucideIcons.square));
      await tester.pump();

      expect(windowLog.calls, containsAllInOrder(['isMaximized', 'unmaximize']));
      expect(windowLog.calls, isNot(contains('maximize')));
    });

    testWidgets('关闭钮 → close(决策树归 F22 既有测试,此处只验调用)', (tester) async {
      await tester.pumpWidget(harness());

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pump();

      expect(windowLog.calls, contains('close'));
    });
  });

  group('拖拽/双击(FR-2)', () {
    /// 拖拽区带 onDoubleTap:交互后 300ms 判定 timer 尚挂着,测试结束前
    /// 泵过 kDoubleTapTimeout 冲掉(否则 AutomatedTestWidgetsFlutterBinding
    /// timersPending 断言炸;经最小复现验证,与组件逻辑无关)。
    Future<void> flushDoubleTapTimer(WidgetTester tester) =>
        tester.pump(const Duration(milliseconds: 500));

    testWidgets('标题栏拖动 → startDragging', (tester) async {
      await tester.pumpWidget(harness());

      await tester.drag(find.text('御财'), const Offset(30, 0));
      await tester.pump();

      expect(windowLog.calls, contains('startDragging'));
      await flushDoubleTapTimer(tester);
    });

    testWidgets('双击标题栏空白区 → toggle maximize(isMaximized=false 分支)',
        (tester) async {
      await tester.pumpWidget(harness());

      // 双击 = 两 tap 间隔落在 kDoubleTapMinTime..kDoubleTapTimeout 内。
      await tester.tap(find.text('御财'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('御财'));
      await tester.pump();

      expect(windowLog.calls, containsAllInOrder(['isMaximized', 'maximize']));
      await flushDoubleTapTimer(tester);
    });

    testWidgets('双击已最大化窗口 → unmaximize(isMaximized=true 分支)',
        (tester) async {
      isMaximizedResult = true;
      await tester.pumpWidget(harness());

      await tester.tap(find.text('御财'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('御财'));
      await tester.pump();

      expect(windowLog.calls, containsAllInOrder(['isMaximized', 'unmaximize']));
      await flushDoubleTapTimer(tester);
    });
  });

  group('maximize 图标态(FR-3/ADR-3:窗口事件驱动)', () {
    testWidgets('maximize/unmaximize 事件切换 □ ↔ ❐', (tester) async {
      await tester.pumpWidget(harness());

      // 初始未最大化 → □(最大化)。
      expect(find.byIcon(LucideIcons.square), findsOneWidget);
      expect(find.byIcon(LucideIcons.copy), findsNothing);

      sendWindowEvent('maximize');
      await tester.pump();
      // 已最大化 → ❐(还原)。
      expect(find.byIcon(LucideIcons.copy), findsOneWidget);
      expect(find.byIcon(LucideIcons.square), findsNothing);

      sendWindowEvent('unmaximize');
      await tester.pump();
      expect(find.byIcon(LucideIcons.square), findsOneWidget);
      expect(find.byIcon(LucideIcons.copy), findsNothing);
    });
  });

  group('双主题探针(FR-4/ADR-4:语义派生,禁裸 hex)', () {
    testWidgets('暗色:标题栏底色 = sidebarBg 令牌(侧栏同口径)', (tester) async {
      await tester.pumpWidget(harness(theme: AppTheme.dark()));

      expect(
        ancestorContainerWithColor(
            find.text('御财'), YucaiTheme.dark().sidebarBg),
        findsOneWidget,
      );
    });

    testWidgets('亮色:标题栏底色 = sidebarBg 令牌(侧栏同口径)', (tester) async {
      await tester.pumpWidget(harness(theme: AppTheme.light()));

      expect(
        ancestorContainerWithColor(
            find.text('御财'), YucaiTheme.light().sidebarBg),
        findsOneWidget,
      );
    });

    testWidgets('关闭钮 hover = negative@10%;普通钮 hover = fg@6%(按下 fg@12% '
        '同派生面)', (tester) async {
      final t = YucaiTheme.dark();
      await tester.pumpWidget(harness(theme: AppTheme.dark()));

      final close = find.byIcon(LucideIcons.x);
      final minimize = find.byIcon(LucideIcons.minus);
      // 未 hover:透明底。
      expect(ancestorContainerWithColor(close, Colors.transparent),
          findsOneWidget);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(close));
      await tester.pump();

      // 行业惯例红警示(F25 数据头 soft 同口径)。
      expect(
        ancestorContainerWithColor(close, t.negative.withValues(alpha: 0.10)),
        findsOneWidget,
      );

      await gesture.moveTo(tester.getCenter(minimize));
      await tester.pump();
      expect(
        ancestorContainerWithColor(minimize, t.fg.withValues(alpha: 0.06)),
        findsOneWidget,
      );
    });
  });
}
