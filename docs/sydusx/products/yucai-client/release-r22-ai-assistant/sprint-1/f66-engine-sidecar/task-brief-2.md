# Task Brief T2 — EngineManagerImpl 生命周期编排

## 工作区与铁律

- worktree `.claude/worktrees/r22-f66`(T1 契约已合入)。TDD;不碰 server/F46/其他模块/T3 范围(llm_stream_client 接线)。
- 完成 `git commit`(`feat(assistant): F66-T2 EngineManagerImpl 生命周期编排`)。

## 必读

1. 同目录 `design.md`(ADR-1..6,LLD EngineManagerImpl/闲置回收两节)+`spec.md`(FR-1/FR-3 全场景)
2. `lib/assistant/domain/engine_port.dart`+`engine_state.dart`+`model_store_port.dart`(T1 产物)
3. `lib/core/feedback/feedback_launcher.dart` 等既有「函数注入缝」写法参照;`lib/app` 的 AppExitPort(F22)看接口形态(接线属 T3,本票只看)

## 任务

### 生产文件(`lib/assistant/data/`)

1. `process_launcher.dart`:
   - `abstract class ProcessLauncher { Future<LaunchedProcess> start({required String exe, required List<String> args}); }`
   - `class LaunchedProcess { int pid; Future<int> exitCode; Future<void> kill(); }`
   - 生产 impl `@LazySingleton() ProcessLauncherImpl`(dart:io Process.start,startInfo:隐藏窗口 Windows `ProcessStartMode.normal` + `DETACHED`不适用——照常,注释说明);`killTree(int pid)` 方法:先 `Process.killPid(pid)` 等 2s,仍在则 `taskkill /PID <pid> /T /F`(Process.runSync),English 注释
2. `engine_manager_impl.dart`:`@LazySingleton(as: EngineManager)`——构造注入 `ProcessLauncher`+`ModelStore`+`AssistantConfig Function()`+可注入时钟/延时缝(`Future<void> Function(Duration)` 缺省 Future.delayed,单测零真等待)+健康探测缝(`Future<bool> Function(Uri)` 缺省真 HTTP /health,dart:io)
   - `ensureReady()` 幂等:Ready→即返;Starting→等待进行中 Future;Stopped/Error→流程:ModelStore.isReady 检查(缺→EngineError(modelMissing),不起进程,直接返)→随机空闲端口扫描(ServerSocket bind 试探,缝可注入)→state=Starting→launcher.start(exe 路径=注入的 `String Function()` exePath 缝,缺省固定相对路径名,注释=T5 捆败后随包)→health 轮询(500ms×60=30s 超时缝)→EngineReady(endpoint)→返;任何失败→退避重启(1s/3s/9s,上限 3 次,计数到顶 EngineError(crashed 或 startFailed 按失败点))→重走全流程(重扫端口)
   - `state`:`ValueNotifier<EngineState>`(当前态缓存),转移即更新;曝光 `ValueListenable<EngineState>`
   - 闲置回收:每次 ensureReady 触发 `touchIdleTimer()`;10min Timer 到→若当前无进行中请求(内部活跃计数,chat 开始+1 结束-1——供 T3 调用的 `beginActivity()/endActivity()` 公开方法)→graceful kill→Stopped;有活跃则顺延重置
   - `shutdown()`:强杀树+Stopped+取消 Timer
   - 英文日志(printf 风格照 AssistantAuditLog 或 debugPrint):`engine start port=<n>`/`engine ready ms=<n>`/`engine idle-stop`/`engine restart attempt=<n>`——无 CJK

### 单测(`test/assistant/data/engine_manager_impl_test.dart`)

全注入缝 fake(零真进程/零真等待——时钟缝立即触发):懒启动全转移 Stopped→Starting→Ready/幂等并发三连调一个进程/modelMissing 不起进程/健康超时退避重启三次到顶 error/进程异常退出(模拟 exitCode 完成)触发重启/闲置回收(时钟快进 10min+无活跃)/活跃期不回收/活跃后到期回收/shutdown 树杀。状态流断言用 ValueListenable 收集器。

## 验证门

`flutter test test/assistant/` 全绿;analyze 零新增(459);`git diff yucai/server` 空。汇报:文件清单+测试数+与 design LLD 偏差(若有)+commit hash。
