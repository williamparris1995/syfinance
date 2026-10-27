/// F64 助手地基 —— agent loop 契约(FR-3/ADR-3/ADR-5)。
///
/// 服务接口形状为事件流(五态 sealed [AssistantEvent],F65 直接渲染);
/// LLM 访问经 [LlmStreamClient] port 隔离 —— openai_dart 仅在
/// assistant/data 生产 impl 出现,mock 回放测试缝不变(NFR-4)。
library;

import 'assistant_tool.dart' show ToolGuideHint;
import 'write_action.dart';

/// agent loop 服务 port(单轮:追加 user 消息 → 驱动 LLM↔工具多轮循环
/// → 终答;内存态单会话消息序列,跨会话持久化不在本票)。
abstract class AgentLoopService {
  /// 发送一条用户消息并流式返回助手事件。
  ///
  /// 未启用(AssistantConfig not ready)→ 仅发 [AssistantError](自解释
  /// 「未启用」,零网络请求,FR-4;文案不含「端点」词汇,评审 T3-M1);
  /// 循环编排细节见 T2 impl。
  Stream<AssistantEvent> send(String userMessage);

  /// 清空内存会话(F65「新对话」,FR-4):丢弃全部历史上下文;下次
  /// [send] 重新注入 system prompt(队首插入一次)。
  void resetConversation();

  /// 确认执行结果注入会话(F70 ADR-2):以 tool role **紧凑单行**消息把
  /// 写操作确认执行结果(如「已记:支出 35.00 午饭 招行卡」的英文单行
  /// note)追加进内存会话 —— 后续对话 LLM 知晓已记账;**不触发任何流**,
  /// 仅等下次 [send] 随历史可见。「新对话」[resetConversation] 一并清空
  /// (待确认作废口径同源)。调用方保证 note 单行紧凑(上下文膨胀防线)。
  void appendToolOutcome(String note);
}

/// 助手事件五态(ADR-5;sealed,消费方穷尽分支)。
sealed class AssistantEvent {
  const AssistantEvent();
}

/// 文本增量(流式拼接;零散分片由消费方按序累加)。
class TextDelta extends AssistantEvent {
  const TextDelta(this.delta);

  final String delta;
}

/// 工具调用开始:LLM 发起一次 tool_call([id]/[name] 已拼装完整)。
class ToolCallStart extends AssistantEvent {
  const ToolCallStart(this.id, this.name);

  final String id;
  final String name;
}

/// 工具调用结束([ok]=执行成功;false=自纠错误已回传 LLM)。
class ToolCallEnd extends AssistantEvent {
  const ToolCallEnd(this.id, this.ok);

  final String id;
  final bool ok;
}

/// 写提案(F70 ADR-1/ADR-7,FR-5 确认门):写工具返回
/// `requiresApproval:true` ToolData 时,在 [ToolCallEnd] 后随流发出 ——
/// 携解析后的 typed [action](内部 id 已钉定)与 [preview](确认卡渲染
/// 数据,T3 消费)。bloc 特判此事件渲染 pending 确认卡;**实际落库唯一
/// 入口 = WriteExecutor.execute,仅 bloc 确认回调可达** —— 本事件只是
/// 提案通知,零写副作用。action JSON 解析失败 → 不发(降级为普通工具
/// 结果:零卡零写,代码门「无卡即无执行」)。
class WriteProposed extends AssistantEvent {
  const WriteProposed(this.toolName, this.action, this.preview);

  /// 提案工具名(transaction_add/update/delete;审计与卡片语境用)。
  final String toolName;

  /// 解析后的写操作(名称→内部 id 于提案时钉定)。
  final WriteAction action;

  /// 预览摘要(名称展示;update 为 before/after,delete 携 destructive)。
  final Map<String, Object> preview;
}

/// 工具引导(F70-T3,v20 V4 查无实体引导):写工具解析口述账户名零命中
/// 时,ToolError 携 [ToolGuideHint.unknownAccount] 结构标记 —— loop 在
/// [ToolCallEnd] 后旁路发本事件(bloc 映射 GuidanceMsg 渲染引导卡);
/// 错误本身照常回填 LLM 自纠,LLM 文本澄清与引导卡两通道并存(ADR-4)。
class ToolGuidance extends AssistantEvent {
  const ToolGuidance(this.hint, this.entityName);

  /// 引导判型(结构标记,不猜文案)。
  final ToolGuideHint hint;

  /// 引导实体名(如零命中的账户名;可能为空串,消费方兜底通用文案)。
  final String entityName;
}

/// 终答完成(正常收束)。
class Done extends AssistantEvent {
  const Done();
}

/// 失败终态(自解释错误(用户态中文消息,ADR-006;不进日志串),零 Key/零完整 payload —— 照 F46 红线)。
class AssistantError extends AssistantEvent {
  const AssistantError(this.message);

  final String message;
}

/// LLM 流式客户端 port(ADR-3:data 层以 openai_dart 实现,单测以
/// 预设 chunk 序列回放 —— 无真实网络)。
abstract class LlmStreamClient {
  /// 发起一次 chat completions 流式请求,按序产出规范化分片。
  Stream<LlmChunk> chat(LlmChatRequest req);
}

/// 单次 chat 请求(messages/toolsSchema 为 OpenAI 兼容原始 map 形状,
/// 由 impl 直接交给 openai_dart;domain 不依赖具体协议类型)。
class LlmChatRequest {
  const LlmChatRequest({
    required this.model,
    required this.messages,
    required this.toolsSchema,
  });

  /// 模型名(如 glm-4-plus;来自 AssistantConfig.model)。
  final String model;

  /// 会话消息序列(role/content/tool_calls/tool_call_id 等)。
  final List<Map<String, Object>> messages;

  /// 工具 schema 数组(AssistantToolRegistry.toOpenAiToolsSchema 输出)。
  final List<Map<String, Object>> toolsSchema;
}

/// LLM 流式分片(三态;SSE 解析与 tool_calls 分片拼装由 data 层完成,
/// 此处为拼装前的规范化增量)。
sealed class LlmChunk {
  const LlmChunk();
}

/// 文本增量分片。
class TextChunk extends LlmChunk {
  const TextChunk(this.delta);

  final String delta;
}

/// tool_calls 增量分片(同一 [index] 归并拼装;首轮分片带 [id]/[name],
/// 后续只带 [argsDelta] JSON 片段 —— OpenAI 流式协议形状)。
class ToolCallDelta extends LlmChunk {
  const ToolCallDelta(this.index, {this.id, this.name, this.argsDelta});

  final int index;
  final String? id;
  final String? name;
  final String? argsDelta;
}

/// 轮次结束(reason:stop / tool_calls / length / ...)。
class Finish extends LlmChunk {
  const Finish(this.reason);

  final String reason;
}
