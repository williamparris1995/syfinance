---
feature: f60-cycle-domain-gf-closeout
status: confirmed
---

# F60 周期域模型+广发收口 — spec

> 依据:R20 release Decisions(周期锚=建户账单日/账单日当天归下期,用户拍板 A 2026-10-14);广发对账取证(2026-10-14 走查)。

## ADDED Requirements

### Requirement: FR-1 账单周期计算单一事实源
- [ ] 纯 domain 周期计算 SHALL:给定账单日(1..31)与任意日期,返回归属账期区间 [start, end)(start=上期账单日,end=本期账单日);**账单日当天交易归下期**;账单日 30/31 在短月 SHALL 钳制为该月最后一天;计算零 IO/零 Flutter 依赖,全仓唯一实现。

#### Scenario: 账单日 20 号的常规归属
- GIVEN 卡账单日=20
- WHEN 交易日期为 2026-10-15
- THEN 归属区间 [2026-09-20, 2026-10-20)(该笔进 10-20 账单)

#### Scenario: 账单日当天归下期(拍板 A)
- GIVEN 卡账单日=20
- WHEN 交易日期为 2026-10-20(恰账单日)
- THEN 归属区间 [2026-10-20, 2026-11-20)(当天账单已出,进下期)

#### Scenario: 31 号账单日过二月
- GIVEN 卡账单日=31
- WHEN 日期为 2026-02-10(平年)
- THEN 归属区间 [2026-01-31, 2026-02-28)(二月账单日钳制为月末 28)

### Requirement: FR-2 无账单日回落自然月
- [ ] 账户无账单日(非信用卡/未填)SHALL 回落自然月周期([当月 1 日, 次月 1 日)),与 F50 既有行为逐分一致;账单日=1 的卡与自然月等价(兼容零迁移)。

#### Scenario: 账单日 1 号等价自然月
- GIVEN 平安卡账单日=1
- WHEN 任意日期
- THEN 归属区间与自然月周期完全一致(回归钉死)

### Requirement: FR-3 广发三件套收口
- [ ] 本票 SHALL 输出广发收口 TS 清单并验证:①五笔财智金「计入卡额度占用」置关(疑专项额度,照平安 35k 先例,用户银行口径确认后 app 内执行);②循环差额 2,983.48 补记清单(用户核卡近期交易);③置关+补记后重对账,app 可用额度与银行真值 45,074.34 容差 ≤ 0.01。

#### Scenario: 置关后可用跳升
- GIVEN 五笔财智金置关完成
- THEN app 广发可用 = 50,000 − 1,942.18 = 48,057.82(待补记后收敛至 45,074.34)

## NFR

### Requirement: NFR-1 测试矩阵
- [ ] 周期计算 SHALL 覆盖矩阵:账单日 {1,12,20,28,30,31} × 月边界 × 平/闰年 × 账单日当天 × 钳制日,全组合钉死。

### Requirement: NFR-2 回归门
- [ ] flutter test 全绿 + analyze 基线 + `make client-e2e`(零 proto 改动)。

## Feasibility

technical 可行(纯函数 port,照 debt_query/derived_value 先例;钳制算术有界);economic 可行(小票,~3 文件);operational 可行(TS 清单即时可执行;重对账走既有真库取证流程)。

## Out of scope

- 消费面切换(账单区块/分期落期/分组) — owner: F61 — excluded because: 依赖本票 port;分层降变异。
- 存量交易重算/迁移 — owner: none(deferred) — excluded because: 周期是视图口径,交易时间戳不动(release done criteria 4)。
- 广发 TS 执行(置关/补记操作本身) — owner: 用户 — excluded because: app 内人工操作,本票交付清单+验证。

## Grill record

- 账单日当天归属 — challenged: 主流归下期(账单已出) vs 个别行当天进账单 — defended: 用户拍板 A(归下期;与 F50 归属方向一致,1 号卡零行为变化)。
- 无账单日回落 — challenged: (事实推论)非信用卡无账单日概念 — defended: 回落自然月=现状零变化,spec 审阅确认。
- 周期锚=建户账单日 — release 级已拍(用户 2026-10-14「这在账户创建时就需要选择」),字段既有。
