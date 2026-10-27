---
title: F70 确认门写工具
keywords: 写工具, 记一笔, 改一笔, 删一笔, 确认门, 幂等键, 参数预览, 新建引导
---

# F70 确认门写工具

> /sydusx-brainstorming 2026-10-27 进入;analysis 同日 spec 落档(质询两决策)。R22 sprint-4 首票;用户核心愿景「说一句就记账」的落地票;确认卡 UI 走 OD 原型+用户确认门。

## 概述

三写工具(transaction_add/update/delete)+确定性确认门(参数预览卡/前后对比/destructive 强提示/新对话作废/同刻单卡)+幂等键+查无实体表单引导;写路径与表单同管道同源;全部确认零例外;审计接口按 F71 预留先日志。

## Stories

- [ ] S1: 写域契约+工具 — WriteApproval 数据模型(待确认操作)/transaction_add/update/delete 三工具(定位/参数面/名称匹配消歧)。
- [ ] S2: 确认门机制 — bloc 扩展(WriteApprovalMsg 型态+确认/取消事件+作废语义+同刻单卡替换)+幂等键守卫+代码门(未确认零执行断言)。
- [ ] S3: 确认卡 UI — 预览卡/前后对比/destructive 样式(照 OD 原型用户拍板版)+deep link 引导跳转。
- [ ] S4: 测试门 — 写管道同源断言(与表单逐分)/幂等/作废/绕过攻击负测/e2e(记→改→删全流程真壳)+覆盖表。

## 非目标(Non-goals)

转账(backlog)/助手直建账户分类(backlog)/免确认分级(已否)/批量操作(backlog)/非交易写(backlog)/审计表(F71)/语音输入(F68/F69)。
