# Code Plan — F22 退出入口与关闭行为 + 扫描调度治本

> 来源:[spec.md](spec.md) FR-1~6/NFR-1~3 + [design.md](design.md) ADR×5/LLD。原型:prototype/v1。
> 复杂度门:跨模块(core/notifications ↔ settings ↔ DI)→ SDD(逐任务派发 + per-task 双轴评审)。
> 串行依赖:T1(地基)→ T2/T3 并行候选 → T4(控制器改造收口)→ T5(全量门)。
> 客户端家法:flutter_bloc/getIt/注释中文/测试文件镜像 lib 路径。

## Tasks

- [x] **T1 设置与退出的地基**(S1+S2 后端半):新 `core/notifications/tray_settings.dart`(TraySettings @LazySingleton,镜像 ThemeSettings:closeBehavior[hide|exit 默认 hide]/scanIntervalMinutes[15|30|60 默认 30]/firstClosePrompted[默认 false];secure_storage 键 `tray_close_behavior`/`tray_scan_interval`/`tray_first_close_prompted`;load/set×3;非法值回落默认) + 新 `core/notifications/app_exit_port.dart`(`abstract class AppExitPort{Future<void> exitApp();}`)+ `TrayAppExit` 实现(持 TrayController 引用→stop()+exit(0)) + injection.dart 注册(bootstrap 后手动注册单例,照 ValueNotifier 先例)。
  测试:`test/core/notifications/tray_settings_test.dart`(默认值/持久化往返/非法值回落/mocked storage——照 theme_settings 测试范式)。
- [x] **T2 设置页 UI**(S2 前端半):`settings/presentation/settings_page.dart` 新「窗口与提醒」card(两行:关闭按钮行为 SegmentedButton 2 段/提醒检查频率 3 段,值↔TraySettings.setX 实时持久化) + 页面最底 `btn-exit-footer`(negSoft 底+neg 描边,即时退出无确认→AppExitPort.exitApp();语义色走 YucaiTheme,禁裸色)。
  测试:settings_page_test 增断言(区标题/两 SegmentedButton 初值与切换持久化调用/退出按钮存在且点击调 port——getIt 注册 fake)。
- [x] **T3 首关对话框**(S3):新 `settings/widgets/first_close_dialog.dart`(dialog-first-close:barrierDismissible=true;返回 enum{minimize,quit,null=cancel};主=最小化到托盘[btn-primary 语义],次=退出程序[destructive 文字钮])。
  测试:first_close_dialog_test(三态:最小化/退出/关闭返回 null;文案断言含「系统托盘」)。
- [x] **T4 TrayController 改造收口**(S1+S3+S4+S5+S6 逻辑半):`tray_controller.dart`——①注入 TraySettings;②onWindowClose 决策树(!trayReady→exit / exit 行为→stop+exit / 已标记→hide / 未标记→经 GoRouter navigatorKey showDialog(await;重入守卫;无 context 兜底 hide);选择→hide 或 stop+exit + setFirstClosePrompted(true);null=返回不动);③drift watch×2(paymentScheduleEntries/transactionTemplates)→防抖 500ms→_scanAndMark;stop() 撤订阅;④撤跨日门槛,Timer.periodic(scanIntervalMinutes)无条件 _scanAndMark + listenable 重臂;⑤托盘菜单撤 _kShow 之外的 _kCheck(余 显示/退出);⑥quit() 公开供 AppExitPort。bootstrap 接线:构造注入 settings/db watch 表、注册 getIt。
  测试:tray_controller_test 扩(决策树四分支/首标记只写一次/防抖合流/重臂周期变化/菜单项枚举无 check;drift watch 用内存库真表触发)。
- [ ] **T5 全量门与覆盖对账**(S7):spec FR/NFR ↔ 测试映射表落 ledger;`flutter analyze`(0 新增)+ `flutter test` 全量绿;`make client-e2e` 回归(模块修改标准门)。

## 接口契约(消费/生产)

- 生产:`TraySettings`(T1)、`AppExitPort`(T1)、`FirstCloseDialogResult`(T3)、`TrayController.quit()`(T4)。
- 消费:settings_page→AppExitPort+TraySettings;tray_controller→TraySettings+AppDatabase(watch)+GoRouter key。
- 禁:settings import tray_controller 具体类(port 之外零耦合)。

## Fix-loop:每任务 1-3 轮 resume / 4-5 换新 / cap5→breaker。Ledger:code-ledger.md。
