# F64 code-ledger

> /sydusx-execute 任务台账(task done / fix-rounds / rulings)。评审批次说明:T2/T3/T4 评审合并一轮(data 层三 diff 联评,T1 已单独评)。

- **T1 domain 契约层 ✅ done**(commit 57aad7c5;33 测;analyze 459 零新增;server diff 空) — 评审 **PASS**(2026-10-23,零 High/Medium)。fix-rounds 0。parked:L-1 domain 经 core/llm 传递拉 Flutter 依赖(复用单源 vs domain 纯度两难,后续票把 LlmProvider/LlmEndpoints 提纯 Dart 文件);L-2 pubspec 注释传递依赖枚举可补「等」。ruling:均 Low 可延,F65 前提取票候选。
- **T2 AssistantSettings 存储 ✅ done**(commit fbcba729;8 测;关键差异断言 localhost 免 Key 助手档 ready vs F46 not-ready 已钉) — 评审并入 T3/T4 批次(待)。
- **T3 三只读工具 ✅ done**(commit 7dc8a10a) — 评审并入 T3/T4 批次(记录于上)。
- **T4 LlmStreamClient+审计 ✅ done**(commit da8b9811) — 评审并入 T3/T4 批次(记录于上)。
- **T5 agent loop 编排+回放集成测试 ✅ done**(commit 38e146a7)。
- **design.md 漂移修正**:HLD 树注释 ToolContext 字样移除(T1 评审 Low-3,控制器顺手修文档,非实现)。
- **T6 DI 接线+全门+需求覆盖 ✅ done**(2026-10-23)— 接线四件全落:**(1)** `AssistantConfig Function()` 取值缝照 1j LlmHttpFn 先例手工注册(injection.dart 1m 段),工厂 = `getIt<AssistantSettings>().value`,端点热切换即时生效;**(2)** `NetWorthSnapshotSourceAdapter`(新文件 `core/di/networth_snapshot_source_adapter.dart`,照 GrpcClient 手工注册先例;落组合根而非 assistant/data —— 适配必 import holding/data,ADR-2 禁 assistant import 生产方)委托既有 `NetWorthLocalDataSource.getNetWorth`;**(3)** 三工具启动注册集中 injection.dart 2g 一段(registry 单例 + networth_snapshot/accounts_list/debts_list,依赖均为既有注册件);**(4)** `AssistantSettings.load()` 挂 bootstrap 2f(F46 LlmSettings.load 同位,注入 1a 共享 secure-storage 单例)。**build_runner 坑(重要)**:regen 失败 —— injectable_generator 无法解析 impl 构造参数的内联函数类型 `AssistantConfig Function()`(报 "Can not resolve function type, try using an alias"),且失败 run 会半写 config(AssistantAuditLog 被生成为 `gh<AssistantLogFn>()` 未注册死引用)+波及 17 个 drift .g.dart;已全部回滚,按 CLAUDE.md 手工兜底先例全手工注册(code-plan T6 本即规划「core/di 手工注册 LlmStreamClient/AgentLoopService 绑定」,T4/T5 代码注释同款口径)。**遗留(非阻塞)**:T2/T4/T5 的 @LazySingleton 注解因此进不了生成图(现状 inert 文档位);未来若要走 regen,需先把两 impl 的内联函数参数改为命名 typedef(如 `typedef AssistantConfigFn = AssistantConfig Function()`)并删除本段手工注册,否则双注册冲突 —— 已在 injection.dart 1m 注释记档。**全门**:flutter test 2961 全绿(main 基线 2849 + assistant 112);analyze 459 = 基线零新增(assistant/core-di 文件零 issue);`git diff main -- yucai/server` 0 字节;server 子目录 git status 干净。零 BLOCKED。

## 需求覆盖对照表(T6;spec FR/NFR ↔ 测试)

