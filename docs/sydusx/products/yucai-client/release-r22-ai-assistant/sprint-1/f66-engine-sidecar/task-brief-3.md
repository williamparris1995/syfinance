# Task Brief T3 — 调用接线 + ModelStore 简版 + 退出钩子

## 工作区与铁律

- worktree `.claude/worktrees/r22-f66`(T1 已合入;**T2 并行在途**——EngineManagerImpl 可能未完,你只依赖 domain 的 EngineManager/ModelStore port 与 T2 的 ProcessLauncher 文件若需;测试全用 fake port,不依赖 T2 impl)。TDD;不碰 server/F46/T2 范围(engine_manager_impl.dart)。
- 完成 `git commit`(`feat(assistant): F66-T3 调用接线+ModelStore+退出钩子`)。

## 必读

1. `design.md`(ADR-8 接线段)+`spec.md`(FR-2/FR-4 场景)
2. `lib/assistant/data/llm_stream_client_impl.dart`(T1 收窄后的现状)+`lib/assistant/data/agent_loop_impl.dart`(未就绪错误消费面)
3. `lib/app/` 下 AppExitPort 定义与注册(F22 先例;grep AppExitPort)
4. `lib/core/di/injection.dart` 1m/2g 手工段(F64 接线现状)

## 任务

1. **ModelStoreImpl**(`lib/assistant/data/model_store_impl.dart`):`@LazySingleton(as: ModelStore)`——modelPath=`<应用数据目录>/yucai/models/qwen3-4b-instruct-q4_k_m.gguf`(路径获取注入缝 `String Function()` 缺省 path_providergetApplicationSupportDirectory——**若 path_provider 不在依赖则用既有应用数据目录获取惯例,grep path_provider/getApplicationSupport;实在没有就注入缝缺省走 `Platform.environment['APPDATA']`+注释**);isReady=File 存在;model 不存在返回 null。单测:临时目录注入缝三态。
2. **LlmStreamClientImpl 改造**:构造追加注入 `EngineManager`;chat() 前置:`ensureReady()`(兜底,ADR-1)+state 检查——非 Ready(如 modelMissing)→抛自解释 `StateError('engine not ready: <reason>')`(**中文面向用户的转换在 agent_loop 的 AssistantError 已有机制:确认 loop 对 StateError 的转换文案,若「引擎未就绪」语义不达则最小改 loop 的异常文案映射一处**);Ready→endpoint 传 OpenAIClient(baseUrl=endpoint)——**删除** T1 期临时固定假端点与 AssistantConfig Function() 的 baseUrl 语义(config 仍供 enabled/model:未启用→同未就绪路径);apiKey='sk-noauth' 占位保留注释(ADR-8)。映射函数与既有 24 测零改动(它们不经引擎路径;新增测试:fake EngineManager 三态——ready 出正确 baseUrl/未就绪抛语义错误/ensureReady 被调)。
3. **退出钩子**:grep AppExitPort 既有注册点,在其触发链加 `getIt<EngineManager>().shutdown()`(English 注释:F66 引擎随退强杀);若无清晰钩子位则在 injection.dart bootstrap 记录 TODO 并在汇报说明(不强行接线)。
4. **DI**:1m/2g 手工段补 ModelStoreImpl/EngineManagerImpl 注册(若 T2 未完成注册——**检查后只补缺,不与 T2 冲突**;EngineManagerImpl 构造依赖多,手工段照 F46 LlmHttpFn 模式逐参 getIt)。

## 验证门

`flutter test test/assistant/` 全绿(T2 WIP 文件若瞬时编译抖动,排除后复跑并注明);analyze 零新增;`git diff yucai/server` 空。汇报:接线点清单+测试数+AppExitPort 接线结果+commit hash。
