// F65-T3(2026-10-24):聊天浮层宿主 widget 测试(spec FR-1 三场景 + FR-4;
// 视觉事实源 = prototype v19 ui/assistant-entry-variants.html V1 段 +
// assistant-chat-states.html 全页)。
//
// seam = AssistantOverlayHost 公共构造四注入缝(AgentLoopService /
// AssistantSettings / ModelManagerPort / EngineManager 全 fake,照 T4
// model_management_card_test 范式)+ frameInterval: Duration.zero 关离合帧
// (照 T2 bloc 测)。覆盖:FAB 开合 / 打开即 ensureReady 预热(ADR-1)/
// 空态引导 chips / 五型 PanelMessage 渲染(含动效态存在性 —— spinner 照
// 仓内 sync_status_badge_test 惯例 find.byType(CircularProgressIndicator),
// 流式光标按 key)/ 发送禁用态(streaming)/ Enter 发送 / 重试回调 /
// 新对话清屏(FR-4)/ 引导三型(未启用/模型未就绪含进度/引擎冷启动,F66)/
// 打字指示气泡(F65 热修:发送→首 token 死区 + 工具轮间隙,v19 .typing)。
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/assistant/data/assistant_settings_store.dart';
import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_manager_port.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';
import 'package:yucai_client/assistant/presentation/widgets/assistant_overlay_host.dart';

/// Fake AgentLoopService(照 T2 assistant_panel_bloc_test._FakeLoop):
/// 脚本化 rounds;交互用例可直接塞 StreamController.stream 手推事件。
class _FakeLoop implements AgentLoopService {
  _FakeLoop(this.rounds);

  final List<Stream<AssistantEvent>> rounds;
  final List<String> sentMessages = [];
  int resetCount = 0;
  int _next = 0;

  @override
  Stream<AssistantEvent> send(String userMessage) {
    sentMessages.add(userMessage);
    if (_next >= rounds.length) {
      throw StateError('no scripted round for send #${sentMessages.length}');
    }
    return rounds[_next++];
  }

  @override
  void resetConversation() => resetCount++;
}

/// Fake AssistantSettings(照 T4 范式):notifier 驱动配置态。
class _FakeAssistantSettings extends Fake implements AssistantSettings {
  _FakeAssistantSettings(AssistantConfig initial)
      : _notifier = ValueNotifier(initial);

  final ValueNotifier<AssistantConfig> _notifier;

  @override
  AssistantConfig get value => _notifier.value;

  @override
  ValueListenable<AssistantConfig> get listenable => _notifier;

  @override
  Future<void> setConfig(AssistantConfig config) async {
    _notifier.value = config;
  }
}

/// Fake ModelManagerPort(照 T4 范式)。
class _FakeModelManager implements ModelManagerPort {
  _FakeModelManager(ModelState initial) : state = ValueNotifier(initial);

  @override
  final ValueNotifier<ModelState> state;

  @override
  Future<void> download() async {}

  @override
  void pause() {}

  @override
  void cancel() {}

  @override
  Future<void> delete() async {}

  @override
  Future<int> diskUsageBytes() async => kModelManifest.totalBytes;

  @override
  ModelManifest get manifest => kModelManifest;
}

/// Fake EngineManager(照 T4 范式):计数 ensureReady 预热调用。
class _FakeEngineManager implements EngineManager {
  _FakeEngineManager(EngineState initial) : state = ValueNotifier(initial);

  @override
  final ValueNotifier<EngineState> state;

  int ensureReadyCalls = 0;

  @override
  Future<void> ensureReady() async {
    ensureReadyCalls++;
  }

  @override
  Future<void> shutdown() async {}

  @override
  void beginActivity() {}

  @override
  void endActivity() {}
}

/// 全就绪缺省(发送守卫全过)。
const _readyConfig = AssistantConfig(enabled: true);

/// 演示数据(照 v19 state-6:1.2GB / 2.5GB · 48%)。
const _downloading = ModelDownloading(
  receivedBytes: 1200000000,
  totalBytes: 2497281120,
  bytesPerSec: 8200000,
);

