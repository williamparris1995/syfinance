# Spec — B1 local-notifications(R7 sprint-2 feature B)

> pivot A 定时通知主线;grill 两轮定案(2026-08-29):触发语义=托盘常驻路线("不能错过"=不依赖用户开 app;电脑关机日不提醒为物理边界),三档提醒策略。
> branch `feature/b1-local-notifications`,worktree `C:/sywt/b1-local-notifications`(短路径,Flutter Windows 构建约束)。

## Problem

到期债务/信用卡账单无任何提醒:debt 期次(`PaymentScheduleEntries.dueDate`)到期/逾期只有打开 app 主动查看才可见;本地模式下 server 调度器不在场,template autoRecord 也无本地调度(sprint-2 feature C)。

## 现状盘点(2026-08-29)

- 本地数据:drift `PaymentScheduleEntries` 含 `dueDate`;debt 本地双源 repo 就绪。
- 通知包生态(research):`local_notifier`(leanflutter,Windows/macOS/Linux,AppFlowy 生产背书);Windows toast 需 AUMID+开始菜单快捷方式(Inno 已建,初始化对齐即可);`tray_manager`/`launch_at_startup`/`window_manager` 同生态配套。
- 客户端 lifecycle:关闭窗口=退出进程(无托盘/自启概念)。

## FRs

- **FR-1 通知基础设施**:`local_notifier` 封装为 client 内 notification port(domain/presentation 不直接依赖插件;测试可替换 fake);初始化时 AUMID/应用名与安装器快捷方式对齐。
- **FR-2 到期扫描器**:扫描本地 drift `PaymentScheduleEntries`(未付期次)→ 按三档策略发提醒——**T-3(到期前 3 天)一次 / T-0(当天)一次 / 逾期未付每日一次**(策略常量集中一处);**去重**:同期次同档当日已发不再发(持久化通知记录);触发时机=启动后、常驻期每日定时、托盘菜单手动"立即检查"。
- **FR-3 托盘常驻**:`tray_manager` 托盘图标+菜单(显示御财/立即检查提醒/退出);关闭主窗口=最小化到托盘;`launch_at_startup` 开机自启默认开启;Inno 卸载清理自启注册(扩展 .iss 卸载段)。
- **FR-4 单实例**:二次启动(自启+手动双开)→ 唤起既有实例窗口后新进程退出。
- **FR-5 提醒内容**:债务名 + 应还金额(本币) + 「3 天后到期/今日到期/已逾期 N 天」;点击通知聚焦主窗口。

## NFRs

- 纯本地(离线可用,零 server 改动);`flutter test` 基线不退化 + `analyze` 不新增;`go test ./...` 全绿(不受影响)。
- 退出托盘=真正退出(无僵尸进程);通知文案中文直写(ADR-006)。
- 策略常量(T-3/T-0/逾期每日)单点定义。

## 测试计划

- 扫描器单测(fake 数据源):T-3/T-0/逾期三档命中与不命中、去重(同日重扫不重发、跨日逾期再发)、已付期次跳过。
- 通知 port 单测:fake notifier 断言内容(名称/金额/相对天数文案)。
- 单实例/托盘:逻辑层可测部分(单实例 handshake 状态机);平台行为人工 checklist。
- 打包版人工冒烟:安装→自启注册→托盘→到期数据造数→通知出现→卸载清理。

## Grill record(2026-08-29)

1. **触发语义 A(app 运行时)被否** — 挑战:A 语义"开着才提醒"与需求"不能错过"冲突;辩护(用户):到期债务/信用卡账单提醒不能错过 → 升级为常驻路线。
2. **C(托盘常驻+自启)吸收进 B,B(任务计划无头+补跑)defer** — 挑战:B 抗崩+错过补跑更强;辩护:leanflutter 三件套专为组合设计、复杂度远低;"不能错过"的可实现语义=不依赖用户开 app(电脑关机日任何方案都不可提醒,物理边界);实测不够再 R8 加固。
3. **三档策略 T-3/T-0/逾期每日** — 默认常量,设置页后续;信用卡账单=debt 期次语义(domain 现状)。

## Scope boundary(排除即决策,逐条有主)

| 排除项 | 归属 | 理由 |
|---|---|---|
| 任务计划补跑(错过后开机补发) | R8 视实测 | grill #2;电脑关机日不提醒为物理边界,下次开 app 可见 |
| 通知设置页(粒度/免打扰/声音) | polish | 策略常量先行 |
| 点击通知深跳详情页 | polish | 本期聚焦主窗口 |
| Android/移动端通知 | R8 | 平台线 |
| email/push 渠道 | 不做 | 无需求证据 |

## 可行性

- **Technical: GO** — leanflutter 三件套生产成熟(AppFlowy/Spotube 先例);本地扫描数据面已在。
- **Economic: GO** — 2-3 天,sprint-2 主体。
- **Operational: GO** — Inno 资产可扩展卸载清理;无 server 影响。
