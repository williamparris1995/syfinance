# Task Brief T2 — AssistantSettings 存储(secure storage 家法镜像)

## 工作区与铁律

- **只在 worktree 工作**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r22-f64`(分支 feature/r22-f64)。shell 先 cd 进 worktree 根。
- **TDD**:先测(RED)后实现(GREEN),逐文件即时跑测。
- **不碰**:`yucai/server/`、`lib/core/llm/` 既有 F46 文件(LlmSettings 零改动)、DI 接线(归 T6)、其他模块。
- 注意:T1 并行在途,可能已创建 `lib/assistant/domain/` 与 pubspec 变更——**只写自己的文件,不与 T1 冲突**;若 `assistant_settings.dart`(domain)尚不存在导致编译依赖缺失,自行按 design.md ADR-4 的 AssistantConfig 契约先行创建会撞 T1——**改为**:你的存储类对 AssistantConfig 的依赖通过相对导入 `../domain/assistant_settings.dart`;若该文件暂缺,等价地在测试内 mock 数据类不可行(强类型)→ 此时先实现测试用例骨架+`@Skip`(标注 pending T1),并在汇报中说明;正常情况 T1 先完成则直接全绿。开工时先检查该文件是否已在。
- 完成后 `git add <相关文件> && git commit`(消息:`feat(assistant): F64-T2 AssistantSettings secure storage`)。

## 必读

1. `docs/sydusx/products/yucai-client/release-r22-ai-assistant/sprint-1/f64-assistant-foundation/design.md`(ADR-4)
2. `yucai/client/lib/core/llm/llm_settings.dart` —— **逐条镜像的家法范本**(LlmSettings:LlmConfig+ValueNotifier+幂等 load+decode 回落+storage 注入缝)
3. F46 的存储测试先例:在 `yucai/client/test/` 里 grep `LlmSettings` 或 `FlutterSecureStorage` 找到 mock secure storage 的写法并照抄该模式

## 任务

### 实现(`yucai/client/lib/assistant/data/assistant_settings_store.dart`)

`@LazySingleton() class AssistantSettings`,逐条照 LlmSettings 家法:

- 构造 `{FlutterSecureStorage? storage}` 注入缝(单测 mock)
- keys:`assistant.enabled` / `assistant.provider` / `assistant.base_url` / `assistant.api_key` / `assistant.model`(与 F46 的 `llm.*` 命名空间并存)
- `ValueNotifier<AssistantConfig> _notifier`;`LlmConfig→AssistantConfig` 对应:`value` getter / `listenable` / `ready` 派生 / 幂等 `load()`(缺省=enabled false 的关闭态,非法值回落:provider→zhipu)/ `setConfig(config)` 全量落盘+通知
- AssistantConfig 来自 `../domain/assistant_settings.dart`(T1 产物)
- doc comment 中文,说明「照 LlmSettings 家法逐条镜像;独立 namespace 与 F46 互不影响;ready 放宽 localhost 免 Key 见 ADR-4」

### 单测(`yucai/client/test/assistant/data/assistant_settings_store_test.dart`)

照 F46 存储测试模式(mock/inline FlutterSecureStorage):

- 缺省态:未 load / 空存储 → enabled=false,ready=false
- 往返:setConfig 全字段 → 新实例 load → 逐字段相等
- 非法存储回落:provider 存垃圾值 → 回落 zhipu
- 幂等:两次 load 第二次不再读存储(mock 计数断言)
- ready 透传:localhost 免 Key 配置 → ready true(F46 语义下会是 false,这里是本任务的关键差异断言)

## 验证门

1. `cd yucai/client && flutter test test/assistant/` 全绿(若含 T1 的测试也须绿)
2. `flutter analyze` 零新增 info
3. `git diff yucai/server` 空

汇报:文件清单+测试通过数+analyze 结果+(若触发 @Skip 路径,说明)。