Widget _host(
  _FakeLoop loop, {
  _FakeAssistantSettings? settings,
  _FakeModelManager? modelManager,
  _FakeEngineManager? engineManager,
}) {
  return MaterialApp(
    home: Scaffold(
      body: AssistantOverlayHost(
        loop: loop,
        settings:
            settings ?? _FakeAssistantSettings(_readyConfig),
        modelManager:
            modelManager ?? _FakeModelManager(const ModelReady()),
        engineManager: engineManager ??
            _FakeEngineManager(EngineReady(Uri.parse('http://127.0.0.1:1/v1'))),
        frameInterval: Duration.zero,
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('assistantFab')));
  await tester.pumpAndSettle();
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byKey(const ValueKey('assistantSendButton')));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('FAB 与浮层开合(v19 V1 段)', () {
    testWidgets('初始仅 FAB(44px 圆);点击展开 400px 浮层;再点收起(toggle)',
        (tester) async {
      final loop = _FakeLoop([]);
      await tester.pumpWidget(_host(loop));
      await tester.pumpAndSettle();
      // FAB 常驻:44px 圆钮(v19 .fab-assist:44x44,主 FAB 52 区分)。
      expect(find.byKey(const ValueKey('assistantFab')), findsOneWidget);
      expect(
          tester.getSize(find.byKey(const ValueKey('assistantFab'))),
          const Size(44, 44),
          reason: 'v19 fab-assist 44px,与 dock 主 FAB 52px 区分');
      // 浮层未开:头部标题不可见。
      expect(find.text('御财助手'), findsNothing);
      await _open(tester);
      // 头部:标题 + 「本机运行」chip + 新对话 + 关闭(v19 cp-head + FR-4)。
      expect(find.text('御财助手'), findsOneWidget);
      expect(find.text('本机运行'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('assistantNewChatButton')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('assistantCloseButton')), findsOneWidget);
      // 浮层宽度 400(v19 .float-chat width:400)。
      expect(
          tester
              .getSize(find.byKey(const ValueKey('assistantPanel')))
              .width,
          400);
      // 再点 FAB = 收起(toggle)。
      await tester.tap(find.byKey(const ValueKey('assistantFab')));
      await tester.pumpAndSettle();
      expect(find.text('御财助手'), findsNothing);
    });

    testWidgets('关闭按钮收起浮层', (tester) async {
      final loop = _FakeLoop([]);
      await tester.pumpWidget(_host(loop));
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('assistantCloseButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('assistantPanel')), findsNothing);
    });

    testWidgets('打开浮层即预热 EngineManager.ensureReady(ADR-1/F66)',
        (tester) async {
      final loop = _FakeLoop([]);
      final engine = _FakeEngineManager(const EngineStopped());
      await tester.pumpWidget(_host(loop, engineManager: engine));
      expect(engine.ensureReadyCalls, 0, reason: '未打开零预热');
      await _open(tester);
      expect(engine.ensureReadyCalls, 1, reason: '打开即预热(ensureReady 幂等)');
      // 关闭再开:再预热一次(每次打开都调,幂等由 impl 承担)。
      await tester.tap(find.byKey(const ValueKey('assistantFab')));
      await tester.pumpAndSettle();
      await _open(tester);
      expect(engine.ensureReadyCalls, 2);
    });
  });

  group('空态引导(v19 state-1)', () {
    testWidgets('空态徽标 + 引导文案 + 三枚示例问题 chips;点击 chip 即发送',
        (tester) async {
      final loop = _FakeLoop([
        Stream.fromIterable(const [TextDelta('答'), Done()]),
      ]);
      await tester.pumpWidget(_host(loop));
      await _open(tester);
      expect(find.text('我是御财助手,数据都在本机'), findsOneWidget);
      expect(find.text('支出、预算、资产都可以问'), findsOneWidget);
      expect(find.text('这个月花了多少'), findsOneWidget);
      expect(find.text('广发卡还差多少'), findsOneWidget);
      expect(find.text('今年收益率'), findsOneWidget);
      // 输入行占位(v19 cp-input placeholder)。
      expect(find.text('问点什么,如:广发卡还差多少'), findsOneWidget);
      await tester.tap(find.text('这个月花了多少'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(loop.sentMessages, ['这个月花了多少'], reason: 'chip 即问');
    });
  });

  group('消息渲染(PanelMessage sealed 五型,v19 state-2/5)', () {
    testWidgets('UserMsg 右气泡 / AssistantMsg 左气泡;完成后无流式光标',
        (tester) async {
      final loop = _FakeLoop([
        Stream.fromIterable(const [
          TextDelta('净资产为 '),
          TextDelta('1000.00'),
          Done(),
        ]),
      ]);
      await tester.pumpWidget(_host(loop));
      await _open(tester);
      await _send(tester, '查净资产');
      expect(find.byKey(const ValueKey('assistantUserBubble')), findsOneWidget);
      expect(find.byKey(const ValueKey('assistantBotBubble')), findsOneWidget);
      expect(find.text('净资产为 1000.00'), findsOneWidget);
      // 对齐:User 右 / Assistant 左(v19 .msg.user align-self:flex-end)。
      final userAlign = tester.widget<Align>(
          find.ancestor(
              of: find.byKey(const ValueKey('assistantUserBubble')),
              matching: find.byType(Align)).first);
      expect(userAlign.alignment, Alignment.centerRight);
      final botAlign = tester.widget<Align>(
          find.ancestor(
              of: find.byKey(const ValueKey('assistantBotBubble')),
              matching: find.byType(Align)).first);
      expect(botAlign.alignment, Alignment.centerLeft);
      // idle 终态:流式光标不在。
      expect(find.byKey(const ValueKey('assistantStreamCursor')), findsNothing);
    });

    testWidgets('流式进行中:尾段 AssistantMsg 带闪烁光标(动效存在性)',
        (tester) async {
      final controller = StreamController<AssistantEvent>();
      final loop = _FakeLoop([controller.stream]);
      await tester.pumpWidget(_host(loop));
      await _open(tester);
      await _send(tester, '查净资产');
      // 尚无任何 AssistantMsg:无光标。
      expect(find.byKey(const ValueKey('assistantStreamCursor')), findsNothing);
      controller.add(const TextDelta('净资产'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('净资产'), findsOneWidget);
      // streaming 中尾段带光标(闪烁动效 widget 存在性断言)。
      expect(find.byKey(const ValueKey('assistantStreamCursor')),
          findsOneWidget);
      await controller.close();
      await tester.pump(const Duration(milliseconds: 50));
      // 终态:光标消失,内容定格。
      expect(find.byKey(const ValueKey('assistantStreamCursor')), findsNothing);
    });

    testWidgets('ToolStatusMsg:进行中「正在查询净资产…」+ spinner;完成打勾;失败 X',
        (tester) async {
      final controller = StreamController<AssistantEvent>();
      final loop = _FakeLoop([controller.stream]);
      await tester.pumpWidget(_host(loop));
      await _open(tester);
      await _send(tester, '查净资产');
      controller
        ..add(const ToolCallStart('c1', 'networth_snapshot'))
        ..add(const TextDelta('净资产为 1000.00'));
      await tester.pump(const Duration(milliseconds: 50));
      // 进行中:pill + spinner(仓内 spinner 断言惯例 byType)。
      expect(find.byKey(const ValueKey('assistantToolPill')), findsOneWidget);
      expect(find.text('正在查询净资产…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      controller.add(const ToolCallEnd('c1', true));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('已查询净资产'), findsOneWidget, reason: '完成态文案');
      expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget,
          reason: '完成打勾');
      // 失败态(自纠失败):X 图标。
      controller.add(const ToolCallStart('c2', 'networth_snapshot'));
      await tester.pump(const Duration(milliseconds: 50));
      controller.add(const ToolCallEnd('c2', false));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(LucideIcons.circleX), findsOneWidget);
      controller.add(const Done());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('打字指示气泡(F65 热修:发送→首 token 死区,v19 .typing)', () {
    testWidgets('发送后首 delta 前:三点指示在;首个 TextDelta 落段后消失,光标接管',
        (tester) async {
      final controller = StreamController<AssistantEvent>();
      final loop = _FakeLoop([controller.stream]);
      await tester.pumpWidget(_host(loop));
      await _open(tester);
      await _send(tester, '查净资产');
      // 死区(streaming 且本轮无 AssistantMsg):三点指示在 —— 流式光标仅
      // 覆盖已有文本段,死区内无 AssistantMsg 可挂(用户实测反馈的死区)。
      expect(find.byKey(const ValueKey('assistantTypingIndicator')),
          findsOneWidget,
          reason: '发送→首 token 之间须有「正在回答」指示');
      expect(find.byKey(const ValueKey('assistantTypingDot')), findsNWidgets(3),
          reason: 'v19 .typing:三点');
      expect(find.byKey(const ValueKey('assistantBotBubble')), findsNothing);
      expect(find.byKey(const ValueKey('assistantStreamCursor')), findsNothing);
      controller.add(const TextDelta('净资产'));
      await tester.pump(const Duration(milliseconds: 50));
      // 首 TextDelta 落段:指示消失,流式光标接管(条件天然切换)。
      expect(find.byKey(const ValueKey('assistantTypingIndicator')),
          findsNothing,
          reason: '本轮已有 AssistantMsg → 指示让位流式光标');
      expect(
          find.byKey(const ValueKey('assistantStreamCursor')), findsOneWidget);
      controller.add(const Done());
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('assistantStreamCursor')), findsNothing);
    });

    testWidgets('工具轮:awaitTool 指示让位 pill;工具完成仍无文本 → 指示与完成 pill 并存',
        (tester) async {
      final controller = StreamController<AssistantEvent>();
      final loop = _FakeLoop([controller.stream]);
      await tester.pumpWidget(_host(loop));
      await _open(tester);
      await _send(tester, '查净资产');
      expect(find.byKey(const ValueKey('assistantTypingIndicator')),
          findsOneWidget);
      controller.add(const ToolCallStart('c1', 'networth_snapshot'));
      await tester.pump(const Duration(milliseconds: 50));
      // awaitTool:指示面归工具 pill(「正在查询…」+ spinner)。
      expect(find.byKey(const ValueKey('assistantToolPill')), findsOneWidget);
      expect(find.byKey(const ValueKey('assistantTypingIndicator')),
          findsNothing,
          reason: 'awaitTool 由工具 pill 覆盖指示面(条件=streaming)');
      controller.add(const ToolCallEnd('c1', true));
      await tester.pump(const Duration(milliseconds: 50));
      // 工具完成回 streaming 且本轮仍无 AssistantMsg → 条件自然继续成立,
      // 指示回归并与完成态 pill 并存(工具轮间隙死区)。
      expect(find.text('已查询净资产'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistantToolPill')), findsOneWidget,
          reason: '完成态 pill 留存');
      expect(find.byKey(const ValueKey('assistantTypingIndicator')),
          findsOneWidget,
          reason: '工具完成后无文本间隙:指示与 pill 并存');
      controller.add(const Done());
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('assistantTypingIndicator')),
          findsNothing,
          reason: '终态指示消失');
    });

    testWidgets('本轮已有文本后的工具间隙:指示不回归(条件单点按最后 UserMsg 判定)',
        (tester) async {
      final controller = StreamController<AssistantEvent>();
      final loop = _FakeLoop([controller.stream]);
      await tester.pumpWidget(_host(loop));
      await _open(tester);
      await _send(tester, '查净资产');
      controller.add(const TextDelta('我查一下'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('assistantTypingIndicator')),
          findsNothing,
          reason: '已有文本:首 delta 起指示即消失');
      controller.add(const ToolCallStart('c1', 'networth_snapshot'));
      await tester.pump(const Duration(milliseconds: 50));
      controller.add(const ToolCallEnd('c1', true));
      await tester.pump(const Duration(milliseconds: 50));
      // 工具完成后回 streaming,但最后 UserMsg 后已有 AssistantMsg → 指示
      // 不回归(该面由既有文本气泡 + 完成 pill 表达;规则单点不特判)。
      expect(find.byKey(const ValueKey('assistantTypingIndicator')),
          findsNothing,
          reason: '条件单点:最后 UserMsg 后已有 AssistantMsg 即不显示');
      controller.add(const Done());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('错误态:指示消失,错误条接管', (tester) async {
      final controller = StreamController<AssistantEvent>();
      final loop = _FakeLoop([controller.stream]);
      await tester.pumpWidget(_host(loop));
      await _open(tester);
      await _send(tester, '查净资产');
      expect(find.byKey(const ValueKey('assistantTypingIndicator')),
          findsOneWidget);
      controller.add(const AssistantError('本机引擎暂时无响应'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('assistantErrorMsg')), findsOneWidget);
      expect(find.byKey(const ValueKey('assistantTypingIndicator')),
          findsNothing,
          reason: '错误终态指示消失(错误条 + 重试接管)');
    });
  });

  group('错误可重试(v19 state-5,FR-1 场景三)', () {
    testWidgets('错误条 + 重试按钮回调:重发最后 UserMsg,历史不删错',
        (tester) async {
      final loop = _FakeLoop([
        Stream.fromIterable(
            const [AssistantError('本机引擎暂时无响应')]),
        Stream.fromIterable(const [TextDelta('重试成功'), Done()]),
      ]);
      await tester.pumpWidget(_host(loop));
      await _open(tester);
      await _send(tester, '第一问');
      expect(find.byKey(const ValueKey('assistantErrorMsg')), findsOneWidget);
      expect(find.text('本机引擎暂时无响应'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('assistantRetryButton')));
      await tester.pump(const Duration(milliseconds: 50));
      // 重试 = 重发最后 UserMsg(loop 收到两次同文);错误条保留(不删错)。
      expect(loop.sentMessages, ['第一问', '第一问']);
      expect(find.text('重试成功'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistantErrorMsg')), findsOneWidget,
          reason: 'FR-1 历史输入不丢/错不删');
    });
  });

  group('输入行(v19 cp-input)', () {
    testWidgets('streaming 态发送禁用:输入框与发送钮均禁用;终态恢复',
        (tester) async {
      final controller = StreamController<AssistantEvent>();
      final loop = _FakeLoop([controller.stream]);
      await tester.pumpWidget(_host(loop));
      await _open(tester);
      expect(
          tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      await _send(tester, '第一问');
      // streaming:输入禁用 + 发送钮 onPressed null。
      expect(
          tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
          tester
              .widget<IconButton>(
                  find.byKey(const ValueKey('assistantSendButton')))
              .onPressed,
          isNull);
      controller.add(const Done());
      await tester.pump(const Duration(milliseconds: 50));
      expect(
          tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(
          tester
              .widget<IconButton>(
                  find.byKey(const ValueKey('assistantSendButton')))
              .onPressed,
          isNotNull);
      // 不 await close:Done 终态已令 bloc 取消订阅,单订阅控制器的 done
      // future 在订阅取消后不再完成(await 会悬挂 10min 超时)。
      controller.close();
    });

    testWidgets('Enter 发送(onSubmitted)', (tester) async {
      final loop = _FakeLoop([
        Stream.fromIterable(const [TextDelta('答'), Done()]),
      ]);
      await tester.pumpWidget(_host(loop));
      await _open(tester);
      await tester.enterText(find.byType(TextField), '广发卡还差多少');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 50));
      expect(loop.sentMessages, ['广发卡还差多少']);
      expect(find.byKey(const ValueKey('assistantUserBubble')), findsOneWidget);
    });
  });

  group('新对话(FR-4,v19 头部按钮)', () {
    testWidgets('清空消息流回空态 + reset loop 会话上下文', (tester) async {
      final loop = _FakeLoop([
        Stream.fromIterable(const [TextDelta('答'), Done()]),
      ]);
      await tester.pumpWidget(_host(loop));
      await _open(tester);
      await _send(tester, '第一问');
      expect(find.byKey(const ValueKey('assistantUserBubble')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('assistantNewChatButton')));
      await tester.pump(const Duration(milliseconds: 50));
      // 回空态(引导 chips 复现)+ loop 复位。
      expect(find.text('我是御财助手,数据都在本机'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistantUserBubble')), findsNothing);
      expect(loop.resetCount, 1);
    });
  });

  group('引导三型(GuideMsg,FR-1 场景二:零 LLM 调用)', () {
    testWidgets('notEnabled:未启用引导卡 + 去设置按钮;不发 LLM 调用',
        (tester) async {
      final loop = _FakeLoop([]);
      await tester.pumpWidget(_host(
        loop,
        settings: _FakeAssistantSettings(const AssistantConfig()),
      ));
      await _open(tester);
      await _send(tester, '这个月花了多少');
      expect(find.text('AI 助手未启用'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistantGoSettingsButton')),
          findsOneWidget);
      expect(loop.sentMessages, isEmpty, reason: '守卫拦截:零 LLM 调用');
      // 无 GoRouter 的测试 harness:点击不抛(maybeOf null 容忍)。
      await tester.tap(find.byKey(const ValueKey('assistantGoSettingsButton')));
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('modelNotReady:下载引导 + 进度条(ModelState 绑定,v19 state-6)',
        (tester) async {
      final loop = _FakeLoop([]);
      final model = _FakeModelManager(_downloading);
      await tester.pumpWidget(_host(loop, modelManager: model));
      await _open(tester);
      await _send(tester, '我的净资产是多少');
      expect(find.text('正在下载模型'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistantGuideProgress')),
          findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('assistantGuideProgress')));
      expect(bar.value,
          closeTo(1200000000 / kModelManifest.totalBytes, 0.001));
      expect(find.text('1.2GB / 2.5GB · 可断点续传'), findsOneWidget);
      expect(find.text('下载完成后即可离线使用'), findsOneWidget);
      expect(loop.sentMessages, isEmpty, reason: '守卫拦截:零 LLM 调用');
      // ModelState 流转:下载完成 → 就绪后引导卡消失需重发;此处仅钉流转
      // 重渲染(paused 态文案切换)。
      model.state.value = const ModelPaused(
          receivedBytes: 1200000000, totalBytes: 2497281120);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('模型未就绪'), findsOneWidget,
          reason: '非下载态切回通用引导文案');
    });

    testWidgets('engineStarting:引擎启动中加载动效(F66 拍板)',
        (tester) async {
      final loop = _FakeLoop([]);
      await tester.pumpWidget(_host(
          loop, engineManager: _FakeEngineManager(const EngineStarting())));
      await _open(tester);
      await _send(tester, '这个月花了多少');
      expect(find.text('引擎启动中…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget,
          reason: 'F66:冷启 3-8s 须显加载动效(旋转指示)');
      expect(loop.sentMessages, isEmpty, reason: '守卫拦截:零 LLM 调用');
    });
  });

  group('守门(硬约束,NFR-2)', () {
    test('源码静态检查:无裸色/无 AppColors/不 import data 层实现', () {
      final src = File(
              'lib/assistant/presentation/widgets/assistant_overlay_host.dart')
          .readAsStringSync();
      expect(src.contains('Color(0x'), isFalse, reason: '禁裸色:走 context.yucai');
      expect(src.contains('AppColors'), isFalse, reason: 'legacy 色禁用');
      expect(src.contains('engine_manager_impl'), isFalse,
          reason: 'presentation 不 import 引擎实现(经 EngineManager port)');
      expect(src.contains('model_manager_impl'), isFalse,
          reason: 'presentation 不 import 下载实现(经 ModelManagerPort port)');
      expect(src.contains('agent_loop_impl'), isFalse,
          reason: 'presentation 不 import loop 实现(经 AgentLoopService port)');
    });
  });
}
