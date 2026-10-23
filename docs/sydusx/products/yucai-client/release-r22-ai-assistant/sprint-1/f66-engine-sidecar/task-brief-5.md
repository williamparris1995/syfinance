# Task Brief T5 — 随包捆绑工程面 + 收尾接线 + 全门 + 覆盖表

## 工作区与铁律

- worktree `.claude/worktrees/r22-f66`(T1-T4 已合入,HEAD d04b0705,138 绿)。shell 先 cd worktree 根。
- 改动面:windows/runner 工程+release CI+两处小接线+docs;**生产核心逻辑(engine_manager/llm_stream 的既有实现)仅在两接线点必要时最小改**。
- 完成 `git commit`(`feat(assistant): F66-T5 随包捆绑+收尾接线+全门`)。

## 必读

1. `design.md`(ADR-9)+`spec.md`(NFR-4/FR-1 退出强杀)
2. `yucai/client/windows/runner/` 结构(CMakeLists;grep WinSparkle/auto_updater 资产先例=F24)
3. `.github/workflows/release.yml`(F24 管线)
4. `lib/assistant/data/process_launcher.dart` 的 exePath 缝现状(EngineManagerImpl 的 exePath 注入,生产默认值=?)与 `lib/core/notifications/notifications_bootstrap.dart`(T3 退出钩子)

## 任务

### 0. 评审 fixlist 必修(批量两轴评审 2026-10-23 裁决,先做)

1. **【T3-H1】主退出路径漏杀引擎**:AppExitPort 只盖设置页退出按钮;`tray_controller.dart` 的 `quit()`(:238-241)与 `_exit()`(:324-325 兜底分支)——托盘菜单 _kQuit(:407-409)/窗口 X 关闭=退出(:326-332)/首关对话框选退出(:353-355)全部不经 AppExitPort。修法:TrayController 注入引擎 shutdown 回调(bootstrap 装配处与 tray.stop 同源),quit() 与 _exit() 分支 await shutdown 后再 _exit();或 quit() 改道 AppExitPort.exitApp()——选实现阻力小者,补断言(可行)或集成说明。
2. **【T3-M1】未启用文案退役词汇**:`agent_loop_impl.dart:80-82`「助手未配置端点,请先在设置中配置」→ 改「助手未启用,请在设置中开启」(无「端点」字样);补 loop 断言。
3. **【T2-M1】崩溃重启预算 off-by-one**:Ready→崩溃重走 _ownStartSequence 时首次重生未计入预算,P1+1s+3s+9s=4 次重生才 Error。修:**总重生 ≤3**(首次重生计入),修 engine_manager_impl 与 engine_manager_impl_test 的 `hasLength(5)`/注释自相矛盾处。
4. **【T2-L1】`process_launcher.dart:101-104` _isAlive catch 注释与行为相反**(false→killTree 直接 return 跳过 taskkill)——注释改为实际语义(assume dead → nothing left to kill, graceful path 已尽力)。
5. **【T2-L2】shutdown 不中止在途启动序列**:退避 _delay 到点可在 shutdown 后再次 spawn。修:generation 计数,每次 spawn 前比对;补测(shutdown 后 delay 触发不再拉起)。
6. **【T2-L3】ensureReady 前置 enabled 检查**:`!_config().enabled → 直接 return`(防 F65 预热在 disabled 时拉起引擎);补测。
7. **【T3-L2】notifications_bootstrap.dart:250 isRegistered 死分支**(T2 已合入恒真)——简化,保留注释说明。

### 1. 随包捆绑(ADR-9)

- windows/runner CMake:把 `tool/engines/` 下(llama-server.exe+DLL,fetch_engine.py 整 zip 产物)在构建时拷入 bundle(与 yucai_client.exe 同级);**目录不存在时零报错跳过**(dev 未跑脚本不破构建,English 注释)。
- release.yml:build 步前加 `python yucai/client/tool/fetch_engine.py`(幂等,tag/sha 钉死)。
- EngineManagerImpl 生产 exePath 默认值改为「exe 旁相对路径 llama-server.exe」解析(注入缝不变,单测照跑;Windows 下 `Platform.resolvedExecutable` 同级)——照既有托盘/资产路径解析惯例。

### 2. 收尾接线两处(T3 遗留)

- **托盘 quit 缺口**:grep TrayController.quit();在退出公共链(quit() 与窗口关闭决策树汇合点)补 EngineManager.shutdown()(isRegistered 守卫同 T3 先例);AppExitPort 链保持。补一测(可行则 mock 断言,否则集成说明)。
- **活跃 port 上提**:EngineManager port 加 `void beginActivity()`/`void endActivity()`(domain engine_port.dart 两行+impl 已有实现直通);LlmStreamClientImpl.chat() 流开始 begin/finally end(防闲置回收杀进行中流);补测:fake EngineManager 断言 begin/end 配对(异常路径 finally 兜底)。

### 3. 全门(逐条留证)

1. `flutter test` 全量绿(基线 main 2967±收窄净变——记录精确数)
2. `flutter analyze` 459 零新增
3. `git diff main -- yucai/server` 空
4. 冒烟在本机真跑(fetch 资产已在)输出摘要

### 4. 覆盖表

spec F66 全 FR/NFR ↔ 测试用例名逐行追加 `code-ledger.md`(新建该文件于 feature 目录,照 F64 格式;含 T1-T5 各 commit 与评审裁决占位)。

## 汇报

捆绑落点(文件+机制)/两接线落法/全门四条输出/覆盖表摘要/commit hash。若 windows/runner 无资产先例可循,提出你采用的机制与理由,勿硬造。
