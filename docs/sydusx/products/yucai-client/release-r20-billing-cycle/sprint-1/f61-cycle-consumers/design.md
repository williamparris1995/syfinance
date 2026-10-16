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


## 票内演进附录(holistic 评审 fixlist-4 补录,2026-10-16)

spec 起草时未预见、票内走查新增的四块(实现与测试均以落码为准):

1. **期次逾期口径账单感知**:`paymentEntryStatusMap`(debt_query,详情表/统计两簇消费)+ `Debt.nextPaymentDueDate`(DS `_toEntity` 期表推导,列表卡脚消费)—— card_loan 到期=下期出账日(F58 语义),出账后自由窗口不红;普通债自身日期不变。**已知限制**:boundRemote 路由 debt_mapper 不产 due 字段,卡脚对 card_loan 缺 due 时抑制负天数提示(详情页现算不受影响);mapper/proto 补字段留后续契约票。
2. **B 模式 catchup**(评审确认为 spec 范围内实现):绑定离线路由放行并账,写经 recordPayment markPending 置 pending 随批上行(PendingCollector 债行嵌套期次);pull 后幂等重跑自愈;boundRemote 不跑。
3. **走查修复×3**:还款/充值对话框候选源=仓库拉取(详情态 bloc 取不到列表);FormLeaveGuard 冻结分支(TickerMode)放行防跨分支无限弹框;跨分支链接 push→go(R19 遗留面包屑残留)。
4. **探针处置**:catchup 诊断探针轮以 WAL 三件套取证收束(平安补并早已生效,拷库漏 -wal 致误判);探针文件评审后删除。

**结构注记(后续票候选)**:月钳(+1 月短月 clamp)现存三份(catchup 内联/DS 静态/domain helper)——收敛进 core/billing 单一实现;普通债逾期边界由「到期当天红」微移为「次日起红」(新 map 用当日零点比较),方向更合理,随收敛票加注记钉测。

## FR-5 平安对账数字(ledger,2026-10-16 WAL 三件套取证)

- 平安 35k(1bc53282):09-12 期 **已并**(paid ✓,期供交易落卡);平安卡欠款 333.13 → **1,950.09**(含并入期供);四笔 1,630.46 期供交易=6/7/8/9 月各期正常并入(非重复)。
- 取证方法:拷库必连 `-wal`/`-shm` 三件套(guest-db-forensics 记忆已更新;漏 WAL 曾三次误判「未并」)。
- 广发:维持 F60 ts-gf-closeout 基线(truing 4,925.66 后期供随银行同增,模型自洽)。
- 银行侧最终复核(容差)留用户走查确认。