| 需求 | 场景 | 测试文件(`yucai/client/test/assistant/`) | 用例名 |
| --- | --- | --- | --- |
| FR-1 工具注册表 | 序列化为 OpenAI tools | `domain/tool_registry_test.dart` | `serializes each tool to OpenAI tools function shape` / `output is valid JSON (spec FR-1 序列化场景)` |
| FR-1 工具注册表 | 重名注册拒绝 | `domain/tool_registry_test.dart` | `duplicate name throws self-explaining error, registry unchanged` / `invalid tool name is rejected` |
| FR-2 三只读工具 | 净资产快照逐分一致 | `data/tools/tools_caliber_test.dart` + `data/tools/networth_snapshot_tool_test.dart` | `parameterized: every tool cent-exact vs same-db direct recomputation` / `execute: dual caliber cents + yuan strings, currency, asOf ISO8601` |
| FR-2 三只读工具 | 载体户不可见 | `data/tools/accounts_list_tool_test.dart` + `data/tools/tools_caliber_test.dart` | `carrier account excluded from items and total_count` / `carrier account invisible in accounts_list on the shared fixture` |
| FR-2 三只读工具 | 欠款为正 | `data/tools/debts_list_tool_test.dart` | `credit-positive invariant: every remaining principal > 0` |
| FR-3 agent loop | 工具往返闭环 | `data/agent_loop_impl_test.dart` | `工具往返闭环:文本→tool_call→工具→文本→Done(FR-3)` / `同轮并行 tool_calls 按 index 归并,逐个执行并回填` |
| FR-3 agent loop | 工具错误自纠有上限 | `data/agent_loop_impl_test.dart` | `错误自纠:ToolError 回传→改参重试成功(FR-3)` / `连续失败上限 3:终止并给失败终态,无 Done(FR-3)` / `未知工具名:ToolError 列出可用工具,下轮正常收尾` |
| FR-3 agent loop | 查无实体转澄清 | `data/agent_loop_impl_test.dart` | `system prompt 逐字常量:同一引用+五要素(ADR-7/NFR-3)`(澄清建议话术为五要素之一,常量钉死;新建动作 spec 明示本票不执行) |
| FR-4 助手档 | 未配置拒绝运行 | `data/agent_loop_impl_test.dart` + `data/llm_stream_client_impl_test.dart` + `domain/assistant_settings_test.dart` | `未配置拒跑:单 AssistantError,零 LLM 调用(FR-4)` / `empty base url fails fast with zero network attempt` / `not ready when disabled even if endpoint complete` 等 ready 判定组 |
| FR-4 助手档 | 本地端点可配 | `domain/assistant_settings_test.dart` + `data/assistant_settings_store_test.dart` | `localhost endpoint ready without key (FR-4 免 Key 路)` / `127.0.0.1 endpoint ready without key` / `IPv6 loopback endpoint ready without key` / `localhost endpoint is ready without an api key (differs from F46)` / `roundtrips through storage into a fresh instance` |
| FR-5 审计日志 | 日志可检索 | `data/audit_log_test.dart` + `data/agent_loop_impl_test.dart` | `ok line format with args summary` / `error line format, args defaults to empty` / `llm line format` / `every emitted line is pure printable ASCII` / `审计:LogFn 行全 ASCII,含 llm host=/tool=/status=(FR-5)` |
| NFR-1 口径一致 | 参数化全工具比对 | `data/tools/tools_caliber_test.dart` + `data/tools/accounts_list_tool_test.dart` + `data/tools/debts_list_tool_test.dart` | `parameterized: every tool cent-exact vs same-db direct recomputation` / `groups subtotals match same-db direct sums, cent-exact` / `used = card debt + unbilled occupation of attached card loans` / `per-debt fields cent-exact vs same-db schedule sums` |
| NFR-2 聚合预算 | 长列表分页 | `data/tools/debts_list_tool_test.dart` + `data/tools/accounts_list_tool_test.dart` | `page_size=1 → first page + total_count + hasMore` / `page beyond range → empty page, summary intact` / `page_size=1 → single item + hasMore=true + page echo` / `lenient coercion: page 0 → 1, page_size 999 → 50, "2" → 2`(上限钳位) |
| NFR-3 防注入定界 | 备注含指令不被执行 | `data/agent_loop_impl_test.dart` | `NFR-3:注入文本只出现在 <tool_data> 定界内` / `system prompt 逐字常量:同一引用+五要素(ADR-7/NFR-3)` |
| NFR-4 mock 可测 | mock 回放集成测试 | `domain/agent_loop_test.dart` + `data/agent_loop_impl_test.dart` + `data/llm_stream_client_impl_test.dart` | `fake stream client satisfies the port (mock seam, NFR-4)` / 全 impl 回放用例(工具往返/自纠/异常,零网络) / 纯映射函数组(message/chunk 映射 22 例) |
| NFR-5 server 零改动 | 合并前验证 | 非测试:全门验证 | `git diff main -- yucai/server` 输出 0 字节 + `git status`(server 子目录)干净(T6 实测通过;每票全门复跑) |

> 漏项检查:spec ADDED 10 条需求(FR-1..5 + NFR-1..5)全部有对应测试/门,**零 BLOCKED**。T6 接线本身(DI 装配/bootstrap)为组合根胶水,按 code-plan 门以三条全门覆盖,不另立测试文件。

## 评审与修复轮记录(2026-10-23)

- T1 评审:PASS(零 High/Medium;3 Low parked——L-1 domain 经 core/llm 传递拉 Flutter 依赖,F65 前提取票候选;L-2 pubspec 传递依赖措辞;L-3 design ToolContext 漂移已当轮修)。
- T2/T3/T4 批量两轴评审:T2 PASS(2 Low 家法继承不修);T3 PASS-with-fixlist(2 Medium+3 Low);T4 PASS(2 Low)。
- T3-fix(e0246264):M1 BaseCurrencySource 微 port(assistant/domain)+core/di 适配(照 NetWorthSnapshotSourceAdapter 先例)/M2 legalKinds 值域守卫测(枚举漂移即红)/L1 未知 kind 显式 ToolError(不静默按 asset)/L2 占用债列表整页一次(mock 计数钉死 called(1))/L3 limitYuan 配对;tools 测 29→31。
- T4-fix(55f69176):重抛格式契约测(config 指 127.0.0.1:1 零外网,StateError 消息含 host)/buildRequest 移出 try 保 ArgumentError 语义(附零资源泄漏收益);T4 测 30→32。
- T5 对 LLD 伪码两处防御性收紧:轮次按累积 tool_calls 收口(不依赖 provider 方言 finish_reason——对症 openai_dart FinishReason 方言收拢)/工具步 args 防御解析+「永不抛」兜底(异常仅携 runtimeType);audit argsSummary 只传顶层 key 名,任何参数值不入日志。
- T6 build_runner 坑记档:injectable_generator 无法解析内联函数类型 `AssistantConfig Function()` → 按 1h/F21 先例 core/di 手工注册(1m 段);T2/T4/T5 的 @LazySingleton 注解因此 inert——未来 regen 前置=函数参数改命名 typedef+删手工段,再生成债(候选票)。
- 控制器终验:flutter test 全量 **2965 全绿**(main 基线 2849+assistant 116)/flutter analyze **459==基线零新增**/git diff main -- yucai/server **0 字节**;分支线性 12 commit,工作区净。
