# Design: F64 助手地基

prototype: none —— 无 UI 单元(纯服务层地基);F65 聊天 UI 时另走 OD 原型。

## Context

- spec:[spec.md](spec.md)(质询七决策);R22 release:[release.md](../../release.md);调研档案=项目记忆 ondevice-llm-voice-research。
- 代码基线:client DDD 四层+getIt/injectable;**local-first**(本地 Drift 为 UI 事实源);F46 先例=`core/llm/llm_settings.dart`(ValueNotifier+secure storage 家法)+`report/data/llm/llm_mda_narrator.dart`(注入缝+隐私红线+防御解析)。
- 数据源实证:`AccountRepository.list()`(domain port)/`DebtRepository.list()`(domain port,Debt entity 含 nextPaymentDate/nextPaymentAmountCents/nextPaymentDueDate)/`NetWorthLocalDataSource.getNetWorth()`(holding/data 具体类,纯本地三 DAO 汇总);AccountVisibility 载体户过滤在 account/domain。

## Goals / Non-Goals

- **Goals**:FR-1..5+NFR-1..5 全落——工具注册表/三只读工具/agent loop 事件流/AssistantSettings/审计日志;可测(mock 回放)。
- **Non-Goals**(照 spec Out of scope):UI/全量工具/端侧边车/语音/写操作/持久化/MCP/durable 审计表。

## Decisions(ADRs)

- **ADR-1 接口层=进程内工具注册表,不上 MCP** — rationale:应用内嵌助手第一方工具,行业共识 OpenAI tools JSON schema 直传 chat API;dart_mcp experimental。alternatives:MCP(外部宿主场景=R18)。grill:release 立项质询(spec Grill record 首行链)。
- **ADR-2 新建 `assistant` DDD 域模块;跨模块只 import domain port** — rationale:agent 语义是业务域非通用件;消费 account/debt 的既有 domain repository port,净资产按 AccountCloser 家法在 assistant/domain 补 `NetWorthSnapshotSource` port(DI 组合根适配 NetWorthLocalDataSource,assistant 不 import holding/data)。alternatives:塞 report/data/llm(语义不同模块膨胀)/core/llm 全包(core 只放通用件)。grill:HLD 结构轮(方案 A/B/C)。
- **ADR-3 流式客户端=引 `openai_dart` + port 隔离,不手写** — rationale:流式 SSE+tool_calls 分片拼装(ChatStreamAccumulator 内建)约 300 行协议代码量级,活跃维护(2026-10 v11.0.1)、MIT、纯 Dart 全平台、依赖干净(http/crypto/logging/meta 等,无 dio/freezed);assistant/domain 定义 `LlmStreamClient` port,openai_dart 仅出现在 assistant/data 生产 impl,mock 回放测试缝不变;F46 非流式旁白不动。alternatives:手写 dart:io(零依赖家法,但量级不同)/langchain(框架过重)/dart_openai(2025-02 弃维护)。grill:用户质询「有没有优秀第三方库」→调研四库定案。
- **ADR-4 AssistantSettings 独立家法镜像,ready 规则放宽** — rationale:照 LlmSettings 家法(ValueNotifier+secure storage)但独立 `assistant.*` keys、独立实体;**ready = enabled && 端点有效 && model 非空 && (apiKey 非空 || 端点 host 为 localhost/127.0.0.1)**——F46 ready 强制 apiKey 非空不可复用(零 Key 门槛 NFR)。F46 LlmSettings 零改动。grill:spec 挑战 1(端侧零配置)落 LLD。
- **ADR-5 事件流形状=sealed `AssistantEvent`** — rationale:`textDelta/toolCallStart/toolCallEnd/done/error` 五态,F65 直接渲染;loop 服务接口 `Stream<AssistantEvent>` 一次做对避免返工。grill:spec 挑战 3(流式进地基)。
- **ADR-6 工具结果=JSON 结构,金额双口径** — rationale:cents 整数+元两位小数字符串并给(LLM 数字精度+人类可读);列表=总额+top-N+total_count+分页(page_size 上限 50)。alternatives:纯文本(不可解析)/纯 cents(模型易错位)。
- **ADR-7 system prompt 逐字常量+澄清引导+外来数据定界** — rationale:NFR-3;查无实体→澄清建议话术(spec 挑战 6);银行备注/对方名以定界标记包成数据,不作为指令。
- **ADR-8 debts_list 字段策略 A** — rationale:执行期先真库断言验证 nextPayment* 三字段实填;缺则锁死 debt mapper 单点顺手补(工具口径正确性必需,非越界)。alternatives:B 降级(助手口径弱于页面,违 NFR-1 承诺)。grill:design 挑战 2,用户拍 A。

## HLD

```
lib/assistant/
  domain/
    assistant_tool.dart        // AssistantTool 抽象 + ToolResult + ToolContext
    tool_registry.dart         // AssistantToolRegistry(注册/分发/OpenAI schema 序列化)
    agent_loop.dart            // AgentLoopService port + AssistantEvent sealed + 会话态
    assistant_settings.dart    // AssistantConfig 值类型(ready 放宽规则)
    networth_port.dart         // NetWorthSnapshotSource port(跨模块,AccountCloser 家法)
  data/
    agent_loop_impl.dart       // 循环编排:openai_dart 流式往返+工具执行+自纠上限
    llm_stream_client_impl.dart// LlmStreamClient 生产 impl(包装 openai_dart)
    assistant_settings_store.dart // secure storage 持久化(家法镜像)
    audit_log.dart             // AssistantAuditLog(English 结构化,LogFn 注入缝)
    tools/
      networth_snapshot_tool.dart
      accounts_list_tool.dart
      debts_list_tool.dart
lib/core/llm/                  // 不动(F46 原样)
core/di/injection.dart         // 手工注册:NetWorthSnapshotSource 适配 + mock 绑定缝
```

