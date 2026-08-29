# Spec — B2 auto-record-scheduler(R7 sprint-2 feature C)

> pivot A 定时通知主线收官件;grill 定案(2026-08-29):双模式常跑(离线完整宪法)、一次性补齐、通知复用 B 通道。
> branch `feature/b2-auto-record-scheduler`,worktree `C:/sywt/b2-auto-record-scheduler`。

## Problem

本地模式无周期模板调度:autoRecord 模板只在 server 有执行者(`template/scheduler`,24h tick);R6 本地模式 server 不在场,周期账(房租/工资/订阅)永远不自动记。绑定用户断网时同样哑火。

## 现状盘点(2026-08-29)

- **server 语义**(`template/scheduler/scheduler.go` + `application/service.go`):FindDue(`autoRecord && !paused && NextDate<=today`)→ RecordTransaction(单笔交易+NextDate 前进,单 DB 事务)+ `template_record_log` UNIQUE 防并发 tick;1 天 1 笔补齐(24h tick 副产品)。
- **周期算法**(`domain/entity.go`):Weekly=+7d;Monthly=addMonthsClamped(月加+billingDay 钳制月末);Yearly=+1y;**Custom=+1d 存根(忽略 CycleDays 字段——server 侧缺陷,client 按正确语义 cycleDays 天移植,分歧记档)**。
- **client 数据面**:drift `TransactionTemplates` 全量列(cycle/cycleDays/billingDay/nextDate/startDate/endDate/autoRecord/paused/lastTransactionId/direction/source/destination/amountCents/category);transaction/template 双源 repo(R6)可写穿透;SessionModeTracker.isGuest;B 的通知 port 与托盘 30min tick 在位。

## FRs

- **FR-1 本地调度器**:双模式常跑(guest/绑定一律本地执行——离线完整);到期判定镜像 server 三条件;**一次性补齐**:单模板 while `nextDate ≤ today && (endDate 未过)` 逐周期「生成交易+推进 nextDate」;同日重跑零新增(nextDate 游标即幂等);`lastTransactionId` 写最近生成。
- **FR-2 写路径**:交易经 transaction 双源 repo(本地必写;绑定模式既有穿透上行);模板 nextDate/lastTransactionId 更新经 template 双源 repo(同样穿透)。
- **FR-3 触发时机**:启动延迟 10s 首跑 + 30min tick 跨日检查 + 托盘「立即检查」顺带;单模板失败捕获继续其余(镜像 server 容错)。
- **FR-4 通知**:复用 B 的 `ReminderNotifier` port——单笔「已自动记账:{模板名} ¥{金额}」;多笔补齐「已自动补记 N 笔:{模板名}」。
- **FR-5 周期推进算法**:Dart 镜像 Weekly/Monthly(addMonthsClamped 语义)/Yearly;**Custom 按 cycleDays 天**(纠正 server 存根,见盘点);server 既有测试用例作移植 oracle。

## NFRs

- 离线完整:绑定+断网照记,回网经穿透上行(不为同步让路)。
- 错误隔离:调度失败降级不炸 app(B 同款守卫);`flutter test` 基线不退化;零 server 改动。
- 日志英文(若有);UI/通知文案中文(ADR-006)。

## 测试计划

- 周期算法表测(oracle=server 用例):weekly/monthly 钳制(1/31→2/28)/yearly/custom-cycleDays/月度 billingDay。
- 调度器单测(fake repo/notifier):到期判定三条件、一次性补齐 N 笔(断网 3 周场景)、endDate 截断、同日重跑零新增、单模板失败继续、paused/autoRecord=false 跳过。
- 接线:tray tick 联动(逻辑层可测部分);通知文案断言。
- 打包版人工冒烟:造月度模板(nextDate=昨天)→ 启动 → 交易生成 + toast + nextDate 前进;绑定模式冒烟(上行)。

## Grill record(2026-08-29)

0. **绑定+断网的真实机制(review R1 修正)**:原提案假设"本地写+写穿透上行"——经查 R6 镜像方向为远端→本地(本地写无上行管线,上行属 ticket 16)。实际机制:**绑定+断网 = record Left → 游标不动 → 零丢失;回网后调度器一次性补齐该期间全部期次**。降级为"延迟落账"而非"当场落账"(guest 模式仍当场落账);数据不丢不重,无需 16 的对账基础设施。grill #1 的"离线完整"以该形态达成。

1. **双模式常跑(绑定不静默)** — 挑战:绑定+在线时 server 调度器同跑有并发双记窗口;辩护(用户):「离线为什么要联网,首先保障离线完整功能可用」——离线完整是宪法 → 本地双模式执行,双记去重 defer ticket 16(跨端写合并同题;server 未部署现状零威胁)。
2. **一次性补齐(非 1 天 1 笔)** — 用户拍板;批量汇总通知缓冲观感;endDate 自然截断无雪崩(个人模板月级频率)。
3. **Custom 周期按 cycleDays** — server CalculateNextDate 的 Custom=+1d 存根(忽略 CycleDays)属缺陷;client 按字段本义移植,分歧记档(server 修复候选,不在本 R7 零改动边界内动)。

## Scope boundary(排除即决策,逐条有主)

| 排除项 | 归属 | 理由 |
|---|---|---|
| 绑定+在线且 server 调度器同跑的并发双记去重 | ticket 16 | grill #1;server 未部署现状零威胁;sync engine 同题一并解 |
| server CycleCustom 存根修复 | 后续 server 线 | R7 零 server 改动;记档为修复候选 |
| 通知粒度/免打扰设置 | polish | 常量先行 |
| server 调度器停用开关 | 不做 | 无部署即无威胁 |
| Android 调度 | R8 | 平台线 |

## 可行性

- **Technical: GO** — 模型列已全量在本地表;算法有 server oracle;双源写路径既有。
- **Economic: GO** — 1-2 天。
- **Operational: GO** — 零部署零迁移(schema 沿用 v2)。
