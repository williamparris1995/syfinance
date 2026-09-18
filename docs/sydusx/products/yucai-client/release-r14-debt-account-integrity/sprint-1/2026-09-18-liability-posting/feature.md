# Feature — F36 负债记账治本——方案 A(R14 sprint-1)

> 2026-09-18。方案 A/B 用户拍板取 A(记账治本),见 [release.md](../../release.md) Decisions。

## Description

现状:借入创建**不入账**(guest 不选到账账户也不入账)、还款**部分入账**,负债账户余额 = 流水残值(dev 库实算:融e借 −¥6,795.20 vs 真实剩余 ¥24,321.02),账户详情 hero 仍显示该失真余额;账户页已绕开余额用债务实时数,两套口径并存。目标(方案 A):借入创建即全额双记(负债 +本金 / 到账资产 +本金),还款从还款账户全额过账(负债借记减少),**不变式:负债账户余额 = −剩余未还本金**;覆盖 server 记账路径 + guest 本地路径 + 离线 sync;存量 debt 关联账户余额修复迁移。

## Stories

- [ ] S1: spec/ADR——分录规则(创建/还款/利息部分)、不变式定义、与 networth DebtSource 口径合并、server+guest 双路径
- [ ] S2: 存量数据迁移——dev/生产库 debt 关联账户余额重算修复(5 户)
- [ ] S3: 实现——server 记账路径 + client 本地路径 + sync
- [ ] S4: 测试——不变式测试(创建/还款/删除回滚余额守恒)、迁移测试、e2e、全量门

## Keywords

`负债记账` `余额不变式` `liability-posting` `借入入账` `还款过账` `存量修复` `migration` `double-entry`