依赖方向:domain ← data;assistant/data → openai_dart + account/debt domain port + core(localdb 间接);presentation 无。

接口契约(domain):

```dart
abstract class AssistantTool {
  String get name;             // 域前缀动词式,如 networth_snapshot
  String get description;      // 何时用/何时不用
  Map<String, Object> get parametersSchema;  // JSON Schema
  Future<ToolResult> execute(Map<String, Object> args);
}

sealed class ToolResult { class ToolData(Map<String,Object> json); class ToolError(String message); } // ToolError=可自纠回传 LLM

abstract class AgentLoopService {
  Stream<AssistantEvent> send(String userMessage);  // 内存态单会话
}

sealed class AssistantEvent { TextDelta; ToolCallStart; ToolCallEnd; Done; AssistantError; }

abstract class LlmStreamClient {
  Stream<LlmChunk> chat(LlmChatRequest req);  // openai_dart 仅在 impl 出现
}

abstract class NetWorthSnapshotSource {
  Future<NetWorthView> fetch({required String baseCurrency});  // NetWorthView 复用 holding/domain entity
}
```

## LLD

- **AgentLoopService.send 循环**(伪码):
  1. append user 消息;2. `LlmStreamClient.chat(messages+tools)` 订阅流;
  3. 文本 delta→`TextDelta`;tool_calls 累积完整→逐个 emit `ToolCallStart`→registry 分发 execute→`ToolCallEnd`;
  4. 工具结果以 tool role 回填(定界包装:NFR-3,外来字符串包 `<data>` 标记);
  5. 若本轮有 tool_calls→回到 2(同一请求内**自纠上限 3 轮**:连续 ToolError 达 3 → emit 失败终答并 Done);
  6. finishReason=stop→`Done`;异常→`AssistantError`(零 Key/零完整 payload,照 F46 红线:错误消息只含错误类+端点域名)。
  - 会话态:`List<Map<String,Object>> _messages` 内存持有(AssistantSettings 换端点不清空,F65 再议)。
- **AssistantConfig**:fields {enabled,provider,baseUrl,apiKey,model};keys `assistant.enabled/.provider/.base_url/.api_key/.model`;ready 规则照 ADR-4(localhost 判定:Uri.parse(host∈{localhost,127.0.0.1,::1}))。
- **三工具 schema/口径**:
  - networth_snapshot {}:→{totalAssetsCents, totalLiabilitiesCents, netWorthCents, currency, formatted:{...元字符串}, asOf:取数时刻}。baseCurrency 经 CurrencySettings.getBaseCurrency()(与 home 大卡同源)。
  - accounts_list {kind?, page?, page_size≤50}:AccountRepository.list()→AccountVisibility 过滤(载体户出局,total_count 不计)→按类分组汇总+每户{名称/类型/余额 cents+元};信用卡类挂卡贷占用:复用 **F50 占用派生口径**(卡欠款+Σ「计入开关开」挂接卡贷剩余本金)——执行期定位既有派生单元;若在 presentation 层则提为 account/domain 纯函数(小改,复用第一)。
  - debts_list {page?, page_size≤50}:DebtRepository.list(borrowedIn)→未结清过滤→每笔{counterparty/剩余本金 cents+元/nextPaymentAmountCents/nextPaymentDueDate/逾期标记(dueDate<今天)}+汇总(笔数/Σ剩余)。
- **audit**:line 格式 `assistant tool=<name> status=<ok|error> ms=<t> args=<摘要>` + `assistant llm host=<domain> ms=<t> model=<model>`;LogFn typedef 注入,生产=debugPrint(ASCII only,grep 门禁)。
- **测试缝**:LlmStreamClient mock 回放(预设 chunk 序列含 tool_calls 分片);工具单测直调;口径断言参数化全工具 vs repository 同库取数逐分。

## Risks / Trade-offs

- [国产端点 SSE 方言差异(智谱等)] → mock 回放钉标准 OpenAI 形状;执行期对智谱真端点冒烟一次;方言坑落 Open Questions 回填。
- [F50 占用派生位置不明] → 执行期定位;presentation 则提纯函数进 domain(小改)。
- [openai_dart 大版本演进(11.x 快节奏)] → pubspec 锁 `^11`;port 隔离使替换面=1 文件。
- [Debt mapper 缺 nextPaymentDueDate(R20 后续票线索)] → ADR-8 策略 A:真库断言先行,缺则 mapper 单点补。
- [自纠死循环] → 硬上限 3 + 每轮审计日志。

## Migration Plan

纯新增模块,零 drift 迁移、零 proto 改动、server 零 diff;AssistantSettings 新 secure-storage keys 与 F46 `llm.*` 并存互不影响。回滚=删模块+DI 行。

## Open Questions

- F50 占用派生当前落点(mapper/presentation)?——execute T1 定位回填此处。
- 智谱 `/v4` 流式 tool_calls 兼容性实测结果——execute 冒烟后回填。
