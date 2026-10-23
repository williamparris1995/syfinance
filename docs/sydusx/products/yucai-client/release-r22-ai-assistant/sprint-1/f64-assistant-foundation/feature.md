---
title: F64 助手地基
keywords: 助手地基, agent loop, 工具注册表, LLM 端点配置, 审计日志
---

# F64 助手地基

> /sydusx-portfolio 2026-10-23 分解;analysis 同日 spec 落档(质询七决策,见 [spec.md](spec.md))。R22 sprint-1 首票;调研依据=项目记忆 ondevice-llm-voice-research。

## 概述

client 进程内 AI 助手的**无 UI 地基**:工具注册表+agent loop(事件流)+首批只读工具+LLM 端点助手档+审计日志。上承 F46 LLM 端点抽象,下启 F65 聊天闭环与 sprint-2 端侧推理。**server 零改动;sprint-1..3 只读(写操作=sprint-4 确认门)。**

## Stories

- [ ] S1: 工具注册表 core — AssistantTool 抽象(name/description/JSON Schema/execute)+注册表+OpenAI tools 序列化;重名拒绝。
- [ ] S2: 首批只读工具×3 — networth_snapshot/accounts_list(载体户隐藏+卡贷占用口径+kind 过滤+分页)/debts_list(欠款=正数+下期月供到期+逾期标记+分页),直调本地 repository。
- [ ] S3: agent loop 事件流服务 — OpenAI 兼容 chat completions tools 往返+SSE 流式解析+tool_calls 拼装执行+结果回填+错误自纠上限(3)+查无实体澄清话术(system prompt 逐字常量)。
- [ ] S4: LlmConfig 助手档 — 独立端点配置(provider/baseUrl/model/key),key 仅 secure storage,custom 支持 localhost,key 可空;未配置明确报错。
- [ ] S5: 审计日志 — LLM 请求与工具调用 English 结构化日志(工具名/参数摘要/结果状态/耗时),无 CJK。
- [ ] S6: 测试门 — 口径逐分断言(参数化全工具)+mock LLM 流式回放集成往返+注入定界断言+server 零 diff 验证。

## 非目标(Non-goals)

聊天 UI/OD 原型(F65);持仓/交易/预算/目标工具(F65 全量批);端侧推理/边车/模型管理/Ollama 自动检测(sprint-2);语音(sprint-3);写操作与确认门(sprint-4);对话历史持久化(F65 决策);MCP/R18(观望);durable 审计表(sprint-4);报告 MD&A 叙事(backlog)。
