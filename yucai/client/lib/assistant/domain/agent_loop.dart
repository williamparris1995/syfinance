/// F64 助手地基 —— agent loop 契约(FR-3/ADR-3/ADR-5)。
///
/// 服务接口形状为事件流(五态 sealed [AssistantEvent],F65 直接渲染);
/// LLM 访问经 [LlmStreamClient] port 隔离 —— openai_dart 仅在
/// assistant/data 生产 impl 出现,mock 回放测试缝不变(NFR-4)。
library;

/// agent loop 服务 port(单轮:追加 user 消息 → 驱动 LLM↔工具多轮循环
/// → 终答;内存态单会话消息序列,跨会话持久化不在本票)。
abstract class AgentLoopService {
  /// 发送一条用户消息并流式返回助手事件。
  ///
  /// 未配置端点(AssistantConfig not ready)→ 仅发 [AssistantError]
  /// (自解释「未配置」,零网络请求,FR-4);循环编排细节见 T2 impl。
  Stream<AssistantEvent> send(String userMessage);
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
