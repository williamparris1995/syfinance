---
title: F51 dual-representation-governance
keywords: [双重表示, 只读降级, loan 字段组, invest 字段组, 挂债, 持仓挂接, 派生估值, dual-representation, dual-representation-governance]
---

# Feature — F51 loan·invest 双重表示规则化(R17 sprint-1)

> 2026-10-10 立项。release 定案见 [release.md](../../../release-r17-account-extensibility/release.md) done-criterion 3;审计依据 = 项目记忆 account-fields-audit。

## Description

现状:loan/invest 账户列与债/持仓数据构成**结构性双表示**(真库未灌水,门敞着):表单两组字段可自由编辑平行数字,且账户页估值 `numValue` 直接读用户维护列——平行维护即漂移(R14「页面间对不上」病根)。目标(详见 [spec.md](spec.md)):①挂接后字段组**只读 + 债/持仓侧派生显示**(loan:总额/剩余/月供/下期日;invest:成本/市值,ytd 显「—」)+ 来源提示;②**读侧统一**:估值/聚合/净资产 client 侧全部改走派生,账户列退为未挂接回退——详情/表单/汇总逐分一致;③未挂接行为逐分不变(回归钉死);④不迁移不删列、派生不回写、零 proto/server。server NetWorthService 同义派生列 backlog。

## Stories

- [ ] S1: domain 派生纯函数(loan 组四值/invest 组两值)+ fixtures 单测(多债聚合/无期表回退/空持仓)
- [ ] S2: 表单降级态 — loan/invest 字段组挂接时只读+派生值+提示,提交不写组列
- [ ] S3: 读侧统一 — `numValue`/详情挂接走派生,列退回退;未挂接回归断言
- [ ] S4: 收口 — 全门(全量绿/analyze/e2e)+ 跨页一致性测试(表单=详情=汇总逐分)
