# F66 code-ledger

> /sydusx-execute 任务台账(task done / fix-rounds / rulings)。评审批次:T1 单独评(L1 spec 措辞订正随 d7b9e5ce);T2/T3/T4 批量两轴评审(2026-10-23 裁决)→ 七项 fixlist 全部由 T5 吸收(逐条记录见文末)。

- **T1 引擎契约+F64 provider 收窄 ✅ done**(commit 6b09391b;domain 三 port(engine_port/engine_state/model_store_port)+ AssistantConfig 收窄 {enabled,model};settings 域测 6 + store 8 + engine_ports 3 + engine_state 7) — 评审 **PASS**(L1 spec FR-3 措辞订正 ValueListenable 随 d7b9e5ce 落档)。
- **T3 调用接线+ModelStore+退出钩子 ✅ done**(commit 88b2cd70;llm_stream_client_impl 引擎接线 + model_store_impl 简版 + notifications_bootstrap 退出钩子) — **记档:本 commit 不可独立编译**(并行协调代价 —— T3 与 T2 并行开发,T3 先落,其 injection.dart 1m 段已注册 `ProcessLauncherImpl`(定义在 T2 的 process_launcher.dart),单检出 88b2cd70 编译不过;2 分钟后 T2(0c62207a)落地即全绿。分支整体始终绿,仅单 commit bisect 粒度受损,知情接受)。
- **T2 EngineManagerImpl 生命周期编排 ✅ done**(commit 0c62207a;engine_manager_impl + process_launcher + 单测 12,T5 修后 14)。
- **T4 真引擎集成冒烟 ✅ done**(commit d04b0705;tool/fetch_engine.py 钉死 b11669 + stories15M-q4_0.gguf fixture 入 git + engine_smoke_test)。
- **spec FR-3 措辞订正 ✅**(commit d7b9e5ce;评审 T1-L1,ValueListenable 行为等价多播)。
- **T5 随包捆绑+收尾接线+评审 fixlist 七项+全门+覆盖表 ✅ done**(见下与 fixlist 逐条记录)。
- **build_runner 债(F64-T6 记档延续,F66 加深)**:injectable_generator 无法解析 impl 构造参数的内联函数类型 → F66 新增 **4 条手工注册**(injection.dart 1m:LlmStreamClient / AgentLoopService / ProcessLauncher / EngineManager,对应 4 个 impl 的 @LazySingleton 注解 inert)。未来若要走 regen:先把 impl 构造的内联函数参数改为命名 typedef + 删 1m 手工段,否则双注册冲突;再生成债候选票已在 F64 ledger 记档。

## T5 落点摘要

- **捆绑(ADR-9/NFR-4)**:`windows/runner/CMakeLists.txt` POST_BUILD `copy_directory` 把 `tool/engines/` 整 zip 产物拷到 `$<TARGET_FILE_DIR:${BINARY_NAME}>`(= exe 同级,yucai.iss 递归打包该目录即入安装包);目录缺失(dev 未跑 fetch 脚本)`if(EXISTS ...)` 零报错跳过。`release.yml` build 步前加 `python yucai/client/tool/fetch_engine.py`(幂等,tag b11669+sha256 钉死)。`EngineManagerImpl` 生产 exePath 缺省改为 `Platform.resolvedExecutable` 父目录 + bundledExeName(注入缝不变)。
- **活跃 port 上提(§2)**:engine_port.dart 加 `beginActivity()/endActivity()`(impl 已有实现直通加 @override);LlmStreamClientImpl.chat 流开始 begin、finally end(FR-1 闲置回收不杀进行中流,异常路径 finally 兜底)。
- **托盘 quit 缺口(评审 T3-H1)**:TrayController 注入 `engineShutdown` 回调,quit() 与 onWindowClose 分支①(托盘不可用兜底真退出)在 _exit 前 await;notifications_bootstrap 以**同一闭包**注入 TrayController 与 TrayAppExit(同源杀,设置页/AppExitPort 链保持)。
- **全门**:flutter test **2994 全绿**(main 基线 2967,T1-T4 净 +20,T5 净 +7);flutter analyze **459 == 基线零新增**;`git diff main -- yucai/server` **0 字节**;真引擎冒烟本机真跑绿(engine start port=13769 / ready ms=509 / completion 非空往返);`flutter build windows --release` 捆绑验证(见 NFR-4 行)。

## 需求覆盖对照表(T5;spec FR/NFR ↔ 测试)

测试根 `yucai/client/test/`(assistant 外注明)。

