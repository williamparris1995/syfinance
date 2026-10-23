# Task Brief T4 — LlmStreamClient 生产实现 + 审计日志

## 工作区与铁律

- **只在 worktree 工作**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r22-f64`(T1 的 domain 契约与 pubspec 的 openai_dart 已在)。shell 先 cd worktree 根。
- **TDD**;不碰 `yucai/server/`、F46 `core/llm/`、assistant/domain(契约已定不得改)。
- 完成 `git commit`(`feat(assistant): F64-T4 LlmStreamClient 实现+审计日志`)。

## 必读

1. 同目录 `design.md`(ADR-3/ADR-5,LLD audit 行格式)+`spec.md`(FR-5/NFR-3/NFR-4)
2. `yucai/client/lib/assistant/domain/agent_loop.dart`(LlmStreamClient/LlmChatRequest/LlmChunk 契约)+`assistant_settings.dart`(AssistantConfig)
3. `yucai/client/lib/report/data/llm/llm_mda_narrator.dart` —— 隐私红线家法(错误只含错误类+端点域名,零 Key 零 payload)
4. openai_dart 的 API:worktree `yucai/client/.dart_tool` 不用翻,直接看 pub cache 里 `openai_dart` 包源码(`flutter pub deps` 定位路径或 `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\openai_dart-11.*\lib\`),重点:`OpenAIClient` 构造(apiKey/baseUrl)、`chat.completions.createStream`(请求类型 ChatCompletionCreateParams:messages/tool 字段)、流事件类型(chat chunk:choices[].delta.content / delta.tool_calls[].{index,id,function.{name,arguments}} / finish_reason)

## 任务

### 1. `yucai/client/lib/assistant/data/llm_stream_client_impl.dart`

`@LazySingleton(as: LlmStreamClient)`。构造注入 **`AssistantConfig Function()` 配置取值缝**(T6 接线时绑 AssistantSettings.value;本任务不依赖 T2 的存在,单测直接传闭包)。每次 `chat()`:

- 读当前 config,构造 `OpenAIClient(apiKey: ..., baseUrl: resolvedBaseUrl)`;**apiKey 为空时传非空占位 'sk-noauth'**(localhost 端点不校验;避免空串断言炸),注释说明
- **纯映射函数(可单测,实现主体)**:
  - `ChatCompletionMessage messageFromMap(Map<String,Object>)`:role∈{system,user,assistant,tool};assistant 带 tool_calls(list of {id,type:function,function:{name,arguments}})时映射到对应 typed 变体;tool 带 tool_call_id+content;未知 role 抛自解释错误
  - `List<LlmChunk> chunksFromOpenAi(openai 流事件)`:delta.content→TextChunk;delta.tool_calls[i]→ToolCallDelta(index,id,function.name,function.arguments 增量);finish_reason→Finish(reason);usage/空 delta 忽略
  - `ChatCompletionCreateParams buildRequest(LlmChatRequest)`:model+messages 映射+tools(schema 已是 OpenAI 形状,直传)+streamOptions includeUsage
- 流包装:异常转 AssistantError 语义在 T5 处理——本层把异常**重抛为自解释格式**(类名+host,零 Key 零完整 body,照 F46 红线)
- 单测:三个映射函数的往返/边界(空 content、多 tool_call 分片按 index、非法 role、finish stop/tool_calls);不发真网络请求

### 2. `yucai/client/lib/assistant/data/audit_log.dart`

- `typedef AssistantLogFn = void Function(String line);`
- `@LazySingleton() class AssistantAuditLog`:构造 `{AssistantLogFn log = debugPrint}` 注入缝
- 方法:`logToolCall({required String name, required bool ok, required int ms, String argsSummary = ''})` → 行 `assistant tool=<name> status=<ok|error> ms=<n> args=<summary>`;`logLlm({required String host, required int ms, required String model})` → `assistant llm host=<host> ms=<n> model=<model>`
- **ASCII 强制**:argsSummary 过滤(非 ASCII 字符剔除),日志行构造后 assert 纯 ASCII;**红线:任何参数/Key 不得进入 argsSummary(调用方保证,类 doc 注释声明)**
- 单测:格式断言+ASCII 门(喂中文参数→输出纯 ASCII)+布尔/毫秒格式

## 验证门

`flutter test test/assistant/` 全绿;`flutter analyze` 零新增;`git diff yucai/server` 空。汇报:文件清单+测试数+openai_dart 映射的坑(若发现 API 与简报预期不符,写明实际形态)。
