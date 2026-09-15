# Design — F22 退出入口与关闭行为 + 扫描调度治本

**prototype: v1**([products/yucai-client/prototype/v1](../../prototype/v1/);Path B-fallback 自生成 HTML,契约=design-v2 既有确认产物直连)

## Context

[spec.md](spec.md)(FR-1~6 + NFR-1~3)。现状代码事实:`TrayController` 在 `notifications_bootstrap._bootstrap` 内局部构造(未进 getIt);扫描读 `paymentScheduleEntries`(join `debts`),自动记账规则在 `transactionTemplates`(经 TemplateRepoAutoRecord);`_maybeScan` 跨日门槛 + 托盘菜单「立即检查」手动逃生口;设置持久化家法 = `ThemeSettings`(@LazySingleton + flutter_secure_storage + ValueNotifier);无全局 navigatorKey(app 用 GoRouter)。

## Goals / NonGoals

- **Goals**:退出入口应用内化;关闭行为设置化+首提示;变更即扫+可配间隔(治本,撤手动项);TrayController 注入化为 F25 打地基。
- **NonGoals**:顶栏菜单按钮(spec 已裁);托盘数据头(F25);自动更新(F24);自定义标题栏;i18n;watch 相关性过滤(见 Open Questions)。

## Decisions(ADR;grill 挑战/辩护在案)

### ADR-1 变更即扫触发 = drift watch(方案 A)
- **决策**:调度器订阅 `select(paymentScheduleEntries).watch()` + `select(transactionTemplates).watch()`,防抖 500ms → 扫描(autoRecord+due 同 `_scanAndMark` 语义)。
- **理由**:零写入路径耦合(不动债务/模板 feature 代码);结构性覆盖全部变更形态(新增/编辑/删除/标记已付);offline-first 响应式惯用法;订阅生命周期照 `_netSub` 进程级先例。
- **备选**:B 写入路径 port 注入——触发面最小但**新写入路径漏接=静默缝隙复发**(本次要治的病),且给两 feature 模块加通知域依赖;C 事件总线——非仓内家法。
- **Grill**:挑战=「无关变更(如普通模板改名)也触发扫描的浪费;数据量大后是否还便宜」→ 辩护=幂等+一次本地查询+防抖合并,成本可忽略;数据量增长到查询变贵时再加相关性过滤(YAGNI,记 Open Questions)。用户拍板「同意」。

### ADR-2 跨模块面 = 最小 port(`AppExitPort`),不暴露 TrayController
- **决策**:设置模块只依赖 `abstract class AppExitPort { Future<void> exitApp(); }`(实现 `TrayAppExit` 持 TrayController,bootstrap 注册进 getIt)。settings → port,不 import notifications 内部类。
- **理由**:跨模块 port 模式是仓约束(消费方不 import 生产方内部);设置页只需要「退出」一个动词。
- **备选**:直接注册 `TrayController` 单例供 settings 消费——接口面大、方向耦合;event bus——非家法。
- **Grill**:结构步 M 深度;挑战=「为一个小动词造 port 是否过度」→ 辩护=仓约束硬性 + F25 马上要复用同一注入面(托盘数据),port 是最小稳定面。

### ADR-3 设置载体 = `TraySettings` 镜像 ThemeSettings
- **决策**:新 `core/notifications/tray_settings.dart`(或 core/settings/,实现时随包结构定):@LazySingleton + flutter_secure_storage + ValueNotifier ×3(closeBehavior[hide|exit,默认 hide]/scanIntervalMinutes[15|30|60,默认 30]/firstClosePrompted[bool,默认 false]);bootstrap `load()` 一次,`setX()` 持久化并广播。
- **理由**:与 ThemeSettings/CurrencySettings 完全同构,零新范式;ValueNotifier 使 TrayController 免轮询响应间隔变更。
- **备选**:drift 表存设置(重,启动序复杂);shared_preferences(仓内无此依赖,引新包无必要)。

### ADR-4 首关对话框从 onWindowClose 弹 = GoRouter navigatorKey
- **决策**:`onWindowClose` 里经 GoRouter 的 navigatorKey 取 context `showDialog`(await 用户选择);**取不到 context(极端时序,如路由切换中)→ 兜底直接隐藏**(fail-open 到既有行为,不阻塞关闭)。
- **实施偏差回写(T4,2026-09-15)**:「不新建全局 key」前提被证伪——router.dart 需 `rootNavigatorKey`(可变全局,buildRouter 每次换新 key:单一 GlobalKey 复用会把旧 Navigator 元素重挂进新树,app_shell_test 双构建翻车)。bootstrap 的 contextResolver 闭包在关闭时刻读当前值,生产行为不变。
- **理由**:setPreventClose 已保证关闭被拦截、可 await 后再决定 hide/exit;不新建全局 key(GoRouter 已有)。
- **备选**:全局 navigatorKey(等价但多一个全局态);不弹对话框改 OS 通知(用户已在 grill 否决)。

