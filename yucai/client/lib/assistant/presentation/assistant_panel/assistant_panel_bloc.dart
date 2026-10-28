/// F65 聊天 UI —— 会话面板状态机(FR-1/FR-4,ADR-2)。
///
/// 职责:订阅 [AgentLoopService] 事件流并编排为消息 view-model
/// (sealed [PanelMessage]);TextDelta 高频增量做 [frameInterval]
/// (默认 30ms)缓冲合帧防渲染卡顿(design Risk);发送前三重就绪守卫
/// (配置/模型/引擎冷启)不就绪给 [GuideMsg] 引导态,**零 LLM 调用**
/// (FR-1 未就绪引导场景);错误消息可重试(FR-1 错误可重试场景);
/// 「新对话」清空消息流并 reset loop 会话上下文(system prompt 重新注入,
/// FR-4 新对话重置场景)。
///
/// F70 确认门(FR-5/ADR-1/ADR-3/ADR-7):loop [WriteProposed] 特判 →
/// [WriteApprovalMsg] pending 卡(同刻单卡,旧 pending → superseded);
/// **实际落库唯一通道 = [WriteExecutor],仅 [ConfirmWriteRequested]/
/// [RetryWriteRequested] 两事件可达**(取消/替换/作废/未确认 = 状态守卫
/// 拒绝,零 executor 调用 —— 绕过负测钉死);确认成功卡转 confirmed +
/// 本地确认消息(executor 侧已另行 appendToolOutcome 注入 LLM 上下文);
/// 失败转 failed(幂等键不消耗,重试同 key 复用);新对话 = 待确认卡随
/// 清空作废,旧 key 确认 = 查无此卡被拒。
///
/// seam(全缝注入,DI 接线归 T3/T4):loop 事件流 + 配置/模型/引擎三个
/// 状态 [ValueListenable](发送时实时取值,不缓存不订阅)+ 合帧窗口
/// [frameInterval](测试注入 [Duration.zero])。流事件经内部事件
/// `add` 进队(bloc 事件队列天然保序),emit 只在 handler 内发生。
library;

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:yucai_client/account/domain/account_visibility.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/assistant/data/note_parser.dart';
import 'package:yucai_client/assistant/data/tools/tool_args.dart' show yuan;
import 'package:yucai_client/assistant/data/tools/transaction_add_tool.dart';
import 'package:yucai_client/assistant/data/tools/write_tool_support.dart'
    show writeActionFromJson;
import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart'
    show ToolData, ToolGuideHint;
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';
import 'package:yucai_client/assistant/domain/write_executor.dart';

// —— Event ——

/// 面板事件(公共三个 + 私有流转发/合帧内部事件)。
sealed class AssistantPanelEvent extends Equatable {
  const AssistantPanelEvent();
}

