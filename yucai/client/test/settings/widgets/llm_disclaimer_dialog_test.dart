// F46 T2(2026-09-28):AI 分析师首启用免责对话框单测(spec FR-1:首次开启
// 启用开关时弹完整免责,确认才生效,取消回弹——本组件照 F22 first_close_dialog
// 范式:纯展示+返回,**不写任何设置标记**,disclaimerAck+enabled 的持久化由
// 消费方(设置卡)负责)。
// - 文案逐字:四行免责(prototype v9 settings.html #llmDlg)+[取消]/
//   [我已知悉并启用] 两钮;
// - 三路返回:主按钮 → true;取消钮 / barrier / Esc → false;
// - 视觉契约:卡宽 400 / 圆角 16(dialog 规格,first_close_dialog 同款);
// - 主题探针:亮/暗双主题渲染不抛 + surface 令牌生效;
// - 无副作用守门:源码无裸色 / 不依赖设置仓储、不写 ack 标记。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/settings/widgets/llm_disclaimer_dialog.dart';

void main() {
  bool? captured;
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
                  captured = await showLlmDisclaimerDialog(ctx);
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

  group('文案逐字(prototype v9 settings.html #llmDlg)', () {
    testWidgets('标题 + 四行免责 + 两钮', (tester) async {
      await pumpHost(tester);
      expect(find.text('启用 AI 分析师'), findsOneWidget);
      // 四行逐字(标点宽度与 v9 一致:ASCII 括号/分号/逗号 + 、 。)。
      expect(
          find.text('数据将以脱敏汇总形式(类别构成与金额区间)'
              '发送至你配置的服务端点;'),
          findsOneWidget);
      expect(find.text('不会发送账户名、交易明细或身份信息;'), findsOneWidget);
      expect(find.text('AI 输出仅供参考,不构成投资建议;'), findsOneWidget);
      expect(find.text('API Key 仅保存在本机。'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '我已知悉并启用'), findsOneWidget);
    });
  });

  group('三路返回(确认 / 取消)', () {
    testWidgets('点主按钮「我已知悉并启用」→ true(消费方据此写 ack+enabled)',
        (tester) async {
      await pumpHost(tester);
      await tester.tap(find.text('我已知悉并启用'));
      await tester.pumpAndSettle();
      expect(captured, isTrue);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('点「取消」→ false(开关回弹,不持久化)', (tester) async {
      await pumpHost(tester);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(captured, isFalse);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('点击 barrier → false(barrierDismissible=true)', (tester) async {
      await pumpHost(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(captured, isFalse);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('按 Esc → false', (tester) async {
      await pumpHost(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(captured, isFalse);
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('视觉契约(first_close_dialog 范式同款)', () {
    testWidgets('卡宽 400 / 圆角 16 / surface 底', (tester) async {
      await pumpHost(tester);
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect((dialog.child! as SizedBox).width, 400);
      final shape = dialog.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect((shape! as RoundedRectangleBorder).borderRadius, AppRadius.lgBorder);
      expect(dialog.backgroundColor, YucaiTheme.light().surface);
    });

    testWidgets('暗色主题渲染不抛,surface 令牌生效', (tester) async {
      await pumpHost(tester, theme: AppTheme.dark());
      expect(find.text('启用 AI 分析师'), findsOneWidget);
      expect(
        tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
        YucaiTheme.dark().surface,
      );
    });
  });

  group('无副作用守门(组件纯展示+返回)', () {
    test('源码静态检查:无裸色/AppColors/LlmSettings 依赖', () {
      final src =
          File('lib/settings/widgets/llm_disclaimer_dialog.dart').readAsStringSync();
      expect(src.contains('Color(0x'), isFalse,
          reason: '禁 v1 硬编码色:颜色须经 context.yucai 语义令牌');
      expect(src.contains('AppColors'), isFalse,
          reason: 'AppColors 为 legacy 过渡层,新增 UI 禁用');
      expect(src.contains('LlmSettings'), isFalse,
          reason: '组件无业务依赖:ack+enabled 写入是设置卡职责');
    });
  });
}
