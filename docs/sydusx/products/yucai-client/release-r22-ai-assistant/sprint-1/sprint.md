# Sprint 1 — P1 文本助手(助手地基+聊天闭环)

> /sydusx-portfolio 2026-10-23 立项(两票串行,F65 依赖 F64 地基)。调研依据=项目记忆 ondevice-llm-voice-research(2026-10-23 三路定案)。

## Sprint Goal

应用内 AI 助手文本对话最小闭环:自然语言问答七域财务数据,口径与页面逐分一致,BYOK 云端 LLM 先行(端侧推理/语音留 sprint-2/3)。

## Features

> 2026-10-23 重构:用户拍板助手纯内嵌端侧 → F66/F67 从 sprint-2 拉入并前置(依赖序 F66→F67→F65);sprint-2 撤销(断网验收并入本 sprint)。F65 的 design/prototype 可先行(不依赖引擎),execute 等 F66/F67。

- [ ] **F66 llama-server 边车管理** — 进程生命周期(拉起/随机端口/退出即杀/崩溃重启)+健康探测+**F64 provider 收窄返工**(AssistantConfig 退役云预设,config=enabled+model,ready=enabled&&模型就绪;localhost 零 Key 路径 F64 已建)。(从 sprint-2 拉入) ✅ done 2026-10-23 ff 合并 70bb5988(合并树 2995 绿+1 冒烟 skip-by-env[main 无引擎资产,设计行为];lib/assistant 覆盖 95.4%;评审 T1 PASS/T2T3 fixlist 七项全修+holistic PASS+test 门 13/13;真引擎冒烟 stories15M/b11669 三层测闭环[单测缝/接线帽石/真 exe];捆绑 CMake+release.yml fetch 双路径实测;收窄返工零迁移)
- [ ] **F67 端侧模型管理** — Qwen3-4B 首跑下载(进度/断点续传/hf-mirror 可选)+存储/版本/磁盘占用管理。(从 sprint-2 拉入) claimed: session_aeae29d380294919dea3162276116bd7 2026-10-23

- [x] **F64 助手地基** — 进程内工具注册表+agent loop 事件流+首批只读工具×3+LlmConfig 助手档+审计日志。 ✅ done 2026-10-23 ff 合并 5a09c68f(合并树 2967 绿/analyze 459/server diff 0B;118 测+集成帽石测,lib/assistant 行覆盖 96.7%,16/16 场景验收;SDD 6 任务+两修复轮,per-task+holistic 评审全 PASS;过程:openai_dart ^11 引入+port 隔离/BaseCurrencySource+NetWorthSnapshotSource 微 port 组合根适配/F50 cardLoanOccupationCents 零改动复用/debts mapper 实证无需补;再生成债=内联函数类型致 build_runner 手工兜底,候选票)
- [ ] **F65 聊天 UI 闭环** — 聊天界面(OD 原型先行,视觉伴侣决策模式)+全量只读工具(持仓含收益/交易查询时间范围过滤分页/预算/目标)+口径一致性断言全量(工具返回 vs repository 同源逐分)+流式渲染与工具调用过程可视化。(依赖 F64 地基) claimed: session_aeae29d380294919dea3162276116bd7 2026-10-23**用户拍板 2026-10-23:OD 原型须经用户确认后方可进 execute(执行门,不自动续跑)。**

## status: pending
