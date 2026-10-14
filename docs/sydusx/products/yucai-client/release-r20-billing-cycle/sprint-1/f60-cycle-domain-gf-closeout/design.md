# Design: F60 周期域模型+广发收口

prototype: none(纯 domain 计算票,零 UI 面;消费面在 F61)

## Context

F50 自然月简化 → R20 每卡真实周期(账单日锚,拍板 A 边界)。跨模块消费(account 卡详情/debt 分期落期/report 分组)→ 归属 core 层共享(照 `core/recurrence/next_after` 先例)。零 proto/schema。

## Goals / Non-Goals

**Goals**:周期计算单一事实源(FR-1/2)+ 矩阵测试(NFR-1)+ 广发 TS 清单与对账验收(FR-3)。
**Non-Goals**:消费面接线(F61)/存量重算/TS 执行本身(用户)。

## Decisions (ADRs)

- **ADR-1 归位 `lib/core/billing/`(新子包)**:跨模块共享的纯日历算术,照 recurrence 先例(core 无 Flutter 依赖);`billing_cycle.dart` 单文件。*Alternatives*:account/domain(跨模块消费方 import 生产方,违 port 方向)/debt/domain(同)。
- **ADR-2 契约 = 值对象 + 纯函数**:`class BillingCycle { final DateTime start; final DateTime end; }`(日期归一:当日零时,区间左闭右开)+ `BillingCycle billingCycleOf(DateTime date, {int? billingDay})`。billingDay null/越界(非 1..31)→ 自然月回落(FR-2);钳制:账单日 > 当月天数 → 当月最后一天;**当天归下期**(拍板 A:`date.day == 实际账单日` → 以 date 为 start 的新区间)。*Alternatives*:扩展 recurrence Rule(周期语义不同:账期是日历区间非复发生成)。
- **ADR-3 TS 清单落 feature 目录 `ts-gf-closeout.md`**:三件套逐项(操作路径/预期数/验收公式),用户 app 内执行后我方真库取证复验(走 guest-db-forensics 流程:拷贝→查询→比对 45,074.34)。

## HLD

| 单元 | 层 | 职责 |
|---|---|---|
| `core/billing/billing_cycle.dart` | client core | BillingCycle 值对象 + billingCycleOf 纯函数(全仓唯一) |
| `test/core/billing/billing_cycle_test.dart` | 测试 | 矩阵(NFR-1:6 账单日×月界×平闰年×当天×钳制) |
| `ts-gf-closeout.md` | feature docs | 广发三件套 TS 清单+验收公式 |

无依赖方改动(F61 接线时才消费)。

## LLD

```dart
/// 归一:DateTime 取 date-only(零时)。
/// 实际账单日 = min(billingDay, 当月天数)。
/// 若 date.day == 实际账单日 → 区间 [date, 次实际账单日)  // 拍板 A:当天归下期
/// 否则找 ≤ date 的最近实际账单日 s → 区间 [s, 下一个实际账单日)
/// billingDay null 或 ∉ 1..31 → 自然月 [当月1日, 次月1日)
```

跨月步进:从 s 的 (年,月) 出发推下一账单日(月+1 溢出进年;日钳制);「找最近 s」:当月实际账单日 ≤ date.day ? 当月 : 上月(日钳制后比较)。

## Risks / Trade-offs

- [钳制比较 subtlety(31 号卡 2 月:s=1/31,date=2/10 → 上月起点)] → 矩阵显式覆盖该组合;实现以「上月实际账单日」为锚而非字面日。
- [F61 前无消费方,死代码风险] → F60 周期内即被 ts-gf-closeout 的对账推演消费(手工验证用例引用 port 计算);F61 排期紧随。

## Migration Plan

零迁移(新纯函数,无调用方)。

## Open Questions

无(拍板 A 已闭;短月口径由 NFR-1 矩阵钉死)。
