# Task Brief T4 — TrayController 改造收口(决策树/watch/重臂/撤项/接线)

> F22 code-plan Task4。TDD;controller 不改产物。前置 T1(TraySettings/AppExitPort)、T3(showFirstCloseDialog)已合。并行提醒:T3 修复代理在改 first_close_dialog.dart 内部(hover/scrim/autofocus)——**API 签名不变**,你按现有签名消费,勿碰该文件内部。

## 环境

worktree:`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r8-f22`(分支 feature/r8-f22;勿切分支勿 commit)。客户端 `yucai/client/`;注释中文。

## 上下文(先读)

- spec.md FR-2/3/4/5/6 + NFR-1/2/3;design.md ADR-1/4/5 与 LLD「onWindowClose 决策树/drift watch 触发链/间隔重臂」。
- lib/core/notifications/tray_controller.dart(现状)、notifications_bootstrap.dart(接线点)、tray_settings.dart、app_exit_port.dart(T1)、lib/settings/widgets/first_close_dialog.dart(T3,消费其 API 勿改其内部)。
- lib/app/router.dart:找 GoRouter 的 navigatorKey(或等价全局 key)作对话框 context 源。
- 既有测试范式:test/core/notifications/ 下 tray 相关测试的 mock 手法(windowManager/trayManager 既有 fake,沿用)。

## 交付

### 1. tray_controller.dart 改造

- 构造新增(全部可选带默认,老测试零改动可构造):`TraySettings? settings`(null→内部默认值行为,等价现状)、`List<Stream<void>> changeTriggers = const []`(drift watch 面,空=无变更触发)、`Future<FirstCloseDialogResult?> Function(BuildContext context)? closePrompt`(首关对话框注入缝;core→settings 方向禁止 import——用 `Future<Object?> Function(BuildContext)` 之类的泛化签名亦可,只要求 bootstrap 能把 showFirstCloseDialog 接进来)、`BuildContext? Function()? contextResolver`(对话框 context 获取缝,默认 null→无 context 兜底路径)。
- **onWindowClose 决策树**(NFR-1 优先):①`!trayReady`→`exit(0)` 不变;②`settings.closeBehavior==exit`→`await stop(); exit(0)`;③`firstClosePrompted==true`→`hide()`;④未标记→重入守卫(进行中 bool)→`contextResolver` 取 context;取不到→**兜底 hide()**(注释:fail-open 到既有行为);取到→`await closePrompt(context)`:minimize→hide+标记;quit→stop+exit+标记;null→返回,不 hide 不标记。
- **drift watch**:start() 里对 changeTriggers 每流订阅→防抖 500ms(`_debounce?.cancel(); _debounce=Timer(500ms,_scanAndMark)`)→stop() 撤订阅与防抖。
- **周期扫描**:撤 `_maybeScan` 跨日门槛与 `_lastScanDay`;`Timer.periodic(Duration(minutes: settings.scanInterval.minutes), (_) => _scanAndMark())`;监听 scanIntervalListenable→cancel+重建(re-arm);stop() 撤 listener。启动 +10s 首扫保留。
- **托盘菜单撤项**:MenuItem 删「立即检查」(_kCheck 与其 case 退役),余 显示御财/退出。
- **公开 `Future<void> quit()`**:stop()+exit(0),供 AppExitPort。
- settings null 容错:所有读走内部 getter(null-safe 默认)。

### 2. notifications_bootstrap.dart + DI 接线

- `_bootstrap` 构造 TrayController 时注入:`settings: getIt<TraySettings>()`、`changeTriggers:` 两张表 watch 流(`(db.select(db.paymentScheduleEntries).watch()).map((_) {})` 与 `transactionTemplates` 同款)、`closePrompt: showFirstCloseDialog`(bootstrap 是组合根,允许 import settings 模块——组合根豁免,注释说明)、`contextResolver:` 从 router 取 navigatorKey.currentContext(读 router.dart 定位 key;若无可用的全局 key,在 router.dart 加 `final rootNavigatorKey = GlobalKey<NavigatorState>()` 供 GoRouter 用,这是允许的唯一 router.dart 改动)。
- tray.start() 后:`getIt.registerSingleton<TrayController>(tray)` + `getIt.registerSingleton<AppExitPort>(TrayAppExit(onExit: tray.stop))`(照 injection.dart 手工注册先例注释)。
- TraySettings.load():放到 app bootstrap 既有 ThemeSettings load 的同位(injection.dart 或 main——找 ThemeSettings load() 调用点同位加,注释同款)。
- **顺手修 T1 评审遗留**:app_exit_port.dart 的 exitApp 改 `try { await onExit(); } finally { exit(0); }`(stop 抛错也必退出),接口文档注释同步;app_exit_port_test 补断言(onExit 抛错→exitApp 仍以 exit 收尾——exit 不可测则断言 finally 语义:异常被吞+完成,注释说明)。

### 3. 测试

- tray_controller_test(扩或新):决策树 4 分支(fake settings 注入,window/tray 既有 mock);首关对话框三态(minimize→hide+setFirstClosePrompted(true) 一次/quit→stop 路径/null→不 hide 不标记);重入守卫(进行中二次 close 直接忽略);contextResolver null→兜底 hide;changeTriggers 用 StreamController 发 3 事件→防抖后仅 1 次 scan(验合流);间隔 listenable 变更→Timer 重建(可测 period 变化或以 listener 触发断言);菜单项枚举不含 check。
- bootstrap 接线:不强求集成测(平台门 notificationsSupported 测试端 false)——以「TrayController 构造参数默认值保证无注入也不炸」+ 单测覆盖各参数组合为线,bootstrap 手工接线以 code review 承接(注释里写明各注入对应 FR)。

## 禁区

first_close_dialog.dart 内部(T3 并行修复中)、settings_page.dart、YucaiTheme。

## 完成门

flutter analyze 无新增;新测试全绿;全量 flutter test 无回归(并行 T3 修复可能有新增断言,以其最终绿为准;遇 first_close_dialog_test 失败先甄别)。报告:文件清单/决策树测试映射/接线清单/偏差。
