# Task Brief T1 — assistant/domain 契约层 + openai_dart 依赖

## 工作区与铁律

- **只在 worktree 工作**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r22-f64`(分支 feature/r22-f64 已就位,勿切分支勿动 main checkout)。所有 shell 命令先 `cd` 进 worktree 根。
- **TDD**:每个契约先写测试(RED)再实现(GREEN);实现一个文件立刻跑它的测试文件;禁止攒批。
- **不碰**:`yucai/server/`(零 diff)、`yucai/client/lib/core/llm/` 既有 F46 文件、其他模块文件、生成文件(.g.dart)。
- 完成后 `git add <相关文件> && git commit`(消息:`feat(assistant): F64-T1 domain 契约层+openai_dart 依赖`)。

## 必读(按序)

1. `docs/sydusx/products/yucai-client/release-r22-ai-assistant/sprint-1/f64-assistant-foundation/spec.md`(FR-1/FR-3/FR-4 场景)+ 同目录 `design.md`(HLD/LLD/ADR-4/ADR-5/ADR-6)
2. 仓库根 `AGENTS.md` + `CLAUDE.md`(约定)
3. `yucai/client/lib/core/llm/llm_settings.dart` —— **家法范本**(LlmConfig 值类型/LlmProvider/LlmEndpoints/copyWith/switch 表达式/doc comment 中文风格)
4. 既有测试风格参照:`yucai/client/test/` 下任一 core 测试(mocktail 用法)

## 任务

### 1. pubspec 依赖

`yucai/client/pubspec.yaml` dependencies 加 `openai_dart: ^11.0.0`,带中文注释一行(照 pub 内 F45 pdf 依赖注释先例:用途=OpenAI 兼容流式客户端+tool_calls 拼装,传递依赖 http/crypto/logging/meta 纯 Dart)。然后 `cd yucai/client && flutter pub get`。

### 2. domain 五文件(`yucai/client/lib/assistant/domain/`)

- **assistant_tool.dart**:
  - `abstract class AssistantTool { String get name; String get description; Map<String, Object> get parametersSchema; Future<ToolResult> execute(Map<String, Object> args); }`
  - `sealed class ToolResult`:`ToolData(Map<String, Object> json)` / `ToolError(String message)`(ToolError=可自纠信息,回传 LLM 让其改参重试)
- **tool_registry.dart**:`class AssistantToolRegistry`——`register(AssistantTool)`(重名→抛自解释 StateError,既有注册不受影响)/`AssistantTool? findByName(String)`/`List<AssistantTool> get all`/`List<Map<String, Object>> toOpenAiToolsSchema()`(每项 `{type: function, function: {name, description, parameters}}`;name 合法性断言 `[A-Za-z0-9_-]`,非法注册时抛错)
- **agent_loop.dart**:
  - `abstract class AgentLoopService { Stream<AssistantEvent> send(String userMessage); }`
  - `sealed class AssistantEvent`:`TextDelta(String delta)` / `ToolCallStart(String id, String name)` / `ToolCallEnd(String id, bool ok)` / `Done()` / `AssistantError(String message)`
  - LLM 流缝(供 data 层实现/mock):`abstract class LlmStreamClient { Stream<LlmChunk> chat(LlmChatRequest req); }`;`class LlmChatRequest { final String model; final List<Map<String, Object>> messages; final List<Map<String, Object>> toolsSchema; }`;`sealed class LlmChunk`:`TextChunk(String delta)` / `ToolCallDelta(int index, {String? id, String? name, String? argsDelta})` / `Finish(String reason)`
- **assistant_settings.dart**:`class AssistantConfig` 不可变+copyWith——字段 `{bool enabled=false; LlmProvider provider; String baseUrl=''; String apiKey=''; String model=''}`。**复用** `core/llm/llm_settings.dart` 的 `LlmProvider`/`LlmEndpoints`(不重复定义,单一事实源);`resolvedBaseUrl` 照 LlmConfig 逻辑(custom=trim 用户值,预设商=钉死)。**ready 规则(ADR-4,与 F46 不同)**:`enabled && resolvedBaseUrl 非空 && model 非空 && (apiKey.trim() 非空 || _isLocalhost)`,其中 `_isLocalhost`=Uri.parse(resolvedBaseUrl) 的 host ∈ {localhost, 127.0.0.1, ::1}(parse 抛异常→false)。
- **networth_port.dart**:`abstract class NetWorthSnapshotSource { Future<NetWorthView> fetch({required String baseCurrency}); }`——`NetWorthView` import `holding/domain/entities/net_worth_entity.dart`(跨模块 import domain 实体合法,照 AccountCloser 家法)。

### 3. 单测(`yucai/client/test/assistant/domain/`)

- registry:注册成功/OpenAI schema 序列化形状断言(含 type=function 嵌套)/重名抛错且旧表不受影响/非法 name 抛错
- AssistantConfig:ready 全分支(未启用/空端点/空 model/localhost 免 Key ready/localhost 带 Key/远端端点缺 Key not ready/预设商端点解析/custom trim)/copyWith
- 事件与 chunk 类型构造(轻)

## 验证门(过完才算完)

1. `cd yucai/client && flutter test test/assistant/` 全绿
2. `flutter analyze` —— 新文件零新增 info(基线 460,不许升)
3. `git diff yucai/server` 为空
4. 注释中文、日志/错误串 English 无 CJK(本任务无日志)

汇报:改动文件清单+测试输出摘要(通过数)+analyze 结果。
