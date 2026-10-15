# Design: F61 消费面切换+随卡还款语义修正

prototype: none(数据聚合口径变化,布局照既有 T8 账单周期面板;无新 UI 面)

## Context

F60 周期 port 就绪;三轮走查拍板(专项池随卡还/期供自动/还款 B 模式)。账单日字段全库在位(accounts.credit_billing_day:广发 6/平安 1/招行 5/工行 28)。

## Goals / Non-Goals

**Goals**:FR-1..5(catchup skip 删除/单腿落卡/账单面板周期化/归属标签周期口径/双卡对账复核)。
**Non-Goals**:还款自动记账(B 模式已裁)、历史配平重写、交易列表分组重排、e招贷。

## Decisions (ADRs)

- **ADR-1 catchup 两轴解耦**:删除 `!countsTowardCardLimit` 跳过分支(挂卡即并账);`runF59SpecialQuotaUnmerge` 修复器**退役**(调用点移除+函数标注 deprecated 留档,不删代码——幂等标记防重启竞态重放)。*Grill*:F59 定案被 10-14 走查实证推翻(专项池=额度维度,并账=账单维度,两轴独立)。
- **ADR-2 账单面板接周期 port**:T8 `CreditCardStatementBreakdown` 的区间计算改 `billingCycleOf(now, billingDay: account.creditBillingDay)`(替换自然月构造);「本期应还」聚合窗随之周期化;无账单日回落自然月(port 内建)。*Alternatives*:面板内自写区间算术(违单一事实源)。
- **ADR-3 归属标签轻量接**:期次/账单文案中的「本月/次月」类自然月措辞,凡由 breakdown 派生者随 ADR-2 自动周期化;独立硬编码处逐点换 port(仅显示层,零数据改动)。

## HLD

| 单元 | 层 | 职责 |
|---|---|---|
| `debt_local_ds.catchupCardLoanMerges` | client debt data | 删 skip 分支 |
| `repairs.runF59SpecialQuotaUnmerge` 调用点 | beforeOpen 管道 | 退役 |
| T8 breakdown 推导(account 域共享推导) | client account | 区间改 billingCycleOf |
| account_detail 账单面板 | presentation | 标题/区间随推导(被动) |

## LLD

- catchup:删 `if (!row.countsTowardCardLimit) continue;` 与 F59 注释块,头注释补两轴解耦说明。
- breakdown:定位区间构造处(自然月 DateTime(y,m,1) 模式),替换为 `billingCycleOf(DateTime.now(), billingDay: a.creditBillingDay)`;断言窗口含端点(拍板 A)。
- 平安补并:无专门 repair——重启 app 即 catchup 自然补(幂等=期次 paid);验收走真库取证(卡欠款增量=四笔到期期次合计)。

## Risks / Trade-offs

- [平安补并后卡欠款跳增] → 预期行为(与银行已用对齐);对账复核容差走查定。
- [F50 占用回归] → 占用统计仍按 counts 开关(不动),专项池排除不变,回归钉死。
- [T8 面板既有断言(自然月区间)] → 随周期化更新,广发 6 号/平安 1 号两口径各钉。

## Migration Plan

无迁移;重启即生效(catchup 补并+面板新区间)。

## Open Questions

无。
