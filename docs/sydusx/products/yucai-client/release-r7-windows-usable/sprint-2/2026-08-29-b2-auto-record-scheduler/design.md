# Design — B2 auto-record-scheduler(R7 sprint-2 feature C)

> 消费 [spec.md](./spec.md)。核心简化:R6 已有 `templateRepository.record()`(drift 单事务:建交易+_advance 推进+lastTransactionId+version,双源穿透)——本 feature = 调度编排层 + 算法修正 + 通知。

## Decisions(ADRs)

- **ADR-1 复用 record() 单笔语义**:调度器=「找到期 → 循环 record() 直到 nextDate>today(endDate 截断)」;不重写交易生成/推进落库。绑定模式穿透由 repo 既有 `_mirrored` 承担(FR-2 零新管线)。
- **ADR-2 算法修正进 `_advance`**(R6 镜像缺陷):月度从「Dart 构造器滚动」改为 server `addMonthsClamped` 语义(月末日钳制+billingDay);custom 已按 cycleDays(优于 server 存根,维持)。抽出纯函数 `advanceNextDate(current, cycle, cycleDays, billingDay)` 供 ds 与测试共用;oracle=server 测试用例移植。
- **ADR-3 调度器落位 `lib/core/notifications/`**:复用 B 的 tick/通知基建与错误隔离模式;依赖抽象 `AutoRecordTemplates`(list/record 两方法,template repo 结构满足)。
- **ADR-4 触发三口**:bootstrap 延迟 10s、复用 tray 30min tick(跨日检查)、托盘菜单「立即检查」(文案微调含记账)。

## HLD

```
TrayController tick/手动 ─┐
bootstrap 延迟 10s ──────┼→ AutoRecordScheduler.run(today)
                          │    ├─ templates.list() 过滤(autoRecord && !paused && nextDate≤today)
                          │    ├─ per template: while nextDate≤today && ≤endDate:
                          │    │     repo.record(id) → 收集(模板名,金额)
                          │    │   单模板 try/catch 继续
                          │    └─ 通知:1 笔「已自动记账」/ N 笔「已自动补记 N 笔」
                          └─ ReminderNotifier(B 的 port)
```

## LLD 要点

- `advanceNextDate`:monthly=月加+billingDay(≤0 取当日)+月末钳制;weekly=+7d;yearly=+1y;custom=+cycleDays;UTC 日粒度。ds `_advance` 改为委托。
- Scheduler 金额来源:record() 前读模板行(amountCents);通知文案复用 policy 的 `_formatYuan` 千分位(提为可复用)。
- endDate 截断:发生日期(推进前 nextDate)≤ endDate 才记;endDate 为空不限。
- 通知去重:调度本身幂等(游标),通知不重复;补齐批只发一条。

## Risks

| 风险 | 缓解 |
|---|---|
| `_advance` 语义变更影响既有手动 record | 月度钳制与滚动在常规日期等价,仅月末溢出场景更正确;oracle 测试锁定 |
| record() 失败半途(catchup 中途断电) | 单笔原子(drift tx);重跑从游标续,不重不漏 |
| 绑定+在线 server 并发双记 | spec 边界:ticket 16(server 未部署零威胁) |

## Migration

无 schema 变更(沿用 v2)。
