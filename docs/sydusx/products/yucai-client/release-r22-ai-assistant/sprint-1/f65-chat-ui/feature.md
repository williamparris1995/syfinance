---
title: F65 聊天 UI 闭环
keywords: 聊天界面, 助手入口, 全量只读工具, performance_range, 助手设置卡, 意图澄清
---

# F65 聊天 UI 闭环

> /sydusx-brainstorming 2026-10-23 进入;analysis 同日 spec 落档(质询五决策,见 [spec.md](spec.md))。R22 sprint-1 次票,依赖 F64 地基。**执行门:OD 原型经用户确认后方可进 execute。**

## 概述

应用内 AI 助手的用户界面闭环:聊天页面(流式渲染+工具调用可视化)+全量只读工具×5(含 performance_range 区间收益)+助手设置卡+意图澄清原则。原生薄 UI(design-v2 体系,不接任何 IM/chat SDK);会话内存态(历史持久化另票)。

## Stories

- [ ] S1: 全量只读工具×5 — holdings_list(面板口径)/transactions_search(六项过滤+分页)/budgets_status/goals_list/performance_range(包 F43 汇编器,报告口径);F64 范式复制+口径断言扩展至八工具全量。
- [ ] S2: 聊天页面 — 路由/assistant+侧栏项(OD 终拍形态)、消息流+输入+流式上屏、工具状态条、「新对话」重置、未配置引导态、错误重试。
- [ ] S3: 助手设置卡 — 端点配置(provider/baseUrl/model/key,localhost 空 Key 可用)、保存热切换、引导跳转。
- [ ] S4: 意图澄清与 prompt 收口 — system prompt 原则一般化(澄清优先/超界明局限/禁编造),常量断言+集成回放。
- [ ] S5: 测试门 — widget 测(页面/设置卡)+口径断言八工具参数化+prompt 原则断言+e2e(照 prototype 确认版);server 零 diff。

## 非目标(Non-goals)

对话历史持久化(另票);标签/金额区间过滤与 XIRR(backlog 工具面);技能包形态(v2 backlog);端侧推理(sprint-2);语音(sprint-3);写操作(sprint-4);MCP/R18(观望)。
