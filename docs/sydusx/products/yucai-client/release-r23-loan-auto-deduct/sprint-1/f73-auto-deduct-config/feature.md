---
title: F73 自动扣款配置与交易↔期次联动
keywords: 自动扣款, autoDeduct, 绑定还款账户, 期次联动, 交易回滚, 贷款配置
---

# F73 自动扣款配置与交易↔期次联动

> /sydusx-brainstorming 2026-11-02 进入(R23 sprint-1 首票);brainstorm 定案见 [release.md](../../release.md) Decisions。

## 概述

Debt 级 autoDeduct 配置{enabled, 绑定还款账户}(仅独立贷款型可开,信用卡挂接分期禁开——跟卡账单统一还款走);自动落账生成的还款交易与期次的关联建模:交易删除→期次回未付、修改按语义联动,期表与账户余额不漂;实扣口径=本金+利息−优惠。存储面倾向 client-only(drift 本地),analysis 查证 bound-online 落账路径后定案。

## Stories

- [ ] S1: domain 配置实体+存储面落定(drift 迁移/client-only 定案;绑定账户引用完整性)。
- [ ] S2: 债务表单/详情 UI(开关+绑定账户选择;卡贷挂接形态禁开+原因文案)。
- [ ] S3: 还款交易↔期次关联建模+联动回滚(删除回未付;不变式:期表与账户余额不漂)。
- [ ] S4: 全门+覆盖表。

## 非目标(Non-goals)

调度器/预检提醒/重试(F74);罚息/宽限期建模;银行实际结果自动对账;平安等存量债务回溯开启(backlog)。
