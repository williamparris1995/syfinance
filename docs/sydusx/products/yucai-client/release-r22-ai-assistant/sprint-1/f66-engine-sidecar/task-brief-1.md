# Task Brief T1 — domain 三契约 + F64 收窄返工

## 工作区与铁律

- **只在 worktree 工作**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r22-f66`(分支 feature/r22-f66;F64 产物已随 main 在)。shell 先 cd worktree 根。
- **TDD** 先测后码逐文件跑;不碰 `yucai/server/`、F46 `core/llm` 既有文件、其他模块。
- 完成 `git commit`(`feat(assistant): F66-T1 引擎契约+F64 provider 收窄`)。

## 必读

1. 同目录 `spec.md`(FR-2/FR-3 场景)+`design.md`(ADR-5/7/8)
2. `yucai/client/lib/assistant/domain/`(F64 五契约文件,收窄对象 assistant_settings.dart)
3. `yucai/client/lib/assistant/data/assistant_settings_store.dart`(keys 收窄)
4. 既有测试 `test/assistant/domain/assistant_settings_test.dart`(16 测将重写)

## 任务

### 1. domain 三新文件

- `engine_state.dart`:`sealed class EngineState`——`EngineStopped`/`EngineStarting`/`EngineReady(Uri endpoint)`/`EngineError(EngineFailureReason reason)`,`enum EngineFailureReason { modelMissing, crashed, startFailed }`
- `engine_port.dart`:`abstract class EngineManager { Future<void> ensureReady(); Future<void> shutdown(); ValueListenable<EngineState> get state; }`(ValueListenable 照 LlmSettings 家法的响应式形态,当前态缓存;注释:F65 打开浮层即调 ensureReady 预热=ADR-1)
- `model_store_port.dart`:`abstract class ModelStore { Future<String?> modelPath(); Future<bool> isReady(); }`(注释:F67 将替换实现为下载管理,port 不变=ADR-7)

### 2. F64 收窄返工(MODIFIES F64 FR-4)

- `assistant_settings.dart`:AssistantConfig 削减为 `{bool enabled=false; String model='qwen3-4b-instruct-q4_k_m'}`(默认模型 id 常量,未来 F67 多模型留缝);**删除** provider/baseUrl/apiKey/resolvedBaseUrl/_isLocalhost/旧 ready;新 `ready` 语义=`enabled && model 非空`(运行期就绪=enabled&&ModelStore.isReady 由引擎侧组合,config 层只管字段完整;doc 注释写明分工);不再 import core/llm(顺手消掉 T1 评审 parked 的 L-1 domain 传递 Flutter 依赖之一)
- `assistant_settings_store.dart`:keys 收窄为 `assistant.enabled`/`assistant.model`;load/setConfig 同步削减;旧键残留无害=读取端天然忽略(FR-2 场景);doc 注释记「2026-10-23 收窄,F64 形态未发版零迁移」
- 测试重写:assistant_settings_test(16→~6:字段/默认/copyWith/ready 新语义)+ store test(往返/幂等/旧键忽略场景——写入遗留键后 load 不受影响)
- 全 assistant 测试跑绿(其他文件若因 config 形态变化编译错,**最小修改**适配:LlmStreamClient/agent_loop 测试的 fake config 构造——只改测试构造参数,不改生产逻辑;生产 LlmStreamClient 的改造属 T3,本票它编译过即可,允许临时以固定 localhost 假端点构造)

## 验证门

`flutter test test/assistant/` 全绿;`flutter analyze` 零新增(459);`git diff yucai/server` 空。汇报:文件清单+测试数(前后对比)+commit hash。
