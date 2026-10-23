# Task Brief T6 — DI 接线 + 全门 + 需求覆盖对照

## 工作区与铁律

- **只在 worktree 工作**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r22-f64`(T1-T5 已合入;分支 feature/r22-f64)。shell 先 cd worktree 根。
- **改动面**:DI 装配+bootstrap+code-ledger 文档;**不改**任何 assistant domain/data 既有实现(若发现接线必须改实现的豁口→停下 BLOCKED 汇报,不要自作主张改)。
- 完成 `git commit`(`feat(assistant): F64-T6 DI 接线+全门+需求覆盖对照`)。

## 必读

1. `lib/core/di/injection.dart`(bootstrap;F46 LlmSettings.load 的调用位)与 `lib/core/di/injection.config.dart`(生成文件,看结构勿手改——除非 build_runner 重生成)
2. `lib/report/data/llm/llm_mda_narrator.dart` 的 LlmHttpFn 注册方式(injection.config 里搜 LlmMdaNarrator:函数类型位置参数的模块绑定先例——AssistantConfig Function() 取值缝照此绑定)
3. `lib/core/di/injection.config.dart` 里 NetWorthLocalDataSource 与 GrpcClient 的注册方式(手工/生成);
4. T5 的 agent_loop_impl.dart 构造签名与 T3 工具三件的构造依赖

## 任务

### 1. DI 装配(全部生产接线)

- **AssistantConfig Function() 取值缝**:照 LlmHttpFn 先例注册模块绑定,工厂返回 `getIt<AssistantSettings>().value`
- **NetWorthSnapshotSource 适配**:小适配类(assistant/data 或 core/di 手工段,照 GrpcClient「Manually registered」先例选位)委托既有 `NetWorthLocalDataSource.getNetWorth`
- **工具注册**:启动时把三工具注册进 AssistantToolRegistry(装配函数/bootstrap 一段,勿散落)
- **AssistantSettings.load()**:bootstrap 里 F46 LlmSettings.load 同位补一行
- 若用 @injectable 注解:改完跑 `dart run build_runner build --delete-conflicting-outputs`(worktree 可用;若失败按 CLAUDE.md 记录的坑手工兜底并汇报)

### 2. 全门(逐条跑,输出留证)

1. `cd yucai/client && flutter test` —— **全量绿**(main 基线 2849;本 feature 新增约 130-160)
2. `flutter analyze` —— **不超基线**(近期实测 459;凡涉及 assistant 文件的新增 issue 一律修掉)
3. `git diff main -- yucai/server` —— **空**
4. `go test ./...` 不需要(server 零改动);但跑 `cd yucai/server && git status` 确认干净

### 3. 需求覆盖对照表(追加进 `docs/sydusx/.../f64-assistant-foundation/code-ledger.md`)

spec 每个 FR/NFR ↔ 对应测试文件与用例名逐行列出(漏项=BLOCKED 汇报,不许静默)。

## 汇报

接线点清单/全门三条的实际输出摘要(测试总数/analyze 数/diff 状态)/覆盖表/commit hash。
