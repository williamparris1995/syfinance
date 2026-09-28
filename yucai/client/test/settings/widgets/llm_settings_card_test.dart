// F46 T2(2026-09-28):「AI 分析师」设置卡 widget 测试(seam =
// LlmSettingsCard 公共构造 + LlmSettings 注入缝;文案逐字 prototype v9
// settings.html「AI 分析师」卡)。
//
// 覆盖:六行渲染/未启用禁用态(半透明+IgnorePointer+输入禁用)/首启用
// 免责流(取消回弹零持久化、ack 持久化、ack 后不再弹)/服务商切换预填
// (base_url+默认模型名 glm-4.6/gpt-4o-mini/deepseek-chat/空,自定义出
// 服务端点输入行)/API Key obscured+onChanged 持久化/城市档位/订阅名明文。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/llm/llm_settings.dart';
import 'package:yucai_client/settings/widgets/llm_settings_card.dart';

/// Fake LlmSettings(照 settings_page_test._FakeTraySettings 范式):
/// notifier 驱动选中态;记录全部 setConfig 调用供持久化断言。
class _FakeLlmSettings extends Fake implements LlmSettings {
  _FakeLlmSettings(LlmConfig initial) : _notifier = ValueNotifier(initial);
  final ValueNotifier<LlmConfig> _notifier;
  final List<LlmConfig> saved = [];

  @override
  LlmConfig get value => _notifier.value;

  @override
  ValueListenable<LlmConfig> get listenable => _notifier;

  @override
  bool get ready => _notifier.value.ready;

  @override
  Future<void> setConfig(LlmConfig config) async {
    saved.add(config);
    _notifier.value = config;
  }
}

Widget _host(LlmSettings settings) => MaterialApp(
      home: Scaffold(
        body: ListView(children: [LlmSettingsCard(settings: settings)]),
      ),
   );

/// 已启用已确认态(zhipu 预设,免弹免责)。
const _ackd = LlmConfig(
  enabled: true,
  disclaimerAck: true,
  apiKey: 'sk-test',
  model: 'glm-4.6',
);

