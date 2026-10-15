---
feature: f61-cycle-consumers
status: confirmed
---

# F61 消费面切换+随卡还款语义修正 — spec

> 依据:F60 周期 port + 走查三轮用户拍板(2026-10-14):①平安备用金/广发财智金=专项额度但**期供随卡还**(推翻 F59「专项池=独立结算不并卡」);②期供**自动**落卡,不手动;③还款端 **B 模式**(还款不进 app,银行自扣;卡余额含未还挂账累积,账单区块显示本期应还)。

## ADDED Requirements

### Requirement: FR-1 catchup 专项池 skip 删除(挂卡即并账)
- [ ] `catchupCardLoanMerges` SHALL 删除 `countsTowardCardLimit==false` 跳过分支:凡 subtype=card_loan 且挂接信用卡的借入债,到期期次一律自动 recordPayment 落卡;占用开关 SHALL 只影响占用统计(卡额度已用),不影响并账。既有 `runF59SpecialQuotaUnmerge` 修复器 SHALL 退役(不再回退专项池并账)。

#### Scenario: 平安四笔恢复自动并账
- GIVEN 平安四笔现金分期(counts=false)期次 09-12~10-02 已到期未并入
- WHEN app 重启触发 catchup
- THEN 到期期次自动落卡(信用卡 C 期供)+期表标还,逾期提示消失;占用统计仍排除它们(专项)

#### Scenario: 广发五笔继续并账
- GIVEN 广发五笔(counts=false,2026-10-14 置关)下期 10-19 起
- WHEN 到期
- THEN 照常自动落卡(置关不阻断并账)

### Requirement: FR-2 期供落卡单腿(无自动还款配平)
- [ ] 期供到期落卡(C,卡欠款增)SHALL 为唯一自动化;app SHALL NOT 自动生成还款 D(模式 B:银行自扣,还款不进 app);2026-09-30 历史批量配平补录为既成事实保留不动。

### Requirement: FR-3 卡详情账单区块周期化
- [ ] 卡详情账单/分期区块 SHALL 按 `billingCycleOf`(账单日锚定,拍板 A 边界)聚合呈现:区块标题=归属账期区间;「本期应还」= 该账期内已落卡期供合计+循环消费(供用户对银行自扣核对);无账单日卡回落自然月(现状兼容)。

#### Scenario: 广发账单区块按真实周期
- GIVEN 广发卡(账单日见账户字段)与 10-09/10-12 两笔期供
- THEN 账单区块区间按账单日锚定,两期供计入对应账期应还

### Requirement: FR-4 分期归属显示周期口径
- [ ] 期次/账单分组的「归属账期」标签 SHALL 经 billingCycleOf 计算(替换自然月假设);交易时间戳零改动。

### Requirement: FR-5 双卡对账复核(验收)
- [ ] 平安:补并后卡欠款增量 = 四笔到期期次合计,对银行可用复核(容差由走查确认);广发:truing 后模型自洽(期供落卡与银行同增,无 D 配平)。

## NFR

### Requirement: NFR-1 回归门
- [ ] flutter test 全绿 + analyze 基线 + `make client-e2e`;F50 占用口径回归(专项池占用排除不回归);billing_cycle 矩阵不回归。

## Feasibility

technical 可行(catchup 删分支一行级;账单区块聚合换 billingCycleOf;平安补并=重启即 catchup);economic 可行(中票 ~6 文件);operational 可行(对账复核走既有取证流程)。

## Out of scope

- 还款自动记账(模式 A) — owner: none(用户拍板 B) — excluded because: 银行自扣不进 app。
- 历史配平补录重写 — owner: none — excluded because: 既成事实;余额已 truing。
- 交易列表按账期分组重排 — owner: none(deferred) — excluded because: 归属标签(FR-4)先行,分组重排观察后议。
- e招贷 — owner: none — excluded because: 已独立账户不挂卡,catchup 天然不触及。

## Grill record

- 专项池并账语义 — challenged: F59 定案(独立结算手动还)vs 走查实证(平安备用金随卡还) — defended: 用户拍板「跟平安信用卡一起还」→两轴解耦(占用/并账),skip 删除。
- 26 号还款记录来源 — challenged: 广发逐月 C=D 配平疑似机制 — defended: 取证=2026-09-30 一次性批量补录;用户澄清平安无此记录+「不要手动」。
- 还款端 — challenged: 全自动两腿(A) vs 还款不进 app(B) — defended: 用户拍板 B(银行自扣;卡余额含未还挂账,账单区块显示本期应还)。
