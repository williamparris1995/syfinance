import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';
import 'package:yucai_client/assistant/presentation/assistant_panel/assistant_panel_bloc.dart';

/// F65-T2:AssistantPanelBloc 单测(FR-1/FR-4,bloc_test 范式)——
/// 脚本化 AgentLoopService(零真实 LLM)+ ValueNotifier 三状态缝;
/// 合帧窗口注入 Duration.zero:同一微任务批内到达的连续 TextDelta
/// 在定时器冲刷前全部进缓冲 → 全量合并为单次 AssistantMsg 增量。
void main() {
  const readyConfig = AssistantConfig(enabled: true);

  AssistantPanelBloc makeBloc(
    _FakeLoop loop, {
    AssistantConfig config = readyConfig,
    ModelState model = const ModelReady(),
    EngineState? engine,
  }) => AssistantPanelBloc(
    loop: loop,
    config: ValueNotifier(config),
    modelState: ValueNotifier(model),
    engineState: ValueNotifier(engine ?? _engineReady()),
    frameInterval: Duration.zero,
  );

  blocTest<AssistantPanelBloc, AssistantPanelState>(
    '流式合帧:窗口内多个 TextDelta 合并为单次 AssistantMsg 增量(Duration.zero)',
    build: () => makeBloc(
      _FakeLoop([
        Stream.fromIterable(const [
          TextDelta('净资'),
          TextDelta('产为 '),
          TextDelta('1000.00'),
          Done(),
        ]),
      ]),
    ),
    act: (b) => b.add(const SendRequested('查净资产')),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      const AssistantPanelState(
        messages: [UserMsg('查净资产')],
        sendState: PanelSendState.streaming,
      ),
      const AssistantPanelState(
        messages: [UserMsg('查净资产'), AssistantMsg('净资产为 1000.00')],
        sendState: PanelSendState.idle,
      ),
    ],
  );

  blocTest<AssistantPanelBloc, AssistantPanelState>(
    '工具条插入序:工具前文本保持在工具条之前,工具后文本新段;awaitTool 流转',
    build: () => makeBloc(
      _FakeLoop([
        Stream.fromIterable(const [
          TextDelta('正在查询净资产。'),
          ToolCallStart('call_001', 'networth_snapshot'),
          ToolCallEnd('call_001', true),
          TextDelta('你的净资产为 '),
          TextDelta('1000.00 CNY。'),
          Done(),
        ]),
      ]),
    ),
    act: (b) => b.add(const SendRequested('查净资产')),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      const AssistantPanelState(
        messages: [UserMsg('查净资产')],
        sendState: PanelSendState.streaming,
      ),
      const AssistantPanelState(
        messages: [
          UserMsg('查净资产'),
          AssistantMsg('正在查询净资产。'),
          ToolStatusMsg('networth_snapshot'),
        ],
        sendState: PanelSendState.awaitTool,
      ),
      const AssistantPanelState(
        messages: [
          UserMsg('查净资产'),
          AssistantMsg('正在查询净资产。'),
          ToolStatusMsg('networth_snapshot', ok: true),
        ],
        sendState: PanelSendState.streaming,
      ),
      const AssistantPanelState(
        messages: [
          UserMsg('查净资产'),
          AssistantMsg('正在查询净资产。'),
          ToolStatusMsg('networth_snapshot', ok: true),
          AssistantMsg('你的净资产为 1000.00 CNY。'),
        ],
        sendState: PanelSendState.idle,
      ),
    ],
  );

  final retryLoop = _FakeLoop([
    Stream.fromIterable(const [
      TextDelta('部分回答'),
      AssistantError('LLM 请求失败(SocketException(localhost))'),
    ]),
    Stream.fromIterable(const [TextDelta('重试成功'), Done()]),
  ]);

  blocTest<AssistantPanelBloc, AssistantPanelState>(
    '错误可重试:ErrorMsg 不删,重发最后 UserMsg 再走全流程(FR-1)',
    build: () => makeBloc(retryLoop),
    act: (b) async {
      b.add(const SendRequested('第一问'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      b.add(const RetryRequested());
      await Future<void>.delayed(const Duration(milliseconds: 20));
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [
      const AssistantPanelState(
        messages: [UserMsg('第一问')],
        sendState: PanelSendState.streaming,
      ),
      const AssistantPanelState(
        messages: [
          UserMsg('第一问'),
          AssistantMsg('部分回答'),
          ErrorMsg('LLM 请求失败(SocketException(localhost))', retryable: true),
        ],
        sendState: PanelSendState.error,
      ),
      const AssistantPanelState(
        messages: [
          UserMsg('第一问'),
          AssistantMsg('部分回答'),
          ErrorMsg('LLM 请求失败(SocketException(localhost))', retryable: true),
          UserMsg('第一问'),
        ],
        sendState: PanelSendState.streaming,
      ),
      const AssistantPanelState(
        messages: [
          UserMsg('第一问'),
          AssistantMsg('部分回答'),
          ErrorMsg('LLM 请求失败(SocketException(localhost))', retryable: true),
          UserMsg('第一问'),
          AssistantMsg('重试成功'),
        ],
        sendState: PanelSendState.idle,
      ),
    ],
    verify: (_) {
      // 重试 = 同文本再走一次 loop.send(全流程,非仅补帧)。
      expect(retryLoop.sentMessages, const ['第一问', '第一问']);
    },
  );

  blocTest<AssistantPanelBloc, AssistantPanelState>(
    '未启用引导:GuideMsg(notEnabled)+guideNotReady,零 LLM 调用(FR-1)',
    build: () => makeBloc(_guideLoop, config: const AssistantConfig()),
    act: (b) => b.add(const SendRequested('你好')),
    wait: const Duration(milliseconds: 20),
    expect: () => [
      const AssistantPanelState(
        messages: [UserMsg('你好'), GuideMsg(GuideKind.notEnabled)],
        sendState: PanelSendState.guideNotReady,
      ),
    ],
    verify: (_) {
      expect(_guideLoop.sentMessages, isEmpty); // 零 LLM 调用
    },
  );

  blocTest<AssistantPanelBloc, AssistantPanelState>(
    '模型未就绪引导:GuideMsg(modelNotReady),零 LLM 调用',
    build: () => makeBloc(_guideLoop, model: const ModelNotDownloaded()),
    act: (b) => b.add(const SendRequested('查净资产')),
    wait: const Duration(milliseconds: 20),
    expect: () => [
      const AssistantPanelState(
        messages: [UserMsg('查净资产'), GuideMsg(GuideKind.modelNotReady)],
        sendState: PanelSendState.guideNotReady,
      ),
    ],
    verify: (_) {
      expect(_guideLoop.sentMessages, isEmpty); // 零 LLM 调用
    },
  );

  blocTest<AssistantPanelBloc, AssistantPanelState>(
    '引擎冷启引导:EngineStarting → GuideMsg(engineStarting),零 LLM 调用',
    build: () => makeBloc(_guideLoop, engine: const EngineStarting()),
    act: (b) => b.add(const SendRequested('查净资产')),
    wait: const Duration(milliseconds: 20),
    expect: () => [
      const AssistantPanelState(
        messages: [UserMsg('查净资产'), GuideMsg(GuideKind.engineStarting)],
        sendState: PanelSendState.guideNotReady,
      ),
    ],
    verify: (_) {
      expect(_guideLoop.sentMessages, isEmpty); // 零 LLM 调用
    },
  );

  final resetLoop = _FakeLoop([
    Stream.fromIterable(const [TextDelta('第一答。'), Done()]),
  ]);

  blocTest<AssistantPanelBloc, AssistantPanelState>(
    '新对话:消息流清空回 idle,loop.resetConversation 被调(FR-4)',
    build: () => makeBloc(resetLoop),
    act: (b) async {
      b.add(const SendRequested('第一问'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      b.add(const NewConversationClicked());
      await Future<void>.delayed(const Duration(milliseconds: 20));
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [
      const AssistantPanelState(
        messages: [UserMsg('第一问')],
        sendState: PanelSendState.streaming,
      ),
      const AssistantPanelState(
        messages: [UserMsg('第一问'), AssistantMsg('第一答。')],
        sendState: PanelSendState.idle,
      ),
      const AssistantPanelState(messages: [], sendState: PanelSendState.idle),
    ],
    verify: (_) {
      expect(resetLoop.resetCount, 1);
    },
  );

  blocTest<AssistantPanelBloc, AssistantPanelState>(
    '会话保序:两轮发送的消息按时间序累积',
    build: () => makeBloc(
      _FakeLoop([
        Stream.fromIterable(const [TextDelta('第一答。'), Done()]),
        Stream.fromIterable(const [TextDelta('第二答。'), Done()]),
      ]),
    ),
    act: (b) async {
      b.add(const SendRequested('第一问'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      b.add(const SendRequested('第二问'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [
      const AssistantPanelState(
        messages: [UserMsg('第一问')],
        sendState: PanelSendState.streaming,
      ),
      const AssistantPanelState(
        messages: [UserMsg('第一问'), AssistantMsg('第一答。')],
        sendState: PanelSendState.idle,
      ),
      const AssistantPanelState(
        messages: [UserMsg('第一问'), AssistantMsg('第一答。'), UserMsg('第二问')],
        sendState: PanelSendState.streaming,
      ),
      const AssistantPanelState(
        messages: [
          UserMsg('第一问'),
          AssistantMsg('第一答。'),
          UserMsg('第二问'),
          AssistantMsg('第二答。'),
        ],
        sendState: PanelSendState.idle,
      ),
    ],
  );
}

/// 就绪引擎端点(值仅占位,bloc 只看状态类型)。
EngineState _engineReady() =>
    EngineReady(Uri.parse('http://127.0.0.1:18365/v1'));

/// 引导三态共用脚本(不应有任何 send 消费)。
final _FakeLoop _guideLoop = _FakeLoop(const []);

/// 脚本化 AgentLoopService:每次 send 依序消费一项脚本
/// (Stream<AssistantEvent> 回放),记录全部发送文本与 reset 次数。
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

  /// F70 ADR-2:port 新扩方法 —— fake 收集注入结果(bloc 侧 T2 才消费)。
  final appendedOutcomes = <String>[];

  @override
  void appendToolOutcome(String note) => appendedOutcomes.add(note);
}