### ADR-5 周期扫描 = 无条件重扫 + 间隔可配重臂
- **决策**:撤 `_maybeScan` 跨日门槛,tick 每 N 分钟(TraySettings.scanIntervalMinutes)直接 `_scanAndMark`;监听 ValueNotifier,变更即 cancel+重建 `Timer.periodic`;启动 +10s 首扫保留;`_lastScanDay` 退役。
- **理由**:幂等已由 ReminderLogStore 按条目保证(spec NFR-2);门槛本就是工作量优化非通知策略。

## HLD(单元 + 接口契约)

```
core/notifications/
  tray_settings.dart      @LazySingleton TraySettings(ADR-3)
  app_exit_port.dart      abstract AppExitPort{exitApp()}(ADR-2)
  tray_controller.dart    改造:注入 TraySettings;drift watch×2+防抖;
                          onWindowClose 决策树;间隔重臂;托盘菜单撤项;
                          quit() 供 AppExitPort
  notifications_bootstrap.dart  注册 TrayController + AppExitPort 进 getIt
settings/presentation/settings_page.dart  「窗口与提醒」区(2 setting-row-seg)
                                          + 底部 btn-exit-footer
settings/widgets/first_close_dialog.dart  dialog-first-close(ADR-4)
```

依赖方向:settings →(port)notifications 抽象;notifications → localdb(drift watch,既有依赖同向);UI 原型见 prototype/v1。

## LLD(关键流程)

**onWindowClose 决策树**(spec FR-2/3 + NFR-1):
1. `!trayReady` → `exit(0)`(fail-safe 不变,不弹对话框)
2. `closeBehavior == exit` → `stop()+exit(0)`(与 FR-1 同路径)
3. `hide` 且 `firstClosePrompted == true` → `hide()`
4. `hide` 且未标记 → 取 context(取不到→兜底 hide)→ `showDialog`(barrierDismissible=false?否——×/Esc 必须=取消:barrierDismissible=true,返回 null=取消→窗口保留,**不写标记**;「最小化」→hide()+写标记;「退出程序」→stop()+exit(0)+写标记)

**drift watch 触发链**(FR-4):两表 watch 流 → 任一事件 → `debounceTimer?.cancel(); debounceTimer = Timer(500ms, _scanAndMark)`;`stop()` 时 cancel 订阅+防抖。

**间隔重臂**(FR-5):`settings.scanIntervalListenable.addListener(_rearm)`;`_rearm` = `_tick?.cancel(); _tick = Timer.periodic(Duration(minutes: n), (_) => _scanAndMark())`。

**设置页**(FR-1/2/5):「窗口与提醒」card 两行 SegmentedButton(值→TraySettings.setX);底部退出按钮 → `getIt<AppExitPort>().exitApp()`(即时,无确认——D1)。

**托盘菜单**(FR-6):items = [显示御财, 退出];`_kCheck` 及其 case 退役。

## Risks

| 风险 | 缓解 |
|---|---|
| onWindowClose 里 await 对话框期间用户再点 ✕ | window_manager 事件重复触发→对话框重入守卫(进行中标志位) |
| watch 在 e2e/测试播种时触发扫描 | 幂等+测试环境 notifier 是 fake;e2e 断言不依赖「无扫描」 |
| secure-storage 读延迟落在关闭路径 | TraySettings bootstrap 时 load 缓存 ValueNotifier,关闭时同步读缓存 |
| 撤「立即检查」是行为变更 | release note 明示;spec Grill record 已留痕 |

## Migration

默认值=现状行为(hide+30min+未标记),升级零惊讶;「立即检查」消失在 release note 说明(治本替代:变更即扫+周期扫)。

## Open Questions

- 数据量增长到本地聚合查询变贵时,watch 触发加「变更行相关性过滤」(ADR-1 YAGNI 记录)。
- 对话框期间 OS 关机/logoff 强杀——setPreventClose 是否阻断关机(实现时真机验证;若阻断需处理 `onWindowEvent` 的 close 类事件)。
