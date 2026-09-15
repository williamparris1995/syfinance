# Task Brief T1 — TraySettings + AppExitPort 地基

> F22 code-plan Task1。实施者:TDD(先红后绿,每步即跑);controller 不改你的产物,评审独立。

## 环境

- 仓库 worktree:`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r8-f22`(分支 feature/r8-f22)
- 客户端:`yucai/client/`;测试命令在该目录下 `flutter test test/<文件>`;分析 `flutter analyze`。
- 注释语言:中文(仓家法);文件头 `///` 文档注释说明用途与约束。

## 交付(全部新文件,不改动既有文件——接线是 T4)

1. `lib/core/notifications/tray_settings.dart` — **镜像** `lib/core/theme/theme_settings.dart` 的结构(@LazySingleton + 注入 FlutterSecureStorage + ValueNotifier + load 幂等 + 非法值回落默认):
   - 枚举 `TrayCloseBehavior { hide, exit }`;`TrayScanInterval { minutes15, minutes30, minutes60 }`(带 `int get minutes`)。
   - 字段:closeBehavior(默认 hide)/scanInterval(默认 minutes30)/firstClosePrompted(默认 false)。
   - storage 键:`tray_close_behavior`/`tray_scan_interval`/`tray_first_close_prompted`(编码字符串)。
   - API:`load()`(bootstrap 一次);`TrayCloseBehavior get closeBehavior` + `setCloseBehavior(...)`;`TrayScanInterval get scanInterval` + `setScanInterval(...)`;`bool get firstClosePrompted` + `setFirstClosePrompted(bool)`;各自 `ValueListenable` 暴露(`closeBehaviorListenable` 等)。
   - 类文档注释写明:关闭路径同步读缓存(load 后内存值),写入才落 secure_storage。
2. `lib/core/notifications/app_exit_port.dart` — `abstract class AppExitPort { Future<void> exitApp(); }` + `class TrayAppExit implements AppExitPort`(构造注入 `Future<void> Function() onExit`;exitApp=await onExit 后 exit(0)——注意 exit 来自 dart:io,onExit 即 TrayController.stop,本任务用函数注入避免依赖具体类;文档注释说明绑定态/guest 均可用)。
3. DI:优先 `@LazySingleton` 注解 + `dart run build_runner build --delete-conflicting-outputs` 重生成 injection.config.dart;**若 build_runner 在本环境失败**,回退 `lib/core/di/injection.dart` 手工 `getIt.registerSingleton<TraySettings>(...)`(照 41-88 行先例,注释说明原因)。二选一后 ledger 记录走了哪条。
4. 测试 `test/core/notifications/tray_settings_test.dart` — **镜像** `test/core/theme/theme_settings_test.dart` 的 fake storage 范式:默认值断言(未 load 前)/load 持久化往返/非法持久化值回落默认/三个 set 持久化+listenable 通知/firstClosePrompted 翻转。另 `app_exit_port_test.dart`:fake onExit 被调用后进程退出——**不真 exit**,仅断言 onExit 被 await(用完成 Completer 验证顺序);exit(0) 路径以注入点设计保证,不测进程死亡。

## 约束

- 不改 tray_controller.dart / notifications_bootstrap.dart / settings_page.dart(T4/T2 的事)。
- 英文标识符,中文注释;无 CJK 进 log 字符串(本任务无日志则无此虑)。
- 完成门:`flutter analyze` 无新增 issue;`flutter test test/core/notifications/` 全绿;全量 `flutter test` 不回归(基线全绿)。
- 产出报告:改动文件清单 + 测试输出摘要(通过数)+ DI 走的哪条路径。