| 需求 | 场景 | 测试文件 | 用例名 |
| --- | --- | --- | --- |
| FR-1 生命周期·懒启动 | Stopped→Starting→Ready 全转移+参数 | `assistant/data/engine_manager_impl_test.dart` | `cold start walks Stopped->Starting->Ready; ADR-6 args; English logs` |
| FR-1 生命周期·懒启动 | 并发 join / Ready 热路径 | 同上 | `three concurrent ensureReady calls share one start (idempotent join)` / `ensureReady on Ready returns immediately and re-arms the idle window` |
| FR-1 生命周期·disabled 门 | disabled 预热不拉引擎(评审 T2-L3) | 同上 | `disabled config: ensureReady is a no-op, engine never spawns (T2-L3)` |
| FR-1 生命周期·闲置回收 | 10min 回收/活跃顺延 | 同上 | `idle timeout (10min fast-forward) with no activity tree-kills -> Stopped` / `idle timeout defers while a request is active, recycles once idle again` |
| FR-1 生命周期·崩溃重启 | Ready 崩溃自愈回 Ready | 同上 | `unexpected process exit after Ready triggers auto-restart to Ready` |
| FR-1 生命周期·崩溃重启 | 总重生 ≤3(首重生计入,评审 T2-M1) | 同上 | `crash loop: respawns capped at 3 (first counts, T2-M1) -> Error(crashed), no self-heal` |
| FR-1 生命周期·退避 | 1s/3s/9s 阶梯 / spawn 失败同口径 | 同上 | `health timeout retries with 1s/3s/9s backoff, then Error(startFailed)` / `spawn failure (exe missing) counts as startFailed toward the same cap` |
| FR-1 生命周期·退出强杀 | shutdown 树杀/解除崩溃监听 | 同上 | `shutdown tree-kills, cancels the idle timer, disarms the crash watcher` |
| FR-1 生命周期·退出强杀 | 在途退避 delay 在 shutdown 后不复活(评审 T2-L2) | 同上 | `shutdown during a backoff delay aborts the ladder: no respawn after teardown (T2-L2)` |
| FR-1 生命周期·退出强杀 | 托盘/关闭决策树全退出路径杀引擎(评审 T3-H1) | `core/notifications/tray_controller_test.dart` | `engineShutdown 注入:quit() 在 exit 前 await 引擎杀(F66 T3-H1;托盘菜单/关闭偏好=退出/首关选退出同路)` / `分支① 托盘不可用兜底真退出:同样先 await 引擎杀(F66 T3-H1)` / `engineShutdown 抛错也必退出(fail-open,不留引擎僵尸)` |
| FR-2 provider 收窄 | ready=enabled&&model 非空 | `assistant/domain/assistant_settings_test.dart` | `ready when enabled and model non-empty (config completeness only)` / `not ready when disabled even if model set` / `not ready when model empty` / `not ready when model whitespace-only` |
| FR-2 provider 收窄 | 两键持久化/旧键忽略 | `assistant/data/assistant_settings_store_test.dart` | `persists exactly the two narrowed keys, never legacy ones` / `legacy F64 keys are ignored; known keys still load (FR-2)` |
| FR-2 provider 收窄 | 模型在位检查(ModelStore) | `assistant/data/model_store_impl_test.dart` | `文件在位:modelPath 返回精确路径,isReady=true` / `目录在而文件缺:modelPath=null,isReady=false(FR-2 modelMissing 源)` / `全缺:modelPath=null 不抛、不建目录` / `缺省缝构造零 IO` |
| FR-2 provider 收窄 | modelMissing 前置不起进程 | `assistant/data/engine_manager_impl_test.dart` | `missing model short-circuits to Error(modelMissing), no process spawned` |
| FR-3 状态 port | 当前值缓存+转移不漏 | `assistant/domain/engine_ports_test.dart` | `state carries current value; transitions reach late subscribers` / `equal state re-set does not notify (value semantics dedupe)` |
| FR-3 状态 port | 四态 sealed 形状 | `assistant/domain/engine_state_test.dart` | `four sealed subtypes are distinct EngineState values` / `fieldless states are const-canonical` / `ready/error equality is value-based` / `covers exactly the FR-1 failure causes` / `switch over EngineState covers all four states` |
| FR-4 调用接线 | Ready 端点真实流入请求(loopback) | `assistant/data/llm_stream_client_impl_test.dart` | `ready:ensureReady 兜底被调,baseUrl 取 Ready 端点,流经该端点往返 (loopback SSE;ADR-1/ADR-8)` |
| FR-4 调用接线 | 未就绪自解释错误语义 | 同上 + `assistant/data/agent_loop_impl_test.dart` | `未就绪 Error(modelMissing):抛自解释 StateError,零网络(FR-4/FR-2)` / `未就绪 Stopped(ensureReady 后仍未就绪):同路径自解释语义` / `引擎未就绪→中文 AssistantError 直给「引擎未就绪」语义(F66-T3/FR-4)` / `未启用拒跑:单 AssistantError,零 LLM 调用(FR-4;文案无「端点」)` |
| FR-4 调用接线 | 活跃包夹防回收杀流(T5 §2) | `assistant/data/llm_stream_client_impl_test.dart` | `T5 活跃包夹:流开始 begin、流关闭 end 成功路径配对(FR-1 闲置回收保护,loopback 往返)` / `T5 活跃包夹:未就绪抛错路径 finally end 兜底配对` |
| NFR-1 真引擎冒烟 | 拉起→ready→往返→终止(真 exe) | `assistant/integration/engine_smoke_test.dart` | `real engine smoke: start -> ready -> completion roundtrip -> shutdown`(本机真跑绿:ready ms=509,completion 非空) |
| NFR-2 注入缝 | 单测零真进程零真等待 | `assistant/data/engine_manager_impl_test.dart` | 全 _Sut 组(delay/healthProbe/portScan/exePath/idleTimerFactory/log 六缝全 fake;`lifecycle log lines stay printable ASCII across paths (NFR-3)` 同组复用) |
| NFR-3 English 日志 | 全路径 ASCII 结构化 | 同上 + `assistant/domain/engine_state_test.dart` | `lifecycle log lines stay printable ASCII across paths (NFR-3)` / `all states render ASCII-only, no CJK` |
| NFR-4 随包捆绑 | 工程面(非测试:全门+构建验证) | windows/runner/CMakeLists.txt + .github/workflows/release.yml | `flutter build windows --release` 双路径实测:**有资产** → `build/windows/x64/runner/Release/llama-server.exe`+ggml*.dll 全套在位(exe 同级,yucai.iss 递归打包即入安装包);**缺目录**(dev 未跑 fetch)→ 构建零报错(EXISTS 守卫静默跳过,实测 exit 0);fetch_engine.py 幂等+sha256 钉死 |
| NFR-5 server 零改动 | 合并前验证(非测试:全门) | — | `git diff main -- yucai/server` 0 字节 + server 子目录 status 干净(T5 实测;每票全门复跑) |