/// 用户发送一条消息。
class SendRequested extends AssistantPanelEvent {
  const SendRequested(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// 错误后重试:重发最后一条 UserMsg 的文本(历史不删错,追加新
/// UserMsg;FR-1「历史输入不丢」)。流式期间忽略(输入区禁用)。
class RetryRequested extends AssistantPanelEvent {
  const RetryRequested();

  @override
  List<Object?> get props => [];
}

/// 「新对话」:清空消息流 + reset loop 会话上下文(FR-4)。
class NewConversationClicked extends AssistantPanelEvent {
  const NewConversationClicked();

  @override
  List<Object?> get props => [];
}

/// F70 确认门:用户在 pending 确认卡上点「确认」([key] = 卡幂等键)。
/// **写执行唯一公共入口**(FR-5 代码门);非 pending 态卡(已取消/
/// 已替换/已作废/已确认/已失败)→ 守卫拒绝零执行。
class ConfirmWriteRequested extends AssistantPanelEvent {
  const ConfirmWriteRequested(this.key);

  final String key;

  @override
  List<Object?> get props => [key];
}

/// F70 确认门:用户取消 pending 确认卡(弃单;非 pending 态忽略)。
class CancelWriteRequested extends AssistantPanelEvent {
  const CancelWriteRequested(this.key);

  final String key;

  @override
  List<Object?> get props => [key];
}

/// F70 确认门:failed 卡重试 —— **幂等键复用**(执行失败不消耗键,
/// ADR-3;非 failed 态忽略)。
class RetryWriteRequested extends AssistantPanelEvent {
  const RetryWriteRequested(this.key);

  final String key;

  @override
  List<Object?> get props => [key];
}

/// F70-T3 引导卡:「换个账户试试」仅关闭卡(移除最后一张
/// [GuidanceMsg];无卡时静默忽略)。不触发任何 loop 调用。
class DismissGuidanceClicked extends AssistantPanelEvent {
  const DismissGuidanceClicked();

  @override
  List<Object?> get props => [];
}

/// F72-T2「以此再记一笔」(spec FR-4,design ADR-3/ADR-4):审计记行
/// 点击上抛的 note 串(「已记:支出 ¥35.00 午饭」)→ 解析三要素 → 经
/// transaction_add 工具 execute 全套(默认推导取名 + 名称→id 消歧,
/// ToolError 照常可出)→ pending 确认卡(**新 uuid 键**,NFR-1 零例外
/// —— 实际落库仍唯 ConfirmWrite 通道)。解析 null / 工具失败 →
/// [ErrorMsg]「无法从该记录生成提案」。
class ProposeFromHistoryRequested extends AssistantPanelEvent {
  const ProposeFromHistoryRequested(this.note);

  /// 审计行 summary(= executor 人话 note 单源串)。
  final String note;

  @override
  List<Object?> get props => [note];
}

/// 内部事件:loop 流 TextDelta 到达(仅入合帧缓冲)。
class _LoopTextDelta extends AssistantPanelEvent {
  const _LoopTextDelta(this.delta);

  final String delta;

  @override
  List<Object?> get props => [delta];
}

/// 内部事件:合帧定时器到点,请求把缓冲文本并入 AssistantMsg。
class _FlushFrame extends AssistantPanelEvent {
  const _FlushFrame();

  @override
  List<Object?> get props => [];
}

/// 内部事件:工具调用开始(先冲刷缓冲再插工具条,保会话时序)。
class _LoopToolCallStart extends AssistantPanelEvent {
  const _LoopToolCallStart(this.id, this.name);

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// 内部事件:工具调用结束([ok]=执行成功)。
class _LoopToolCallEnd extends AssistantPanelEvent {
  const _LoopToolCallEnd(this.id, this.ok);

  final String id;
  final bool ok;

  @override
  List<Object?> get props => [id, ok];
}

/// 内部事件:终答完成(正常收束)。
class _LoopDone extends AssistantPanelEvent {
  const _LoopDone();

  @override
  List<Object?> get props => [];
}

/// 内部事件:失败终态(用户态中文消息,直接入 ErrorMsg)。
class _LoopError extends AssistantPanelEvent {
  const _LoopError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// 内部事件:底层流闭合(正常路径已由 Done/Error 收口;此为防御终态
/// ——流意外截断时复位 busy,不悬挂在 streaming)。
class _LoopStreamClosed extends AssistantPanelEvent {
  const _LoopStreamClosed();

  @override
  List<Object?> get props => [];
}

/// 内部事件:loop 发出写提案(F70 ADR-1;→ pending 确认卡)。
class _LoopWriteProposed extends AssistantPanelEvent {
  const _LoopWriteProposed(this.proposal);

  final WriteProposed proposal;

  @override
  List<Object?> get props => [proposal];
}

/// 内部事件:loop 发出工具引导(F70-T3 v20 V4;→ 引导卡)。
class _LoopToolGuidance extends AssistantPanelEvent {
  const _LoopToolGuidance(this.guidance);

  final ToolGuidance guidance;

  @override
  List<Object?> get props => [guidance];
}

// —— 消息 view-model(sealed,presentation 内;ADR-2) ——

/// 面板消息渲染模型:穷尽分支由 T3 浮层消费。
sealed class PanelMessage extends Equatable {
  const PanelMessage();
}

/// 用户消息(输入原文)。
class UserMsg extends PanelMessage {
  const UserMsg(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// 助手消息(同段 TextDelta 合帧累积;工具条分隔出新段)。
class AssistantMsg extends PanelMessage {
  const AssistantMsg(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// 工具调用状态条:[ok]=null 执行中(「正在查询净资产…」)/ true 成功 /
/// false 自纠失败。ToolCallStart 插入、ToolCallEnd 原位更新。
class ToolStatusMsg extends PanelMessage {
  const ToolStatusMsg(this.name, {this.ok});

  final String name;

  /// 执行结果(null=进行中)。
  final bool? ok;

  @override
  List<Object?> get props => [name, ok];
}

/// 错误消息(loop AssistantError 转译;可重试 → UI 给重试入口)。
class ErrorMsg extends PanelMessage {
  const ErrorMsg(this.text, {required this.retryable});

  final String text;
  final bool retryable;

  @override
  List<Object?> get props => [text, retryable];
}

/// 引导态消息(未就绪,零 LLM 调用;FR-1 未就绪引导场景)。
class GuideMsg extends PanelMessage {
  const GuideMsg(this.kind);

  final GuideKind kind;

  @override
  List<Object?> get props => [kind];
}

/// 引导类型:未启用 / 模型未就绪(未下载完)/ 引擎冷启中。
enum GuideKind {
  /// 助手未启用(设置开「AI 助手」开关)。
  notEnabled,

  /// 模型未就绪(未下载/下载中/失败;引导查看下载进度)。
  modelNotReady,

  /// 引擎冷启动中(3-8s;渲染加载动效,F66 拍板)。
  engineStarting,
}

/// F70-T3 引导卡消息(v20 V4 查无实体引导;ADR-7 PanelMessage 新型态)。
/// 与 [GuideMsg](F65 未就绪引导)不同型:本型 = 写工具解析口述账户/分类名
/// 零命中(loop [ToolGuidance] 事件映射),卡片给「新建账户」跳转 +
/// 金额/账户参数行 + 「换个账户试试」关闭;LLM 文本澄清(ToolError 回填
/// 自纠)照常并存。
class GuidanceMsg extends PanelMessage {
  const GuidanceMsg({
    required this.text,
    required this.route,
    this.amountYuan,
    this.accountName,
  });

  /// 澄清文案(如「没有找到『滴滴』这个账户,要新建吗?」)。
  final String text;

  /// 主钮跳转目标(unknownAccount → `/accounts`;T1 查证无独立新建路由
  /// —— 账户创建 = 账户页内对话框,跳账户页即达,ADR-5)。
  final String route;

  /// 请求金额元串(v20 V4 参数行「金额 ¥12.00」;ToolGuidance.amountYuan
  /// 映射,评审 T3-M2;null/空 = 不出行)。
  final String? amountYuan;

  /// 零命中实体名(v20 V4 参数行「账户 滴滴(未找到)」;ToolGuidance
  /// .entityName 映射;null/空 = 不出行)。
  final String? accountName;

  @override
  List<Object?> get props => [text, route, amountYuan, accountName];
}

/// F70 写确认卡状态(v20 六形态数据面;ADR-7/FR-5)。
enum WriteApprovalStatus {
  /// 待确认(可确认/可取消;同刻仅一卡)。
  pending,

  /// 已确认且执行成功(终态;幂等键已消耗)。
  confirmed,

  /// 已取消(弃单终态)。
  cancelled,

  /// 被更新提案替换(终态;不可再确认)。
  superseded,

  /// 随「新对话」作废(实现语义 = 卡随消息流清空移除,旧 key 确认被
  /// 守卫拒绝;枚举值保留为状态词汇完整性,F71+ 会话持久化后可落卡面)。
  voided,

  /// 执行失败([WriteApprovalMsg.failureReason] 携单行原因;可重试,
  /// 幂等键复用 —— 失败不消耗键)。
  failed,
}

/// F70 写确认卡消息(PanelMessage 新型态,ADR-7;T3 渲染 v20 六形态)。
///
/// [idempotencyKey] = 确认实例 uuid(ADR-3;bloc 于 pending 建卡时生成,
/// 确认/重试共用 —— 执行器幂等集凭它去重);[action] = 解析后写操作;
/// [preview] = 工具预览摘要(名称展示;add 平铺 / update before+after /
/// delete 携 destructive)。
class WriteApprovalMsg extends PanelMessage {
  const WriteApprovalMsg({
    required this.idempotencyKey,
    required this.action,
    required this.preview,
    required this.status,
    this.failureReason,
  });

  final String idempotencyKey;
  final WriteAction action;
  final Map<String, Object> preview;
  final WriteApprovalStatus status;

  /// failed 态单行英文原因(WriteFailed.reason;其余态 null)。
  final String? failureReason;

  /// preview 不入 props:equatable 对 Map prop 走恒等比较(非深比较),
  /// 入 props 会破坏值相等;卡身份 = 幂等键 + 状态(preview 只读渲染源)。
  @override
  List<Object?> get props => [idempotencyKey, action, status, failureReason];

  /// 状态流转(离开 failed 时清 [failureReason])。
  WriteApprovalMsg copyWith({WriteApprovalStatus? status, String? failureReason}) =>
      WriteApprovalMsg(
        idempotencyKey: idempotencyKey,
        action: action,
        preview: preview,
        status: status ?? this.status,
        failureReason: status != null && status != WriteApprovalStatus.failed
            ? null
            : failureReason ?? this.failureReason,
      );
}

// —— State ——

/// 发送状态机:idle → streaming ⇄ awaitTool → idle | error;守卫不过
/// → guideNotReady(下次发送或新对话复位)。
enum PanelSendState { idle, streaming, awaitTool, error, guideNotReady }

/// 面板状态:消息列表 + 发送状态。
class AssistantPanelState extends Equatable {
  const AssistantPanelState({
    this.messages = const [],
    this.sendState = PanelSendState.idle,
  });

  final List<PanelMessage> messages;
  final PanelSendState sendState;

  /// 流式往返进行中(新发送/重试忽略,输入区禁用)。
  bool get isBusy =>
      sendState == PanelSendState.streaming ||
      sendState == PanelSendState.awaitTool;

  AssistantPanelState copyWith({
    List<PanelMessage>? messages,
    PanelSendState? sendState,
  }) => AssistantPanelState(
    messages: messages ?? this.messages,
    sendState: sendState ?? this.sendState,
  );

  @override
  List<Object?> get props => [messages, sendState];
}

// —— Bloc ——

/// 会话面板 bloc(ADR-2;DI 接线归 T3/T4,此处纯构造注入)。
class AssistantPanelBloc
    extends Bloc<AssistantPanelEvent, AssistantPanelState> {
  /// 构造注入全缝:[loop] 事件流;[config]/[modelState]/[engineState]
  /// 三个状态 ValueListenable(发送时实时取值 —— 设置卡改动即刻生效);
  /// [writeExecutor] 写执行器(F70 确认门唯一落库通道 —— 仅 Confirm/
  /// Retry 事件触达,代码门);[frameInterval] TextDelta 合帧窗口(默认
  /// 30ms,测试注入 [Duration.zero] 关离合帧);[addTool]/[accounts]
  /// F72「以此再记一笔」缝(可选 —— 缺省 null 特性惰性,既有装配零扰动)。
  AssistantPanelBloc({
    required this._loop,
    required this._config,
    required this._modelState,
    required this._engineState,
    required this._writeExecutor,
    this._addTool,
    this._accounts,
    this.frameInterval = const Duration(milliseconds: 30),
  }) : super(const AssistantPanelState()) {
    on<SendRequested>(_onSendRequested);
    on<RetryRequested>(_onRetryRequested);
    on<NewConversationClicked>(_onNewConversationClicked);
    on<ConfirmWriteRequested>(_onConfirmWriteRequested);
    on<CancelWriteRequested>(_onCancelWriteRequested);
    on<RetryWriteRequested>(_onRetryWriteRequested);
    on<DismissGuidanceClicked>(_onDismissGuidanceClicked);
    on<ProposeFromHistoryRequested>(_onProposeFromHistoryRequested);
    on<_LoopTextDelta>(_onLoopTextDelta);
    on<_FlushFrame>(_onFlushFrame);
    on<_LoopToolCallStart>(_onLoopToolCallStart);
    on<_LoopToolCallEnd>(_onLoopToolCallEnd);
    on<_LoopWriteProposed>(_onLoopWriteProposed);
    on<_LoopToolGuidance>(_onLoopToolGuidance);
    on<_LoopDone>(_onLoopDone);
    on<_LoopError>(_onLoopError);
    on<_LoopStreamClosed>(_onLoopStreamClosed);
  }

  final AgentLoopService _loop;
  final ValueListenable<AssistantConfig> _config;
  final ValueListenable<ModelState> _modelState;
  final ValueListenable<EngineState> _engineState;

  /// F70 写执行器缝(既有注入面扩一;绕过负测钉死其为唯一写通道)。
  final WriteExecutor _writeExecutor;

  /// F72「以此再记一笔」:提案工具(execute 全套解析/消歧复用;缺省
  /// null = 特性惰性 —— [ProposeFromHistoryRequested] 直落 ErrorMsg)。
  final TransactionAddTool? _addTool;

  /// F72「以此再记一笔」:默认推导取名所需的账户池(与工具同源 repo)。
  final AccountRepository? _accounts;

  /// TextDelta 合帧窗口(design Risk:30ms 高频渲染防卡顿)。
  final Duration frameInterval;

  StreamSubscription<AssistantEvent>? _subscription;

  /// 合帧缓冲:窗口内到达的连续 TextDelta 拼接为单次 AssistantMsg 增量。
  StringBuffer _frameBuffer = StringBuffer();
  Timer? _frameTimer;

  /// 进行中的工具条 id → 消息下标(ToolCallEnd 原位更新 ok)。
  final Map<String, int> _pendingToolCalls = {};

  Future<void> _onSendRequested(
    SendRequested event,
    Emitter<AssistantPanelState> emit,
  ) async {
    if (state.isBusy) return;
    final base = [...state.messages, UserMsg(event.text)];
    _dispatch(event.text, base, emit);
  }

  /// 重试:取最后一条 UserMsg 文本,历史保 ErrorMsg 之上追加新 UserMsg
  /// (不删错);再走全流程(守卫重新评估 —— 设置已修复时直接放行)。
  Future<void> _onRetryRequested(
    RetryRequested event,
    Emitter<AssistantPanelState> emit,
  ) async {
    if (state.isBusy) return;
    String? lastUserText;
    for (final message in state.messages) {
      if (message is UserMsg) lastUserText = message.text;
    }
    if (lastUserText == null) return;
    final base = [...state.messages, UserMsg(lastUserText)];
    _dispatch(lastUserText, base, emit);
  }

  /// 三重就绪守卫(FR-1 未就绪引导;顺序:配置 → 模型 → 引擎冷启):
  /// 任一不过 → GuideMsg + guideNotReady,**零 LLM 调用**(loop.send
  /// 不触达)。引擎仅 starting 拦截(Stopped/Error 由引擎侧 ensureReady
  /// 自愈,预热接线归 T3)。
  void _dispatch(
    String text,
    List<PanelMessage> base,
    Emitter<AssistantPanelState> emit,
  ) {
    if (!_config.value.ready) {
      _emitGuide(base, GuideKind.notEnabled, emit);
      return;
    }
    if (_modelState.value is! ModelReady) {
      _emitGuide(base, GuideKind.modelNotReady, emit);
      return;
    }
    if (_engineState.value is EngineStarting) {
      _emitGuide(base, GuideKind.engineStarting, emit);
      return;
    }
    emit(state.copyWith(messages: base, sendState: PanelSendState.streaming));
    _subscribe(text);
  }

  void _emitGuide(
    List<PanelMessage> base,
    GuideKind kind,
    Emitter<AssistantPanelState> emit,
  ) => emit(
    state.copyWith(
      messages: [...base, GuideMsg(kind)],
      sendState: PanelSendState.guideNotReady,
    ),
  );

  /// 订阅 loop 事件流,翻译为内部事件入队(bloc 队列保序 → 会话保序)。
  void _subscribe(String text) {
    _subscription?.cancel();
    _subscription = _loop
        .send(text)
        .listen(
          (event) {
            if (isClosed) return;
            switch (event) {
              case TextDelta(:final delta):
                add(_LoopTextDelta(delta));
              case ToolCallStart(:final id, :final name):
                add(_LoopToolCallStart(id, name));
              case ToolCallEnd(:final id, :final ok):
                add(_LoopToolCallEnd(id, ok));
              case WriteProposed():
                add(_LoopWriteProposed(event));
              case ToolGuidance():
                add(_LoopToolGuidance(event));
              case Done():
                add(const _LoopDone());
              case AssistantError(:final message):
                add(_LoopError(message));
            }
          },
          onError: (Object _) {
            // loop 契约保证终态事件;流级异常为防御路径(loop 不抛流错误)。
            if (!isClosed) add(const _LoopError('连接已中断,请重试'));
          },
          onDone: () {
            if (!isClosed) add(const _LoopStreamClosed());
          },
        );
  }

  /// 新对话:断流 + 清合帧/工具游标 + 清消息流 + reset loop 会话
  /// (system prompt 下次 send 重新注入,FR-4)。F70:待确认卡随消息流
  /// 清空而作废(FR-5「新对话作废」)—— 旧 key 的确认/取消/重试在空流
  /// 上查无此卡,守卫直接拒绝,**确认后也不再执行**。
  void _onNewConversationClicked(
    NewConversationClicked event,
    Emitter<AssistantPanelState> emit,
  ) {
    _teardownStream();
    _loop.resetConversation();
    emit(const AssistantPanelState());
  }

  // —— F70 确认门(FR-5;写执行唯一通道)——

  /// 写提案 → pending 确认卡:先冲刷合帧缓冲(提案前文本保持在前,
  /// 会话保序);同刻单卡 —— 既有 pending 卡转 [superseded](新写请求
  /// 替换旧的);新卡携新生幂等键(ADR-3)。不触 sendState(写确认与
  /// 流式往返独立,LLM 轮次照常收口)。
  void _onLoopWriteProposed(
    _LoopWriteProposed event,
    Emitter<AssistantPanelState> emit,
  ) =>
      _insertPendingCard(event.proposal.action, event.proposal.preview, emit);

  /// pending 确认卡插入公共体(F70 loop 提案 / F72 历史再记提案共用):
  /// 冲刷合帧缓冲 → 既有 pending 卡 superseded(同刻单卡)→ 追加新卡
  /// (**新生 uuid 幂等键**,ADR-3 / F72「新键」断言点)。
  void _insertPendingCard(
    WriteAction action,
    Map<String, Object> preview,
    Emitter<AssistantPanelState> emit,
  ) {
    final messages = _drainFrame(state.messages);
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (message is WriteApprovalMsg &&
          message.status == WriteApprovalStatus.pending) {
        messages[i] = message.copyWith(status: WriteApprovalStatus.superseded);
      }
    }
    messages.add(WriteApprovalMsg(
      idempotencyKey: const Uuid().v4(),
      action: action,
      preview: preview,
      status: WriteApprovalStatus.pending,
    ));
    emit(state.copyWith(messages: messages));
  }

  // —— F72-T2「以此再记一笔」(spec FR-4,design ADR-3/ADR-4)——

  /// 统一用户态失败文案(解析 null / 账户池读取失败 / 工具 ToolError
  /// 共用;不透传工具英文串 —— 此路径无 LLM 自纠回路,ToolError 即终态)。
  static const _reproposeFailedText = '无法从该记录生成提案';

  /// note → 三要素([AddActionFromNote.parse])→ 默认推导取名(ADR-3:
  /// 账户/分类不从 note 猜 —— 串中无)→ [TransactionAddTool.execute]
  /// 全套(日期缺省今天/金额元转 cents/名称→id 消歧,ToolError 照常可
  /// 出)→ pending 确认卡(**新键**,经正常确认门;本 handler 零
  /// executor 调用 —— NFR-1 点击本身零落库)。
  Future<void> _onProposeFromHistoryRequested(
    ProposeFromHistoryRequested event,
    Emitter<AssistantPanelState> emit,
  ) async {
    void fail() => emit(state.copyWith(
          messages: [
            ..._drainFrame(state.messages),
            const ErrorMsg(_reproposeFailedText, retryable: false),
          ],
        ));

    final draft = AddActionFromNote.parse(event.note);
    if (draft == null || _addTool == null || _accounts == null) return fail();

    // 默认推导(ADR-3「描述→分类/默认资产账户」的确定性形态):账户 =
    // 首个可见**资产**付款户(无资产户才落首个负债户),分类 = 方向匹配
    // 科目池首个 —— 推导差异由确认卡如实呈现,确认门兜底(design Risk
    // 钉定);池空 → 不传名,由工具出规范 ToolError(照常可出)。
    final listed = await _accounts.list();
    final accounts = listed.fold((l) => null, (r) => r);
    if (accounts == null) return fail();
    final visible = AccountVisibility.userVisible(accounts);
    final paymentPool = visible
        .where((a) =>
            a.accountType == AccountType.asset ||
            a.accountType == AccountType.liability)
        .toList();
    final categoryPool = visible
        .where((a) => draft.direction == WriteDirection.outflow
            ? a.accountType == AccountType.expense
            : a.accountType == AccountType.income)
        .toList();
    Account? account;
    for (final a in paymentPool) {
      if (a.accountType == AccountType.asset) {
        account = a;
        break;
      }
    }
    account ??= paymentPool.isEmpty ? null : paymentPool.first;

    final result = await _addTool.execute({
      'direction': draft.direction.wire,
      'amount': yuan(draft.amountCents), // 工具自源格式(千分位串)→ 精确回转 cents
      'description': draft.description,
      if (account != null) 'account': account.name,
      if (categoryPool.isNotEmpty) 'category': categoryPool.first.name,
    });
    if (result is! ToolData) return fail(); // ToolError → 统一文案

    // ToolData → WriteApproval(镜像 loop _writeProposalOf 形状;解析
    // 失败(requiresApproval/action 缺失)同落统一文案 —— 零卡零写)。
    if (result.json['requiresApproval'] != true) return fail();
    final actionJson = result.json['action'];
    if (actionJson is! Map) return fail();
    final action =
        writeActionFromJson(Map<String, Object>.from(actionJson));
    if (action == null) return fail();
    final rawPreview = result.json['preview'];
    final preview = rawPreview is Map
        ? Map<String, Object>.from(rawPreview)
        : const <String, Object>{};
    _insertPendingCard(action, preview, emit);
  }

  /// 确认 pending 卡 → 执行(唯一写路径;守卫:查无此卡/非 pending = 零执行)。
  Future<void> _onConfirmWriteRequested(
    ConfirmWriteRequested event,
    Emitter<AssistantPanelState> emit,
  ) => _executeWrite(event.key, emit, from: WriteApprovalStatus.pending);

  /// failed 卡重试 → 同幂等键再执行(失败不耗键,ADR-3;守卫:仅 failed)。
  Future<void> _onRetryWriteRequested(
    RetryWriteRequested event,
    Emitter<AssistantPanelState> emit,
  ) => _executeWrite(event.key, emit, from: WriteApprovalStatus.failed);

  /// 取消 pending 卡(弃单;守卫:非 pending 忽略 —— 已确认不可撤,已
  /// 替换/作废卡本就不可达)。**零 executor 调用**。
  void _onCancelWriteRequested(
    CancelWriteRequested event,
    Emitter<AssistantPanelState> emit,
  ) {
    final index = _cardIndex(event.key);
    if (index == null) return;
    final card = state.messages[index] as WriteApprovalMsg;
    if (card.status != WriteApprovalStatus.pending) return;
    final messages = List<PanelMessage>.of(state.messages);
    messages[index] = card.copyWith(status: WriteApprovalStatus.cancelled);
    emit(state.copyWith(messages: messages));
  }

  /// 写执行公共体([from] = 允许发起执行的卡状态:confirm=pending /
  /// retry=failed —— 其余任何状态零执行,FR-5 代码门)。
  ///
  /// 成功(WriteExecuted/AlreadyExecuted)→ 卡转 confirmed + 本地确认
  /// 消息(executor 侧已 appendToolOutcome 注入 LLM 上下文,此处补 UI
  /// 会话文案,ADR-2 双通道);失败 → 卡转 failed(reason 携单行原因,
  /// 幂等键保留供重试)。
  Future<void> _executeWrite(
    String key,
    Emitter<AssistantPanelState> emit, {
    required WriteApprovalStatus from,
  }) async {
    final index = _cardIndex(key);
    if (index == null) return;
    final card = state.messages[index] as WriteApprovalMsg;
    if (card.status != from) return;
    final outcome = await _writeExecutor.execute(card.action, key);
    if (isClosed) return;
    switch (outcome) {
      case WriteExecuted() || AlreadyExecuted():
        final messages = List<PanelMessage>.of(state.messages);
        messages[index] =
            (messages[index] as WriteApprovalMsg).copyWith(
              status: WriteApprovalStatus.confirmed,
            );
        emit(state.copyWith(
          messages: [...messages, AssistantMsg(_confirmLine(card))],
        ));
      case WriteFailed(:final reason):
        final messages = List<PanelMessage>.of(state.messages);
        messages[index] =
            (messages[index] as WriteApprovalMsg).copyWith(
              status: WriteApprovalStatus.failed,
              failureReason: reason,
            );
        emit(state.copyWith(messages: messages));
    }
  }

  /// 本地确认消息文案(中文紧凑单行;与 executor 注入 LLM 的 note 同
  /// 词汇同序:已记:方向 ¥额 描述 / 已改:描述 ¥额 / 已删:描述 ¥额)。
  static String _confirmLine(WriteApprovalMsg card) {
    Map<String, Object> section(String key) {
      final value = card.preview[key];
      return value is Map
          ? Map<String, Object>.from(value)
          : const <String, Object>{};
    }

    final preview = card.preview;
    String yuanOf(Object? v) =>
        '$v'.trim().isEmpty ? '' : '¥${'$v'.trim()}';
    String join(String head, List<Object?> parts) {
      final body = parts
          .map((p) => '$p'.trim())
          .where((p) => p.isNotEmpty)
          .join(' ');
      return body.isEmpty ? head : '$head:$body';
    }

    return switch (card.action) {
      TransactionAdd(:final direction, :final description) => join('已记', [
            direction == WriteDirection.outflow ? '支出' : '收入',
            yuanOf(preview['amountYuan']),
            description,
          ]),
      TransactionUpdate() => join('已改', [
            section('after')['description'],
            yuanOf(section('after')['amountYuan']),
          ]),
      TransactionDelete() => join('已删', [
            section('target')['description'],
            yuanOf(section('target')['amountYuan']),
          ]),
    };
  }

  /// 按幂等键定位确认卡下标(消息流为唯一事实源;查无 = 已随新对话清空
  /// 或从未存在 —— 守卫拒绝)。
  int? _cardIndex(String key) {
    for (var i = 0; i < state.messages.length; i++) {
      final message = state.messages[i];
      if (message is WriteApprovalMsg && message.idempotencyKey == key) {
        return i;
      }
    }
    return null;
  }

  // —— F70-T3 引导卡(V4 查无实体引导)——

  /// loop [ToolGuidance] → [GuidanceMsg]:先冲刷合帧缓冲(引导前文本保持
  /// 在前,会话保序)。unknown-account 唯一型 → 澄清文本 + 跳账户页
  /// (T1 查证无独立新建路由);实体名缺省 → 通用文案;金额/实体名随
  /// 事件透传(V4 参数行,评审 T3-M2)。不触 sendState(引导与流式往返
  /// 独立,LLM 轮次照常收口)。
  void _onLoopToolGuidance(
    _LoopToolGuidance event,
    Emitter<AssistantPanelState> emit,
  ) {
    final hint = event.guidance;
    final String text;
    switch (hint.hint) {
      case ToolGuideHint.unknownAccount:
        final name = hint.entityName.trim();
        text = name.isEmpty
            ? '没有找到该账户,要新建吗?'
            : '没有找到『$name』这个账户,要新建吗?';
    }
    final messages = _drainFrame(state.messages);
    messages.add(GuidanceMsg(
      text: text,
      route: '/accounts',
      amountYuan: _blankToNull(hint.amountYuan),
      accountName: _blankToNull(hint.entityName),
    ));
    emit(state.copyWith(messages: messages));
  }

  /// 空/白串 → null(参数行「空值不出行」口径的归一)。
  static String? _blankToNull(String? v) {
    final trimmed = v?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// 关闭引导卡(「换个账户试试」):移除最后一张 [GuidanceMsg]
  /// (照 [RetryRequested] 取最后 UserMsg 先例);无卡静默忽略。
  void _onDismissGuidanceClicked(
    DismissGuidanceClicked event,
    Emitter<AssistantPanelState> emit,
  ) {
    for (var i = state.messages.length - 1; i >= 0; i--) {
      if (state.messages[i] is GuidanceMsg) {
        final messages = List<PanelMessage>.of(state.messages)..removeAt(i);
        emit(state.copyWith(messages: messages));
        return;
      }
    }
  }

  /// TextDelta 只入缓冲;窗口内首个 delta 起表([frameInterval] 到点
  /// 冲刷一次 —— 窗口内后续 delta 静默合帧)。
  void _onLoopTextDelta(_LoopTextDelta event, Emitter<AssistantPanelState> _) {
    _frameBuffer.write(event.delta);
    _frameTimer ??= Timer(frameInterval, () {
      _frameTimer = null;
      if (!isClosed) add(const _FlushFrame());
    });
  }

  /// 定时器到点:缓冲并入 AssistantMsg(尾段是 AssistantMsg 则原位追加
  /// 增量,否则新开一段 —— 工具条后/错误后/新 UserMsg 后必然新段)。
  void _onFlushFrame(_FlushFrame event, Emitter<AssistantPanelState> emit) {
    if (_frameBuffer.isEmpty) return;
    emit(state.copyWith(messages: _drainFrame(state.messages)));
  }

  /// 工具条插入:先冲刷缓冲(工具调用前的文本保持在工具条之前,会话
  /// 保序),再插执行中状态条并转 awaitTool。
  void _onLoopToolCallStart(
    _LoopToolCallStart event,
    Emitter<AssistantPanelState> emit,
  ) {
    final messages = _drainFrame(state.messages);
    _pendingToolCalls[event.id] = messages.length;
    emit(
      state.copyWith(
        messages: [...messages, ToolStatusMsg(event.name)],
        sendState: PanelSendState.awaitTool,
      ),
    );
  }

  /// 工具条原位更新 ok(执行中 → 成功/失败),回 streaming 待终答。
  void _onLoopToolCallEnd(
    _LoopToolCallEnd event,
    Emitter<AssistantPanelState> emit,
  ) {
    final messages = _drainFrame(state.messages);
    final index = _pendingToolCalls.remove(event.id);
    if (index != null &&
        index < messages.length &&
        messages[index] is ToolStatusMsg) {
      messages[index] = ToolStatusMsg(
        (messages[index] as ToolStatusMsg).name,
        ok: event.ok,
      );
    }
    emit(
      state.copyWith(messages: messages, sendState: PanelSendState.streaming),
    );
  }

  /// 终答:冲刷尾段缓冲 → idle。
  void _onLoopDone(_LoopDone event, Emitter<AssistantPanelState> emit) {
    final messages = _drainFrame(state.messages);
    _teardownStream();
    emit(state.copyWith(messages: messages, sendState: PanelSendState.idle));
  }

  /// 失败终态:冲刷已到文本(不丢)→ 追加可重试 ErrorMsg(历史不删错,
  /// FR-1)。loop 错误消息已为用户态中文(含未启用拒跑文案),统一
  /// retryable —— 重试会重新过守卫,未启用类自然转为引导态。
  void _onLoopError(_LoopError event, Emitter<AssistantPanelState> emit) {
    final messages = _drainFrame(state.messages);
    _teardownStream();
    emit(
      state.copyWith(
        messages: [...messages, ErrorMsg(event.message, retryable: true)],
        sendState: PanelSendState.error,
      ),
    );
  }

  /// 防御终态:流闭合但无终态事件(契约外)→ 复位 busy。
  void _onLoopStreamClosed(
    _LoopStreamClosed event,
    Emitter<AssistantPanelState> emit,
  ) {
    _teardownStream();
    if (state.isBusy) {
      emit(state.copyWith(sendState: PanelSendState.idle));
    }
  }

  /// 冲刷合帧缓冲到 [base](不变更 state):尾段 AssistantMsg 原位追加,
  /// 否则新段。**恒返回新列表**(调用方在其上原位改写工具条 —— 不得与
  /// 既有 state 共享同一 List 实例,否则历史态被追溯改写)。
  List<PanelMessage> _drainFrame(List<PanelMessage> base) {
    final next = List<PanelMessage>.of(base);
    if (_frameBuffer.isEmpty) return next;
    final chunk = _frameBuffer.toString();
    _frameBuffer = StringBuffer();
    final last = next.isNotEmpty ? next.last : null;
    if (last is AssistantMsg) {
      next[next.length - 1] = AssistantMsg(last.text + chunk);
      return next;
    }
    next.add(AssistantMsg(chunk));
    return next;
  }

  void _teardownStream() {
    _subscription?.cancel();
    _subscription = null;
    _frameTimer?.cancel();
    _frameTimer = null;
    _pendingToolCalls.clear();
  }

  @override
  Future<void> close() {
    _teardownStream();
    return super.close();
  }
}

/// F72-T2「以此再记一笔」注入总线(design ADR-4;getIt 懒单例)。
///
/// 接线选型实录:bloc **非 getIt 注册** —— 生命周期由
/// [AssistantOverlayHost] 内建持有(浮层开合不销毁),对话框(设置卡
/// showDialog 弹出)经回调上抛至 host 的链路在现有装配下不可达(设置卡
/// 不持有 host 引用,对话框路由上下文亦寻不到 host state)。故取 ADR-4
/// 的 event-bus 分支:对话框直接 `getIt<AssistantReproposeInbox>.request`
/// 上抛 note → host 订阅转发 `bloc.add(ProposeFromHistoryRequested)` 并
/// 打开浮层(「若未开则 host 打开」)。last-wins(低频面;未消费请求
/// 被下一次覆盖),消费即清 —— host 每次通知取走全部。
class AssistantReproposeInbox extends ChangeNotifier {
  String? _pending;

  /// 待消费 note;无待消费 = null。
  String? get pending => _pending;

  /// 对话框记行点击上抛(串 = 审计行 summary 原样)。
  void request(String note) {
    _pending = note;
    notifyListeners();
  }

  /// host 消费:取走待处理 note 并清空(无则 null)。
  String? consume() {
    final note = _pending;
    _pending = null;
    return note;
  }
}
