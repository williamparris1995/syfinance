# Code Plan — B1 local-notifications

> inline TDD;工作目录 `yucai/client/`(worktree C:/sywt/b1-local-notifications 短路径)。

- [x] **T1 DueReminderPolicy 纯逻辑** — tier 分类(t3/t0/overdue/null)、当日去重判定、三档中文文案;表驱动单测
- [x] **T2 DueScanner 编排** — fake source/log/notifier:三档命中/已付跳过/当日去重/跨日逾期再发/空扫描;发送摘要断言
- [x] **T3 drift 侧** — ReminderLogs 表 + DriftReminderLogStore(wasSentToday/markSent 幂等)+ DriftDueSource(未付期次 join Debts;窗口过滤);drift 内存库单测
- [x] **T4 插件 adapter + DI** — LocalNotifierAdapter(薄)+ injection 注册(@LazySingleton/手写)+ pubspec 四件套依赖
- [x] **T5 bootstrap 接线** — main: single_instance + window_manager(关闭 hide)+ TrayController(托盘菜单/每日 Timer/启动首扫)+ launch_at_startup 默认注册;托盘 icon 资产
- [x] **T6 Inno 卸载清理 + 冒烟清单** — .iss [UninstallRun] reg delete HKCU Run/yucai_client;打包版冒烟 checklist(通知出现/自启/卸载清理)
- [ ] **收尾** — flutter test/analyze 基线 → code-review → commit