> 漏项检查:spec ADDED 9 条需求(FR-1..4 + NFR-1..5)全部有对应测试/门,**零 BLOCKED**。FR-1 退出强杀的设置页路径(AppExitPort)由 bootstrap 同源闭包接线,组合根胶水按 code-plan 门以全门覆盖(托盘侧三分支有 mock 断言)。

## 评审与修复轮记录(2026-10-23)

- T1 评审:PASS;L1 spec FR-3 措辞订正(ValueListenable)随 d7b9e5ce 落档。
- T2/T3/T4 批量两轴评审:裁决七项必修,全部由 T5 吸收(即简报 §0 fixlist):

| # | 项 | 落法 |
| --- | --- | --- |
| 1 | T3-H1 主退出路径漏杀引擎 | TrayController 注入 `engineShutdown` 回调(选型=注入回调而非 quit() 改道 AppExitPort:后者需 TrayController 持 port 引用且 bootstrap 注册时序耦合,阻力更大);quit() 与 onWindowClose 分支① _exit 前 await;bootstrap 同一闭包双注入(TrayController+TrayAppExit 同源);失败 fail-open 吞错仍退出。+3 测(quit 杀/抛错仍退/分支① 杀) |
| 2 | T3-M1 未启用文案退役「端点」 | `助手未配置端点,请先在设置中配置`→`助手未启用,请在设置中开启`(agent_loop_impl);domain agent_loop.dart doc 同步;loop 断言逐字更新 `未启用拒跑:单 AssistantError,零 LLM 调用(FR-4;文案无「端点」)` |
| 3 | T2-M1 重启预算 off-by-one | `_runStartSequence({firstAttemptIsRestart})`:崩溃重入(_onUnexpectedExit)传 true,预算 +1 offset → 总重生 ≤3;冷启口径不变(初试免费,1+3)。测试 `hasLength(5)`→`hasLength(4)`(注释「initial+3」自相矛盾处修正)+ 重启日志断言精确化(attempt=1,2) |
| 4 | T2-L1 _isAlive catch 注释与行为相反 | 注释改为实际语义:tasklist 不可用 → assume dead → 直接 return(跳过 taskkill;graceful 已尽力;报 alive 反而每次 killTree 强跑 taskkill) |
| 5 | T2-L2 shutdown 不中止在途启动 | `_generation` 代数:shutdown 递增;_runStartSequence 进序列快照,每次 spawn 前(循环顶)比对,已换代即 return。+1 测(gate 卡首退避 delay,shutdown 后放行 → 零重生、零后续退避) |
| 6 | T2-L3 ensureReady 前置 enabled | `!_config().enabled → 直接 return`(状态不动/零进程/零端口扫描/零模型检查;防 F65 预热白拉起)。+1 测;_Sut 缺省 config 改 enabled:true(既有用例不受扰) |
| 7 | T3-L2 isRegistered 死分支 | notifications_bootstrap 直调 `getIt<EngineManager>().shutdown()`(T2 已合入恒真),注释记档缘由;try/catch 包裹(引擎清理降级不阻断退出) |