void main() {
  group('六行渲染(v9「AI 分析师」卡逐字)', () {
    testWidgets('标题 + 启用开关 + 服务商四 pills + API Key + 模型名 + 城市规模 + 订阅名明文',
        (tester) async {
      await tester.pumpWidget(_host(_FakeLlmSettings(const LlmConfig())));
      await tester.pumpAndSettle();
      expect(find.text('AI 分析师'), findsOneWidget); // 卡标题
      expect(find.text('启用 AI 分析师'), findsOneWidget);
      expect(find.text('服务商'), findsOneWidget);
      for (final p in ['智谱', 'OpenAI', 'DeepSeek', '自定义']) {
        expect(find.text(p), findsOneWidget, reason: '服务商 pill:$p');
      }
      expect(find.text('API Key'), findsOneWidget);
      expect(find.text('仅存本机安全存储'), findsOneWidget);
      expect(find.text('模型名'), findsOneWidget);
      expect(find.text('城市规模'), findsOneWidget);
      for (final t in ['一线', '新一线', '二三线']) {
        expect(find.text(t), findsOneWidget, reason: '城市档位:$t');
      }
      expect(find.text('订阅名明文'), findsOneWidget);
      // 预设商(默认智谱)无服务端点输入行(仅自定义出现)。
      expect(find.text('服务端点'), findsNothing);
    });

    testWidgets('API Key 输入:obscured + v9 占位符逐字', (tester) async {
      await tester.pumpWidget(_host(_FakeLlmSettings(_ackd)));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
          find.byKey(const ValueKey('llmApiKeyInput')));
      expect(field.obscureText, isTrue);
      expect(field.decoration?.hintText, '••••••••••••••');
    });

    testWidgets('模型名占位符:glm-4.6(v9 逐字)', (tester) async {
      await tester.pumpWidget(_host(_FakeLlmSettings(const LlmConfig())));
      await tester.pumpAndSettle();
      final field = tester
          .widget<TextField>(find.byKey(const ValueKey('llmModelInput')));
      expect(field.decoration?.hintText, 'glm-4.6');
    });
  });

  group('未启用禁用态(v9 .llm-cfg.off:半透明+pointer-events:none)', () {
    testWidgets('配置行被 IgnorePointer 罩住 + 输入框禁用', (tester) async {
      await tester.pumpWidget(_host(_FakeLlmSettings(const LlmConfig())));
      await tester.pumpAndSettle();
      // 服务商 seg / API Key 输入均被罩住(断言存在 ignoring=true 的祖先;
      // 框架内部自带若干 ignoring=false 的 IgnorePointer,不参与判定)。
      bool hasIgnoring(bool v) {
        final ancestors = find.ancestor(
            of: find.byKey(const ValueKey('llmProviderSeg')),
            matching: find.byType(IgnorePointer));
        return tester
            .widgetList<IgnorePointer>(ancestors)
            .any((w) => w.ignoring == v);
      }

      expect(hasIgnoring(true), isTrue,
          reason: '未启用时配置行禁点(v9 pointer-events:none)');

      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('llmApiKeyInput')))
            .enabled,
        isFalse,
      );
      expect(
        tester.widget<TextField>(find.byKey(const ValueKey('llmModelInput')))
            .enabled,
        isFalse,
      );
      // 禁用态点击城市档位不产生写入。
      final fake = _FakeLlmSettings(const LlmConfig());
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新一线'));
      await tester.pumpAndSettle();
      expect(fake.saved, isEmpty);
    });

    testWidgets('已启用:配置行无 ignoring 罩(可交互)', (tester) async {
      await tester.pumpWidget(_host(_FakeLlmSettings(_ackd)));
      await tester.pumpAndSettle();
      final ancestors = find.ancestor(
          of: find.byKey(const ValueKey('llmProviderSeg')),
          matching: find.byType(IgnorePointer));
      expect(
        tester.widgetList<IgnorePointer>(ancestors).every((w) => !w.ignoring),
        isTrue,
      );
    });
  });

  group('首启用免责流(FR-1:确认才生效,取消回弹)', () {
    testWidgets('取消:开关回弹 + 零持久化(不写 enabled/ack)', (tester) async {
      final fake = _FakeLlmSettings(const LlmConfig());
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('llmEnableSwitch')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget); // 免责弹出
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.widgetWithText(Switch, '启用 AI 分析师'),
          findsNothing); // 保险:行结构
      expect(
        tester.widget<Switch>(find.byKey(const ValueKey('llmEnableSwitch')))
            .value,
        isFalse,
        reason: '取消 → 开关回弹(UI 经 listenable 未变即回)',
      );
      expect(fake.saved, isEmpty, reason: '取消路径零持久化');
    });

    testWidgets('确认:持久化 enabled+disclaimerAck', (tester) async {
      final fake = _FakeLlmSettings(const LlmConfig());
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('llmEnableSwitch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('我已知悉并启用'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(fake.saved, hasLength(1));
      expect(fake.saved.single.enabled, isTrue);
      expect(fake.saved.single.disclaimerAck, isTrue);
      expect(
        tester.widget<Switch>(find.byKey(const ValueKey('llmEnableSwitch')))
            .value,
        isTrue,
      );
    });

    testWidgets('ack 后:关闭再开启不再弹免责', (tester) async {
      final fake = _FakeLlmSettings(_ackd);
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();
      // 已启用 → 关。
      await tester.tap(find.byKey(const ValueKey('llmEnableSwitch')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing, reason: '关闭不弹');
      expect(fake.saved.last.enabled, isFalse);
      // 再开:ack 已持久化 → 直接生效,零弹窗。
      await tester.tap(find.byKey(const ValueKey('llmEnableSwitch')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing, reason: 'ack 后不再弹');
      expect(fake.saved.last.enabled, isTrue);
      expect(fake.saved.last.disclaimerAck, isTrue);
    });
  });

  group('服务商切换预填(base_url + 默认模型名)', () {
    testWidgets('切 OpenAI:provider+gpt-4o-mini+预设 base_url 一并写入',
        (tester) async {
      final fake = _FakeLlmSettings(_ackd);
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OpenAI'));
      await tester.pumpAndSettle();
      expect(fake.saved.last.provider, LlmProvider.openai);
      expect(fake.saved.last.model, 'gpt-4o-mini');
      expect(fake.saved.last.baseUrl, 'https://api.openai.com/v1');
    });

    testWidgets('切 DeepSeek:deepseek-chat + 预设 base_url', (tester) async {
      final fake = _FakeLlmSettings(_ackd);
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DeepSeek'));
      await tester.pumpAndSettle();
      expect(fake.saved.last.provider, LlmProvider.deepseek);
      expect(fake.saved.last.model, 'deepseek-chat');
      expect(fake.saved.last.baseUrl, 'https://api.deepseek.com/v1');
    });

    testWidgets('切自定义:模型名清空 + 出现服务端点输入行,回车提交后持久化',
        (tester) async {
      final fake = _FakeLlmSettings(_ackd);
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();
      await tester.tap(find.text('自定义'));
      await tester.pumpAndSettle();
      expect(fake.saved.last.provider, LlmProvider.custom);
      expect(fake.saved.last.model, '', reason: '自定义默认模型名 = 空');
      expect(find.text('服务端点'), findsOneWidget, reason: '自定义出 base_url 行');
      await tester.enterText(
          find.byKey(const ValueKey('llmBaseUrlInput')), 'https://my.llm/v1');
      await tester.pump();
      // 输入过程不落存储(失焦+回车提交,评审 R1)。
      expect(fake.saved.last.baseUrl, isNot('https://my.llm/v1'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(fake.saved.last.baseUrl, 'https://my.llm/v1');
      expect(fake.saved.last.resolvedBaseUrl, 'https://my.llm/v1');
    });

    testWidgets('切回智谱:glm-4.6 + 预设 base_url(自定义残留被覆盖)',
        (tester) async {
      final fake = _FakeLlmSettings(const LlmConfig(
        enabled: true,
        disclaimerAck: true,
        provider: LlmProvider.custom,
        baseUrl: 'https://my.llm/v1',
        apiKey: 'sk-test',
      ));
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();
      await tester.tap(find.text('智谱'));
      await tester.pumpAndSettle();
      expect(fake.saved.last.provider, LlmProvider.zhipu);
      expect(fake.saved.last.model, 'glm-4.6');
      expect(fake.saved.last.baseUrl, 'https://open.bigmodel.cn/api/paas');
    });
  });

  group('其余行写入(全部走 LlmSettings.setConfig)', () {
    testWidgets('API Key:输入过程不落存储;失焦后落(评审 R1)', (tester) async {
      final fake = _FakeLlmSettings(_ackd);
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('llmApiKeyInput')), 'sk-xyz');
      await tester.pump();
      // 击键中:零 setConfig(不每击键写 secure storage)。
      expect(fake.saved, isEmpty, reason: '输入过程不落存储');
      // 失焦(点卡片外非交互区不可靠,直用 FocusManager)→ 提交。
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(fake.saved, hasLength(1));
      expect(fake.saved.last.apiKey, 'sk-xyz');
    });

    testWidgets('模型名:回车(done)提交覆盖预填默认(评审 R1)', (tester) async {
      final fake = _FakeLlmSettings(_ackd);
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('llmModelInput')), 'glm-4-flash');
      await tester.pump();
      expect(fake.saved, isEmpty, reason: '输入过程不落存储');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(fake.saved.last.model, 'glm-4-flash');
    });

    testWidgets('城市档位:切新一线 → tier2', (tester) async {
      final fake = _FakeLlmSettings(_ackd);
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新一线'));
      await tester.pumpAndSettle();
      expect(fake.saved.last.cityTier, LlmCityTier.tier2);
    });

    testWidgets('订阅名明文开关:默认关,开 → includeNames=true', (tester) async {
      final fake = _FakeLlmSettings(_ackd);
      await tester.pumpWidget(_host(fake));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Switch>(find.byKey(const ValueKey('llmIncludeNamesSwitch')))
            .value,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('llmIncludeNamesSwitch')));
      await tester.pumpAndSettle();
      expect(fake.saved.last.includeNames, isTrue);
    });
  });

  group('守门(硬约束)', () {
    test('源码静态检查:无裸色/无 AppColors/presentation 不 import data 层',
        () {
      final src =
          File('lib/settings/widgets/llm_settings_card.dart').readAsStringSync();
      expect(src.contains('Color(0x'), isFalse, reason: '禁裸色:走 context.yucai');
      expect(src.contains('AppColors'), isFalse, reason: 'legacy 色禁用');
      expect(src.contains('llm_http'), isFalse,
          reason: 'presentation 不直接 import llm_http');
      expect(src.contains('llm_mda_narrator'), isFalse,
          reason: 'presentation 不直接 import narrator 实现(经 port)');
    });
  });
}
