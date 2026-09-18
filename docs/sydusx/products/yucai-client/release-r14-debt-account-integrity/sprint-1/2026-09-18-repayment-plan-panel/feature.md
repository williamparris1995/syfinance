# Feature — F35 贷款账户详情页还款计划面板(R14 sprint-1)

> 2026-09-18。

## Description

现状:`account_detail_page.dart` 贷款类账户的类型专属面板是占位「待 payment_schedule 模块接入」(投资类持仓列表同为占位,本票不做)。目标:按 accountId 关联债务(一户可多笔)拉取 payment schedule,复用债务模块现成数据源/组件(`AmortizationPreview`、债务详情页 schedule 渲染)在账户详情页聚合展示还款计划;近期交易面板已接入无需动。纯 client。

## Stories

- [ ] S1: spec——数据源(repo.getByAccount 聚合 or 按债逐笔)、多笔聚合展示形态、空态
- [ ] S2: 实现——贷款类账户详情还款计划面板
- [ ] S3: 测试——面板渲染单测 + e2e(还款后计划联动)+ 全量门

## Keywords

`还款计划` `payment-schedule` `账户详情` `account-detail` `贷款账户` `repayment-plan` `amortization`
