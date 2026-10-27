import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart' show ToolGuideHint;
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';
import 'package:yucai_client/assistant/domain/write_executor.dart';
import 'package:yucai_client/assistant/presentation/assistant_panel/assistant_panel_bloc.dart';

/// F65-T2:AssistantPanelBloc 单测(FR-1/FR-4,bloc_test 范式)——
/// 脚本化 AgentLoopService(零真实 LLM)+ ValueNotifier 三状态缝;
/// 合帧窗口注入 Duration.zero:同一微任务批内到达的连续 TextDelta
/// 在定时器冲刷前全部进缓冲 → 全量合并为单次 AssistantMsg 增量。
///
/// F70-T2 追加:确认门机制(FR-5)—— 计数型 fake WriteExecutor 钉死
/// **bloc→executor 唯一写通道**(提案到达/取消/替换/作废/重复确认全路径
/// 零 executor 调用;仅 ConfirmWrite/RetryWrite(且卡态守卫过)可达)。
/// 幂等键 bloc 内生成(uuid)—— F70 组用手动驱动 + 状态断言(键不可预知,
/// 从 state 读回再驱动)。
void main() {
  const readyConfig = AssistantConfig(enabled: true);

  AssistantPanelBloc makeBloc(
    _FakeLoop loop, {
    AssistantConfig config = readyConfig,
    ModelState model = const ModelReady(),
    EngineState? engine,
    _FakeWriteExecutor? writeExecutor,
  }) =>
      AssistantPanelBloc(
        loop: loop,
        config: ValueNotifier(config),
        modelState: ValueNotifier(model),
        engineState: ValueNotifier(engine ?? _engineReady()),
        writeExecutor:
            writeExecutor ?? _FakeWriteExecutor([const WriteExecuted('t')]),
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

  // —— F70 确认门(FR-5;四负测 = 幂等/作废/替换/绕过)——

  /// 写提案轮脚本:工具往返 + WriteProposed + 终答收口。
  Stream<AssistantEvent> proposalRound({
    String tool = 'transaction_add',
    WriteAction? action,
    Map<String, Object>? preview,
  }) =>
      Stream.fromIterable([
        ToolCallStart('call_w1', tool),
        const ToolCallEnd('call_w1', true),
        WriteProposed(tool, action ?? _addAction, preview ?? _addPreview),
        const TextDelta('已生成待确认操作。'),
        const Done(),
      ]);

  /// 现取唯一确认卡。
  WriteApprovalMsg cardOf(AssistantPanelBloc bloc) => bloc
      .state.messages
      .whereType<WriteApprovalMsg>()
      .reduce((a, b) => a.status == WriteApprovalStatus.pending ? a : b);

  test('绕过负测:提案到达只发 pending 卡,loop 流事件本身零 executor 调用',
      () async {
    final loop = _FakeLoop([proposalRound()]);
    final executor = _FakeWriteExecutor([const WriteExecuted('txn-1')]);
    final bloc = makeBloc(loop, writeExecutor: executor);

    bloc.add(const SendRequested('记一笔午饭 35 块'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final cards = bloc.state.messages.whereType<WriteApprovalMsg>().toList();
    expect(cards, hasLength(1));
    expect(cards.single.status, WriteApprovalStatus.pending,
        reason: 'WriteProposed → pending 确认卡');
    expect(cards.single.action, _addAction);
    expect(cards.single.idempotencyKey, isNotEmpty);
    // FR-5 代码门:工具直调/loop 流事件路径零写(T1 钉工具零写;此处钉
    // bloc 收到提案亦零执行 —— 唯一通道 = ConfirmWrite 事件)。
    expect(executor.calls, isEmpty, reason: '未确认零执行');
    expect(bloc.state.sendState, PanelSendState.idle,
        reason: '写确认不干扰流式收口');
    await bloc.close();
  });

  test('确认:executor.execute(action, key) 恰一次;卡 confirmed + 本地确认消息',
      () async {
    final loop = _FakeLoop([proposalRound()]);
    final executor = _FakeWriteExecutor([const WriteExecuted('txn-1')]);
    final bloc = makeBloc(loop, writeExecutor: executor);
    bloc.add(const SendRequested('记一笔午饭 35 块'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final key = cardOf(bloc).idempotencyKey;

    bloc.add(ConfirmWriteRequested(key));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(executor.calls, hasLength(1));
    expect(executor.calls.single.$1, _addAction, reason: '携提案 action');
    expect(executor.calls.single.$2, key, reason: '携卡幂等键');
    final card = bloc.state.messages.whereType<WriteApprovalMsg>().single;
    expect(card.status, WriteApprovalStatus.confirmed);
    expect(
      bloc.state.messages,
      contains(const AssistantMsg('已记:支出 ¥35.00 午饭')),
      reason: 'bloc 补本地确认消息文案(executor 已另行注 outcome)',
    );
    await bloc.close();
  });

  test('幂等负测:确认后再触发同 key 确认 → 状态守卫拒,executor 仍恰一次',
      () async {
    final loop = _FakeLoop([proposalRound()]);
    final executor = _FakeWriteExecutor([
      const WriteExecuted('txn-1'),
      const WriteExecuted('txn-should-not-run'),
    ]);
    final bloc = makeBloc(loop, writeExecutor: executor);
    bloc.add(const SendRequested('记'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final key = cardOf(bloc).idempotencyKey;

    bloc.add(ConfirmWriteRequested(key));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    bloc.add(ConfirmWriteRequested(key)); // 双击/重放
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(executor.calls, hasLength(1),
        reason: 'confirmed 卡不可再确认(bloc 侧守卫;executor 幂等集兜底)');
    await bloc.close();
  });

  test('取消:pending → cancelled 零执行;取消后确认 → 守卫拒零执行',
      () async {
    final loop = _FakeLoop([proposalRound()]);
    final executor = _FakeWriteExecutor([const WriteExecuted('txn-1')]);
    final bloc = makeBloc(loop, writeExecutor: executor);
    bloc.add(const SendRequested('记'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final key = cardOf(bloc).idempotencyKey;

    bloc.add(CancelWriteRequested(key));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
        bloc.state.messages.whereType<WriteApprovalMsg>().single.status,
        WriteApprovalStatus.cancelled);
    expect(executor.calls, isEmpty, reason: '取消零执行');

    bloc.add(ConfirmWriteRequested(key)); // 取消后确认 = 拒绝
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(executor.calls, isEmpty, reason: 'cancelled 卡不可确认(代码门)');
    await bloc.close();
  });

  test('替换负测:新提案替换旧 pending(→superseded);旧 key 确认零执行,'
      '新 key 可确认', () async {
    final loop = _FakeLoop([
      proposalRound(),
      proposalRound(tool: 'transaction_delete', action: _deleteAction,
          preview: _deletePreview),
    ]);
    final executor = _FakeWriteExecutor([const WriteExecuted('txn-2')]);
    final bloc = makeBloc(loop, writeExecutor: executor);
    bloc.add(const SendRequested('记'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final oldKey = cardOf(bloc).idempotencyKey;

    bloc.add(const SendRequested('把那笔删了')); // 第二轮提案
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final cards = bloc.state.messages.whereType<WriteApprovalMsg>().toList();
    expect(cards, hasLength(2));
    expect(
        cards.first.status, WriteApprovalStatus.superseded,
        reason: '同刻单卡:旧 pending 被替换');
    expect(cards.last.status, WriteApprovalStatus.pending);
    expect(cards.last.idempotencyKey, isNot(oldKey), reason: '新卡新键');

    bloc.add(ConfirmWriteRequested(oldKey));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(executor.calls, isEmpty, reason: 'superseded 卡不可确认');

    bloc.add(ConfirmWriteRequested(cards.last.idempotencyKey));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(executor.calls, hasLength(1), reason: '现行 pending 卡可确认');
    expect(
      bloc.state.messages,
      contains(const AssistantMsg('已删:美团买菜 ¥30.00')),
    );
    await bloc.close();
  });

  test('作废负测:新对话后旧 key 确认 → 查无此卡守卫拒,零执行',
      () async {
    final loop = _FakeLoop([proposalRound()]);
    final executor = _FakeWriteExecutor([const WriteExecuted('txn-1')]);
    final bloc = makeBloc(loop, writeExecutor: executor);
    bloc.add(const SendRequested('记'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final key = cardOf(bloc).idempotencyKey;

    bloc.add(const NewConversationClicked());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.messages, isEmpty, reason: '待确认卡随清空作废(FR-5)');
    expect(loop.resetCount, 1);

    bloc.add(ConfirmWriteRequested(key));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(executor.calls, isEmpty,
        reason: '作废后确认也不再执行(卡已不存在)');
    expect(bloc.state.messages, isEmpty);
    await bloc.close();
  });

  test('失败与重试:WriteFailed → failed(reason);RetryWrite 同 key 复用'
      '(失败不耗键)→ 成功 confirmed', () async {
    final loop = _FakeLoop([proposalRound()]);
    final executor = _FakeWriteExecutor([
      const WriteFailed('versionConflict'),
      const WriteExecuted('txn-1'),
    ]);
    final bloc = makeBloc(loop, writeExecutor: executor);
    bloc.add(const SendRequested('改一下'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final key = cardOf(bloc).idempotencyKey;

    bloc.add(ConfirmWriteRequested(key));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    var card = bloc.state.messages.whereType<WriteApprovalMsg>().single;
    expect(card.status, WriteApprovalStatus.failed);
    expect(card.failureReason, 'versionConflict');

    bloc.add(RetryWriteRequested(key));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(executor.calls, hasLength(2), reason: '重试真实再执行');
    expect(executor.calls[0].$2, key);
    expect(executor.calls[1].$2, key,
        reason: '幂等键复用 —— 失败不消耗键(ADR-3)');
    card = bloc.state.messages.whereType<WriteApprovalMsg>().single;
    expect(card.status, WriteApprovalStatus.confirmed);
    expect(card.failureReason, isNull, reason: '离开 failed 清原因');
    await bloc.close();
  });

  test('AlreadyExecuted 回放也收口 confirmed(执行器幂等命中不算失败)',
      () async {
    final loop = _FakeLoop([proposalRound()]);
    final executor =
        _FakeWriteExecutor([const AlreadyExecuted('txn-1')]);
    final bloc = makeBloc(loop, writeExecutor: executor);
    bloc.add(const SendRequested('记'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    bloc.add(ConfirmWriteRequested(cardOf(bloc).idempotencyKey));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
        bloc.state.messages.whereType<WriteApprovalMsg>().single.status,
        WriteApprovalStatus.confirmed);
    await bloc.close();
  });

  test('未知 key 确认/取消/重试:静默忽略零执行零状态变化', () async {
    final loop = _FakeLoop([proposalRound()]);
    final executor = _FakeWriteExecutor([const WriteExecuted('txn-1')]);
    final bloc = makeBloc(loop, writeExecutor: executor);
    bloc.add(const SendRequested('记'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final before = bloc.state;

    bloc
      ..add(const ConfirmWriteRequested('no-such-key'))
      ..add(const CancelWriteRequested('no-such-key'))
      ..add(const RetryWriteRequested('no-such-key'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(executor.calls, isEmpty);
    expect(bloc.state.messages, before.messages);
    await bloc.close();
  });

  // —— F70-T3 引导卡(V4 查无实体引导;bloc 映射面)——

  /// unknown-account 引导轮脚本:工具失败 + 引导事件 + LLM 文本澄清收口。
  Stream<AssistantEvent> guidanceRound() => Stream.fromIterable(const [
        ToolCallStart('call_g1', 'transaction_add'),
        ToolCallEnd('call_g1', false),
        ToolGuidance(ToolGuideHint.unknownAccount, '滴滴'),
        TextDelta('没有找到「滴滴」这个账户,要新建吗?'),
        Done(),
      ]);

  test('unknown-account 引导映射:ToolGuidance → GuidanceMsg(text+route);'
      'LLM 文本澄清照常并存', () async {
    final loop = _FakeLoop([guidanceRound()]);
    final executor = _FakeWriteExecutor([const WriteExecuted('txn-1')]);
    final bloc = makeBloc(loop, writeExecutor: executor);

    bloc.add(const SendRequested('记一笔打车 12 块,滴滴账户'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final guidance = bloc.state.messages.whereType<GuidanceMsg>().single;
    expect(guidance.text, '没有找到『滴滴』这个账户,要新建吗?');
    expect(guidance.route, '/accounts',
        reason: 'T1 查证无 /accounts/new 独立路由 → 跳账户页(页面内建户)');
    // v20 V4:LLM 文本澄清(bot 消息)与引导卡并存,两通道独立。
    expect(
      bloc.state.messages,
      contains(const AssistantMsg('没有找到「滴滴」这个账户,要新建吗?')),
    );
    expect(bloc.state.messages.whereType<WriteApprovalMsg>(), isEmpty,
        reason: '查无账户不产生确认卡(不静默代建)');
    expect(executor.calls, isEmpty, reason: '引导路径零执行');
    await bloc.close();
  });

  test('entityName 缺省防御:空名 → 通用澄清文案(不出现『』空壳)', () async {
    final loop = _FakeLoop([
      Stream.fromIterable(const [
        ToolCallStart('call_g2', 'transaction_update'),
        ToolCallEnd('call_g2', false),
        ToolGuidance(ToolGuideHint.unknownAccount, ''),
        Done(),
      ]),
    ]);
    final bloc = makeBloc(loop);
    bloc.add(const SendRequested('改一下'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      bloc.state.messages.whereType<GuidanceMsg>().single.text,
      '没有找到该账户,要新建吗?',
    );
    await bloc.close();
  });

  test('DismissGuidanceClicked:移除最后一张引导卡;再点(无卡)静默忽略',
      () async {
    final loop = _FakeLoop([guidanceRound()]);
    final bloc = makeBloc(loop);
    bloc.add(const SendRequested('记一笔打车 12 块,滴滴账户'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state.messages.whereType<GuidanceMsg>(), hasLength(1));

    bloc.add(const DismissGuidanceClicked());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.messages.whereType<GuidanceMsg>(), isEmpty,
        reason: '「换个账户试试」仅关闭卡');
    expect(bloc.state.messages.whereType<AssistantMsg>(), isNotEmpty,
        reason: '会话其余消息保留');

    final before = bloc.state;
    bloc.add(const DismissGuidanceClicked());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.messages, before.messages, reason: '无卡时零变化');
    await bloc.close();
  });
}

/// 就绪引擎端点(值仅占位,bloc 只看状态类型)。
EngineState _engineReady() =>
    EngineReady(Uri.parse('http://127.0.0.1:18365/v1'));

/// F70 提案 fixture:记一笔午饭 35 元(内部 id 已解析形状)。
final _addAction = TransactionAdd(
  direction: WriteDirection.outflow,
  amountCents: 3500,
  description: '午饭',
  accountId: 'acc-cash',
  categoryId: 'acc-food',
  date: DateTime(2026, 10, 27),
);

const _addPreview = {
  'direction': 'out',
  'amountCents': 3500,
  'amountYuan': '35.00',
  'description': '午饭',
  'account': '现金',
  'category': '餐饮',
  'date': '2026-10-27',
};

/// F70 提案 fixture:删一笔美团买菜。
const _deleteAction = TransactionDelete(transactionId: 'txn-9');

const _deletePreview = {
  'destructive': true,
  'target': {
    'date': '2026-10-05',
    'description': '美团买菜',
    'direction': 'out',
    'amountCents': 3000,
    'amountYuan': '30.00',
    'account': '现金',
    'category': '餐饮',
  },
};

/// 计数型 fake WriteExecutor:脚本化逐调用回放结果,记录全部
/// (action, key) 调用 —— 绕过负测的断言面(任何路径多出一次调用即红)。
class _FakeWriteExecutor implements WriteExecutor {
  _FakeWriteExecutor(this._outcomes);

  final List<WriteOutcome> _outcomes;
  final List<(WriteAction, String)> calls = [];
  int _next = 0;

  @override
  Future<WriteOutcome> execute(
      WriteAction action, String idempotencyKey) async {
    calls.add((action, idempotencyKey));
    return _next < _outcomes.length
        ? _outcomes[_next++]
        : const WriteExecuted('txn-fallback');
  }
}

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
