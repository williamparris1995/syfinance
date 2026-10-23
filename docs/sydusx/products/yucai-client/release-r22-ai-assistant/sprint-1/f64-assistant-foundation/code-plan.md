# F64 code-plan

> /sydusx-execute 2026-10-23。批次:[T1∥T2] → [T3∥T4] → [T5] → [T6];SDD(子代理实现+两轴评审);控制器不写实现。

- [x] T1 domain 契约层 ✅(57aad7c5;33 测;评审 PASS 3 Low parked) — `lib/assistant/domain/` 五契约文件(assistant_tool/tool_registry/agent_loop[AssistantEvent sealed]/assistant_settings[AssistantConfig+ready 放宽 localhost]/networth_port)+注册/重名拒/OpenAI schema 序列化/ready 规则单测;pubspec 引 openai_dart ^11。
- [x] T2 配置存储 ✅(fbcba729;8 测;评审并入批次) — `lib/assistant/data/assistant_settings_store.dart`(LlmSettings 家法镜像,assistant.* keys,mock storage 注入缝)+load/setConfig/ready 单测。
- [x] T3 三只读工具 ✅(7dc8a10a;29 测;F50=cardLoanOccupationCents domain 复用/mapper 无需补列) — data/tools/ 三实现(networth[NetWorthSnapshotSource+CurrencySettings baseCurrency]/accounts[AccountVisibility 过滤+F50 占用派生复用:定位落点回填 design Open Question,presentation 则提 account/domain 纯函数]/debts[nextPayment 三字段真库式断言,缺则 debt mapper 单点补])+口径逐分参数化断言(vs repository/NetWorthLocalDataSource 同库)。
- [x] T4 流客户端+审计 ✅(da8b9811;30 测;openai_dart 11.0.1 API 六处出入记档) — data/llm_stream_client_impl.dart(openai_dart 包装,LlmChatRequest/LlmChunk 映射)+data/audit_log.dart(LogFn 注入缝+ASCII grep 门测试)。
- [x] T5 agent loop 编排 ✅(38e146a7;12 测回放集成;两处防御性收紧) — data/agent_loop_impl.dart(循环/自纠上限 3/事件流/外来字符串定界回填/错误红线只含类+域名)+mock 回放集成测试(工具往返闭环/错误自纠二振成功/上限 3 终止/未配置拒跑)。
- [x] T6 接线+全门 ✅(23805c70;接线 4/4 手工注册兜底 build_runner 函数类型坑;全门 2961 绿→修复轮后终验 2965) — core/di 手工注册(NetWorthSnapshotSource 适配 holding NetWorthLocalDataSource+LlmStreamClient/AgentLoopService 绑定);门=flutter test 全绿(基线 2849 不降)+analyze 不升基线(460/461)+git diff yucai/server 空+需求覆盖对照表(spec FR/NFR ↔ 测试)。

复杂度判级:cross-module(新模块+跨域 port+新依赖)→ full SDD。
