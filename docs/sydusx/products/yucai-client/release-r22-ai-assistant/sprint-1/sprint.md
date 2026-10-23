# Sprint 1 — P1 文本助手(助手地基+聊天闭环)

> /sydusx-portfolio 2026-10-23 立项(两票串行,F65 依赖 F64 地基)。调研依据=项目记忆 ondevice-llm-voice-research(2026-10-23 三路定案)。

## Sprint Goal

应用内 AI 助手文本对话最小闭环:自然语言问答七域财务数据,口径与页面逐分一致,BYOK 云端 LLM 先行(端侧推理/语音留 sprint-2/3)。

## Features

- [ ] **F64 助手地基** — 进程内工具注册表(OpenAI tools JSON schema 定义/分发/结果序列化)+agent loop 服务(OpenAI 兼容 chat completions tools 往返/流式/错误自纠)+首批只读工具(净资产快照/账户列表含卡贷载体户口径/债务列表欠款=正数)+LlmConfig 助手档(端点配置独立于报告 BYOK)+工具调用审计日志(English 结构化)。 claimed: session_aeae29d380294919dea3162276116bd7 2026-10-23
- [ ] **F65 聊天 UI 闭环** — 聊天界面(OD 原型先行,视觉伴侣决策模式)+全量只读工具(持仓含收益/交易查询时间范围过滤分页/预算/目标)+口径一致性断言全量(工具返回 vs repository 同源逐分)+流式渲染与工具调用过程可视化。(依赖 F64 地基)

## status: pending
