# Feature — F33 债务 subtype 全链路可编辑 + 9 类扩展(R14 sprint-1)

> 2026-09-18。分类集合 9 类用户已拍板(见 [release.md](../../release.md) Decisions)。

## Description

现状:subtype 创建后**不可改**——`debt_form_page.dart` 编辑模式 chips 只读(注释:UpdateDebtParams 不携带 subtype),proto `UpdateDebtRequest` 无 subtype 字段;种类仅 5 类,用户数据已出现「贷款账户挂房贷标签」的维度错位样本。目标:①种类扩至 9 类(新增 credit_loan 信用贷款 / cash_installment 现金分期 / consumption_loan 消费贷 / business_loan 经营贷);②subtype 进入更新链路,用户可在 app 内改存量债务分类。subtype 全链纯 string 透传(server dto verbatim),`DebtSubtypes` 常量表即单一事实源。

## Stories

- [ ] S1: spec/设计——proto `UpdateDebtRequest` 加 `subtype` 字段 + regen(高风险路径:sync.pbjson F13 手工补丁重套;client+server 双侧生成物)
- [ ] S2: server——UpdateDebt handler/params 接线 subtype(repo 层 `SetSubtype` 已存在,缺入参通路)
- [ ] S3: client——UpdateDebtParams/repo/remote DS/local DS/sync envelope(mirror_mappers)补 subtype;`DebtSubtypes` 扩 9 类;表单编辑模式 chips 解禁;新 4 类图标/色 switch(debt_form_page/debt_list_widgets/debt_detail_page)
- [ ] S4: 测试——mapper/DS/repo 单测、表单编辑 e2e、全量门(flutter test + analyze + client-e2e + go test)

## Keywords

`subtype` `债务分类` `信用贷款` `现金分期` `消费贷` `经营贷` `credit_loan` `cash_installment` `consumption_loan` `business_loan` `debt-subtype` `分类可编辑`
