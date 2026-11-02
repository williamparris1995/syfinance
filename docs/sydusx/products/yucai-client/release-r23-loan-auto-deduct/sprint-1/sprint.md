# Sprint 1 — 机制线:配置联动+调度预检

> /sydusx-portfolio 2026-11-02 立项(R23 开 release 同日;单 sprint 两票用户拍板)。

## Sprint Goal

自动扣款型独立贷款零日常操作:配置开箱(F73)→ 到期自动落账+余额预检差额提醒+失败重试(F74)全链闭环;工行实例真库实测。

## Features

- [ ] **F73 自动扣款配置与交易↔期次联动** — Debt 级 autoDeduct{enabled,绑定还款账户} 配置(client 本地存,存储面 analysis 定案);仅独立贷款型可开(信用卡挂接禁开);自动落账生成的还款交易与期次的关联建模,交易删除/修改联动期次回滚;实扣口径=本金+利息−优惠。 `claimed: zcode 2026-11-02`
- [ ] **F74 自动落账调度与余额预检** — LoanAutoDeductScheduler 镜像 AutoRecordScheduler(catch-up/防御上限/完成通知):到期日余额够→事务性落账,不足→绝不落账+失败提醒含差额+每日重试;预检提醒源(提前窗口查绑定账户余额,差额文案新档位,「将自动扣款」轻提示);「现在重试」手动入口;overdue 6h 桶封顶不破。(依赖 F73)

## status: pending
