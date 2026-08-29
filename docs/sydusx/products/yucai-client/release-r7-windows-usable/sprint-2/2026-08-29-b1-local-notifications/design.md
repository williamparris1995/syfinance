# Design — B1 local-notifications(R7 sprint-2 feature B)

> 消费 [spec.md](./spec.md)(ab6944ed)。新模块 `lib/core/notifications/`(cross-cutting 先例:connectivity/session_mode)。

## Decisions(ADRs)

- **ADR-1 包选型 leanflutter 四件套**:`local_notifier`(toast)+ `tray_manager`(托盘)+ `launch_at_startup`(自启)+ `single_instance`(单实例信号)——同生态、AppFlowy/Spotube 生产先例;`window_manager` 处理关闭=最小化。备否:flutter_local_notifications(Windows 支持弱且不合流)、任务计划无头方案(grill #2 defer)。
- **ADR-2 端口化隔离插件**:domain 逻辑(policy/scanner)只依赖三抽象——`DueScheduleSource`(数据)/`ReminderLogStore`(去重)/`ReminderNotifier`(发送);插件 adapter 在 data 侧,DI 注入 fake 即测。镜像 connectivity_gateway 先例。
- **ADR-3 数据面直查 drift**:扫描器不经 debt 双源 repo(远端模式下去本地库即真相——提醒属本地职责);`PaymentScheduleEntries`(paymentDate=应还日,paid 过滤)join `Debts` 取名。去重持久化=新表 `ReminderLogs`(entryId+tier+sentDate,当日幂等)。
- **ADR-4 自启默认开 + 卸载清理**:launch_at_startup appName 固定 `yucai_client`(HKCU Run);.iss 增 `[UninstallRun]` reg delete(HKCU Run /v yucai_client)。重装不误删(install 侧不碰,仅 app 运行时写)。
- **ADR-5 调度**:启动后延迟首扫 + 常驻期每日 Timer(墙钟跨日触发)+ 托盘"立即检查"手动口。

## HLD

```
main.dart ── bootstrap: single_instance(次实例→show 主窗→exit)
   ├─ window_manager(关闭→hide)
   ├─ tray_controller(托盘菜单:显示/立即检查/退出;每日 Timer)
   └─ bootstrapNotifications(直构,不经 getIt —— 模块无 getIt 消费方,死注册更差;review R1 裁决)
        ├─ DueReminderPolicy(纯函数:tier/应发/文案)      ← TDD 核心
        ├─ DueScanner(编排:source→policy→log→notifier)   ← TDD 核心
        ├─ DriftDueSource(AppDatabase join)               ← drift 内存库测
        ├─ DriftReminderLogStore(ReminderLogs 表)         ← 同上
        └─ LocalNotifierAdapter(local_notifier 插件)      ← 薄,冒烟
```

依赖方向:scanner→抽象(ADR-2);插件仅 adapter;presentation(tray 菜单回调)→service。

## LLD 要点

- **Policy**:`tierFor(today, paymentDate)` → `t3`(差 3 天)/`t0`(差 0)/`overdue`(已过)/null;`shouldSend(tier, wasSentToday)`——t3/t0 当日一次,overdue 每日(自然由"当日一次"覆盖);文案:「3 天后到期」「今日到期」「已逾期 N 天」+ 标题「御财·{债务名}」+ 金额(totalCents 元)。
- **Scanner**:`scan(today)` → source.unpaidDueCandidates() → per entry: tier → skip if null/paid → logStore.wasSentToday? skip : notifier.show + markSent。返回发送摘要(可测断言)。
- **ReminderLogs**:`(id auto, entryId text, tier int, sentDate text yyyy-mm-dd)`,查询 `wasSentToday = select where entryId+tier+today`。
- **Tray**:菜单中文;退出=dispose tray+真退(exit(0));托盘 icon 资产 `assets/tray_icon.ico`。
- **Single instance**:`single_instance` 信号回调→window_manager.show()+focus;次实例直接 return exit。

## Risks

| 风险 | 缓解 |
|---|---|
| AUMID/快捷方式不齐 toast 不显 | local_notifier setup 与 Inno 快捷方式名对齐;打包版冒烟 checklist |
| 关闭→hide 后用户"找不到退出" | 托盘菜单首项=显示;退出项明确 |
| 注入 codegen(injection.config)漂移 | 走既有 flutter-build-runner;手写第三方注册区追加 |

## Migration

无 DB 迁移冲突(纯新增表);Inno .iss 增量段。
