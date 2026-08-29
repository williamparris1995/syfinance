# Sprint 2 — R7 定时通知

> Sprint Goal + feature roster。`/sydusx-portfolio`(2026-08-29)。

## Sprint Goal

**本地定时提醒可用**:Windows 本地通知基础设施就位,账单(debt 期次)到期有提醒,周期模板在本地模式自动生成交易(autoRecord 不再依赖 server 调度器)。

## Feature roster(依赖排序)

- [x] **feature B** 2026-08-29-b1-local-notifications — Windows 本地通知基础设施 + debt 期次到期提醒 ✅ done(2026-08-29;leanflutter 四件套[local_notifier/tray_manager/launch_at_startup/flutter_single_instance];三档策略 T-3/T-0/逾期每日+当日去重[ReminderLogs 唯一索引];托盘常驻+自启默认开+卸载清理;单实例信号文件;21 单测;2 轮 review 闭环 PASS;运行时冒烟 blocked-on-user)
- [x] **feature C** 2026-08-29-b2-auto-record-scheduler — autoRecord 本地调度器 ✅ done(2026-08-29;双模式常跑+一次性补齐[游标幂等/endDate 截断];周期算法 Dart 移植[月度钳制修正 R6 缺陷,server 用例 oracle];绑定断网=延迟落账回网即补[连通性触发];2 轮 review 闭环 PASS[Critical DI 修复+Left 失败计数])

## defer

- 移动端通知 → R8;通知设置页(粒度/免打扰)→ 后续 polish;最小化到托盘常驻 → 后续(当前语义:app 运行期间提醒,analysis grill 定)

## status: done(B+C ✅ 2026-08-29——通知基础设施/托盘常驻/autoRecord 调度全落地;运行时冒烟 blocked-on-user)
