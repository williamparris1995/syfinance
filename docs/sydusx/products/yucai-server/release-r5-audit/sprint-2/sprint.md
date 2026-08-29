# Sprint 2 — 05 DB 完整性约束 + 06 财务计算正确性

> Sprint Goal + feature roster。`/sydusx-portfolio` sprint planning(2026-08-23)。
> 源 ticket [.scratch/yucai-audit/issues/05](../../../../../../.scratch/yucai-audit/issues/05-db-integrity-constraints.md) + [06](../../../../../../.scratch/yucai-audit/issues/06-financial-calculation-correctness.md)。

## Sprint Goal

**数据完整性**(05:ent 同模块 FK+Min(0)+UNIQUE+Immutable+DeleteAccount 引用拒绝+软删索引)+ **财务计算正确性**(06:portfolioXIRR 主指标切换+XIRR 归一化/bracket/Brent+TWR 分段链乘+Round 精度+真实样本 oracle)。

## Feature roster(依赖排序)

- [x] **feature E** 2026-08-23-f1-ent-schema-integrity — 05 决策 1/2/4/5 前半:同模块 ent edge FK+OnDelete / 金额 field.Min(0) 清单 / UNIQUE 4 项(User.email·Backup.filename·BudgetItem·PaymentSchedule)/ FK 列 Immutable / 软删表 partial unique;regen+既有数据兼容验证 ✅ done(2026-08-23;9 Immutable 合法回退;挖出并修复 UpdateTransaction uuid.Nil entries 存量 bug;scripts/clean-before-r5-e.sql 升级前置清理+冒烟测试;review PASS-with-nits 修复后 merge)
- [x] **feature F** 2026-08-23-f2-delete-account-guard — 05 决策 5 后半:DeleteAccount 拒绝有引用(查 transaction/holding/budget/debt 引用方)+ orphan 清理测试;version CAS 现状 grep 确认(决策 3 已纠正误判) ✅ done(2026-08-23;六源 port[含 goal/template 扩展]/fail-closed/DeleteByTenant 保留;review PASS-with-nits 修复后 merge)
- [ ] **feature G** 2026-08-23-f3-xirr-twr-correctness — 06 决策 2/3/4:XIRR 入口归一化+自适应 bracket+Brent;TWR 零端值 sentinel+清仓分段链乘+<-1 防御;AmountCents math.Round+等额本金均摊;真实样本 oracle(大额 1e8/清仓重建/Excel 对拍) `claimed: zcode-main 2026-08-29`
- [ ] **feature H** 2026-08-23-f4-cagr-primary-switch — 06 决策 1:portfolioXIRR 切主指标;portfolioCAGR 降级辅助+口径标注(「仅当前持仓成本→市值」;client UI 重命名/tooltip 属 R5 scope 外——server DTO 层就位+client defer 记档);依赖 G(XIRR 修后数值稳定)

**defer**:TimeMixin 抽取(→10 A10)/ SyncLog·SyncDevice unique(→16 sync 重开)/ F12-F13 P2 / client UI 口径(client defer)。

## status: in-progress(E/F done 2026-08-23;next:feature G xirr-twr-correctness)
