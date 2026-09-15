// F22 T3(2026-09-15):首次关闭一次性对话框单测(spec FR-3,原型
// prototype/v1/ui/first-close-dialog.html / components.md dialog-first-close)——
// - 三态返回:主按钮「最小化到托盘」→ minimize;次按钮「退出程序」→ quit;
//   barrier 点击 / Esc / 右上 × → null(取消);
// - 文案:标题「御财将最小化到系统托盘」与正文关键语义(系统托盘 /
//   到期提醒与自动记账不受影响 / 点击托盘图标恢复窗口);
// - 视觉契约:卡宽 400 / 圆角 16;
// - 主题探针:亮/暗(AppTheme)双主题渲染不抛 + surface 令牌生效
//   (照 sync_status_badge_test 的 extension 真注入范式);
// - 无副作用守门:源码无裸色 / 无 legacy AppColors / 不依赖设置仓储、
//   不写首关标记(标记写入是 T4 消费方职责)。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/settings/widgets/first_close_dialog.dart';

void main() {
  /// 挂载宿主并打开对话框;返回值经 [captured] 捕获(pop 后完成)。
  FirstCloseDialogResult? captured;
  Future<void> pumpHost(WidgetTester tester, {ThemeData? theme}) async {
    captured = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: FilledButton(
                onPressed: () async {
                  captured = await showFirstCloseDialog(ctx);
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget); // 前置:确实弹出
  }

  group('三态返回(FR-3:返回值驱动 hide/exit/取消)', () {
    testWidgets('点主按钮「最小化到托盘」→ minimize', (tester) async {
      await pumpHost(tester);
      await tester.tap(find.text('最小化到托盘'));
      await tester.pumpAndSettle();
      expect(captured, FirstCloseDialogResult.minimize);
      expect(find.byType(Dialog), findsNothing); // 弹层关闭
    });

    testWidgets('点次按钮「退出程序」→ quit', (tester) async {
      await pumpHost(tester);
      await tester.tap(find.text('退出程序'));
      await tester.pumpAndSettle();
      expect(captured, FirstCloseDialogResult.quit);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('点击 barrier → null(取消,barrierDismissible=true)', (tester) async {
      await pumpHost(tester);
      await tester.tapAt(const Offset(5, 5)); // 视口角落 = 遮罩,非卡内
      await tester.pumpAndSettle();
      expect(captured, isNull);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('按 Esc → null(取消)', (tester) async {
      await pumpHost(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(captured, isNull);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('点右上 × → null(取消)', (tester) async {
      await pumpHost(tester);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(captured, isNull);
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('文案与视觉契约(原型 first-close-dialog.html)', () {
    testWidgets('标题与正文关键语义齐全', (tester) async {
      await pumpHost(tester);
      expect(find.text('御财将最小化到系统托盘'), findsOneWidget);
      expect(find.textContaining('系统托盘'), findsAtLeast(1));
      expect(find.textContaining('到期提醒与自动记账不受影响'), findsOneWidget);
      expect(find.textContaining('点击托盘图标恢复窗口'), findsOneWidget);
      expect(find.textContaining('仅出现一次'), findsOneWidget); // kbd 提示
    });

    testWidgets('卡宽 400 / 圆角 16(dialog-first-close 规格)', (tester) async {
      await pumpHost(tester);
      // Dialog 的 renderObject 落在 route 全屏容器上,尺寸断言经 widget
      // 属性表达契约:child SizedBox 定宽 400 + shape 圆角 16。
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect((dialog.child! as SizedBox).width, 400);
      final shape = dialog.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect((shape! as RoundedRectangleBorder).borderRadius,
          AppRadius.lgBorder); // 16
    });
  });

  group('主题探针(双主题经 YucaiTheme 生效)', () {
    testWidgets('亮色(AppTheme.light)渲染不抛,surface 令牌生效', (tester) async {
      await pumpHost(tester, theme: AppTheme.light());
      expect(find.text('御财将最小化到系统托盘'), findsOneWidget);
      expect(
        tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
        YucaiTheme.light().surface,
      );
    });

    testWidgets('暗色(AppTheme.dark)渲染不抛,surface 令牌生效', (tester) async {
      await pumpHost(tester, theme: AppTheme.dark());
      expect(find.text('御财将最小化到系统托盘'), findsOneWidget);
      expect(
        tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
        YucaiTheme.dark().surface,
      );
    });
  });

  group('评审修复 R1/R2/R3(2026-09-15 review round 1)', () {
    testWidgets('R1:亮色下 barrier = 恒定暗遮罩(原型 --scrim,非 bg 派生)',
        (tester) async {
      await pumpHost(tester, theme: AppTheme.light());
      final route = ModalRoute.of(tester.element(find.byType(Dialog)))!;
      // 原型 --scrim rgba(2,6,16,.55):双主题恒定暗遮罩(亮色近白纱罩
      // 会弱化模态感,评审 R1)。
      expect(route.barrierColor, Colors.black.withValues(alpha: 0.55));
      // 防「派生式」回归:不得由主题 bg 派生。
      expect(route.barrierColor,
          isNot(YucaiTheme.light().bg.withValues(alpha: 0.55)));
    });

    testWidgets('R2:主按钮 autofocus,Enter = 默认最小化(原型默认语义)',
        (tester) async {
      await pumpHost(tester);
      // Enter 只有在主按钮持焦时才激活 —— 行为即 autofocus 探针
      // (焦点在 barrier 时 Enter 无 action,弹层不关)。
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(captured, FirstCloseDialogResult.minimize);
    });

    testWidgets('R2:autofocus 聚焦态按 Esc 仍返回 null(DismissIntent 冒泡)',
        (tester) async {
      await pumpHost(tester);
      // 实证:焦点在卡内按钮时,Esc 的 DismissIntent 仍被 route 级
      // Actions(_DismissModalAction,routes.dart)捕获 → maybePop → null。
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(captured, isNull);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('R3:次按钮 hover → negative 文字(默认态仍 muted)', (tester) async {
      await pumpHost(tester);
      final style =
          tester.widget<TextButton>(find.widgetWithText(TextButton, '退出程序'))
              .style;
      expect(style?.foregroundColor?.resolve({WidgetState.hovered}),
          YucaiTheme.light().negative); // 原型 .btn-secondary:hover --neg
      expect(style?.foregroundColor?.resolve(<WidgetState>{}),
          YucaiTheme.light().muted); // 默认 muted 文字钮
    });

    testWidgets('R3:右上 × hover → fg 图标 + surfaceAlt(track)底', (tester) async {
      await pumpHost(tester);
      final style = tester.widget<IconButton>(find.byType(IconButton)).style;
      expect(style?.foregroundColor?.resolve({WidgetState.hovered}),
          YucaiTheme.light().fg); // 原型 .x:hover --fg
      expect(style?.foregroundColor?.resolve(<WidgetState>{}),
          YucaiTheme.light().muted); // 默认 muted
      expect(style?.backgroundColor?.resolve({WidgetState.hovered}),
          YucaiTheme.light().surfaceAlt); // 原型 .x:hover --seg-track
    });
  });

  group('无副作用守门(组件纯展示+返回)', () {
    test('源码静态检查:barrierDismissible=true;无裸色/AppColors/设置仓储依赖',
        () {
      final src =
          File('lib/settings/widgets/first_close_dialog.dart').readAsStringSync();
      expect(src.contains('barrierDismissible: true'), isTrue,
          reason: 'FR-3:barrier 点击 = 取消');
      expect(src.contains('Color(0x'), isFalse,
          reason: 'R8 禁 v1 硬编码色:颜色须经 context.yucai 语义令牌');
      expect(src.contains('AppColors'), isFalse,
          reason: 'R8:AppColors 为 legacy 过渡层,新增 UI 禁用');
      expect(src.contains('TraySettings'), isFalse,
          reason: '组件无业务依赖:首关标记写入是 T4 消费方职责');
      expect(src.contains('setFirstClosePrompted'), isFalse,
          reason: '本组件不写任何设置标记(无副作用)');
    });
  });
}
