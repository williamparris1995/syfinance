# Release R22 — 应用内 AI 助手(in-app-ai-assistant)

> /sydusx-portfolio 2026-10-23 立项落档(用户三拍板:草案落档 / P2 形态=捆绑+检测双路 / 随即 sprint-1 立项)。product checkpoint:重读 [vision.md](../vision.md),Product Goal(可分发的商业级个人专业理财应用的客户端)ongoing——R22 在「操作效率/商业级差异化」面上延伸:自然语言问答+语音交互为操作效率下一档。vision Positioning「本地优先架构下经 gRPC 直连 server(无本地 DB)」措辞自 R6 起已过时(本地 Drift 为 UI 事实源),措辞订正随 R22 收官由 sydusx-envision 顺带。
> 起因:用户 2026-10-23 brainstorm「调研端侧 LLM 支持直接语音对话,御财接口封装给上层 LLM 调用」——三路后台调研定案(推理运行时/语音管线/MCP 与工具设计标准;档案=项目记忆 ondevice-llm-voice-research,来源 URL 全列)。核心结论:①**应用内嵌助手=进程内 function registry**(OpenAI tools JSON schema 直传 chat API),行业共识不上 MCP(dart_mcp experimental 且仅 stdio;MCP 留外部宿主场景=R18);②client local-first 天然适配——工具层直调本地 repository,guest/离线可用,数据不出机器;③推理=llama.cpp(MIT)边车 llama-server + Qwen3-4B-Instruct-2507(Apache 2.0,Q4 ~2.5GB,8GB RAM 起,同规模工具调用最强);④语音=sherpa-onnx 官方 Flutter 插件(v1.13.8,Apache 2.0,Windows 桌面支持)中文栈(流式 Paraformer 226MB+Silero VAD+Kokoro v1.1-zh ~90MB,首跑下载 ~550-600MB),桌面首发 push-to-talk(无 AEC 回声自激);Whisper 中文 CER 落后不选。

## Release Goal

御财 client 具备应用内 AI 助手:自然语言(文本→语音)问答财务数据、引导并执行记账操作(sprint-4 带确认门),进程内工具面(sprint-1..3 只读)与页面口径逐分一致;LLM 双路(BYOK 云端复用 F46 端点抽象 / 端侧 llama-server 边车),端侧路径断网可用、数据不出机器;**server 零改动**。

## Decisions(用户拍板 2026-10-23)

- **client-only**:助手数据面全在本地(repository/Drift 与 UI 同源),server 零改动(done 门=git diff yucai/server 空);多设备场景助手读本机镜像,新鲜度与本机页面一致(结构性保证,非缺陷)。
- **R18 观望**:yucai-server R18 agent-ready MCP 门面(2026-10-09 立项 pending)不随本 release 并行,降为可选观望——外部宿主(Claude/ZCode/Cursor)接入是独立价值,需求出现再动工;工具 schema 契约届时可共享本线设计。
- **接口层=进程内工具注册表**:OpenAI tools JSON schema 直传 OpenAI 兼容 chat completions(端点抽象复用 F46 LlmConfig);不上 MCP、不引 dart_mcp。
- **sprint-1..3 只读**:问答/查询工具面;写操作升正式 **sprint-4**(2026-10-23 F64 spec 质询定案,原 backlog v2 评估作废)——带确认门三件套(记一笔/改一笔/删一笔+新建引导),须确定性确认门(代码层不可绕过,非提示词)+幂等键+durable 审计表(actor=agent 区分),对齐 R18 同款拍板。
- **三段路线(2026-10-23 订正)**:~~P1 文本(BYOK 云端先行)~~ → **作废**:用户拍板助手**纯内嵌端侧独立运行**(F65 质询定案)——不提供任何云服务商选项、无 Ollama 检测、无自定义端点;F46 报告 BYOK 云端线不受影响。sprint-1 重构为 F66(边车,含 F64 provider 收窄返工)→F67(模型管理)→F65(聊天 UI+端侧模型管理卡),sprint-2 撤销并入(断网验收并 sprint-1)。
- **~~P2 形态=捆绑+检测双路~~ → 纯内嵌独立运行(2026-10-23 用户收窄)**:随包 llama-server.exe(随机 localhost 端口边车,退出即杀,~几十 MB)+ 模型 Qwen3-4B(Q4 ~2.5GB)首跑下载(hf-mirror 镜像可选);**检测已装 Ollama 作废**(纯内嵌唯一路径);LM Studio 同废。端口号/internal 端点为引擎内部实现,用户面零端点概念。
- **语音首发 push-to-talk**:桌面扬声器回灌 mic 无 AEC 会自激 VAD;全双工免提/唤醒词(sherpa-onnx KWS,中文可用)backlog。
- **口径不变式沿既有**:债务欠款=正数/卡贷与载体户口径/净资产逐位——工具返回与页面同源同口径,一致性测试钉死。

## Sprint roster

- [x] sprint-1 — P1 文本助手:F64 助手地基(进程内工具注册表+agent loop+首批只读工具[净资产/账户/债务]+LlmConfig 助手档+审计日志)→ F65 聊天 UI 闭环(OD 原型+全量只读工具[持仓/交易查询/预算/目标]+口径一致性断言)(2026-10-23 立项,两票串行,F65 依赖 F64 地基)
- [x] ~~sprint-2 — P2 端侧推理~~ → **撤销并入 sprint-1**(2026-10-23 纯内嵌定案;F66/F67 前置于 F65;断网验收随 sprint-1)
- [ ] sprint-3 — P3 语音:F68 语音管线(sherpa-onnx 流式 ASR/Silero VAD/Kokoro TTS+语音模型管理+mic 采集 spike 收口)+ F69 对话体验(push-to-talk+按句流式播报+barge-in 打断);验收=说→答端到端体感流畅(2026-10-24 立项;原触发词 sprint-2 已撤销订正)
- [ ] sprint-4 — P4 写操作:F70 确认门写工具(记一笔/改一笔/删一笔+新建引导[意图澄清线落地];确定性确认门 UI+幂等键+参数预览)+ F71 durable 审计表(actor=agent 区分+可追责查询);验收=语音/文本说一句→确认→落库,全程可审计(sprint-3 收官后立项;2026-10-23 F64 spec 质询从 backlog 升格)
- backlog — 唤醒词免提(KWS);报告/MD&A 叙事接 R16 F46 通道;多设备新鲜度提示。

## Done criteria

1. 只读工具面覆盖七域:净资产快照/账户(含卡贷与载体户口径)/债务(欠款=正数不变式)/持仓(含收益指标)/交易查询(时间范围+过滤+分页)/预算/目标;返回**聚合摘要**(总额+top-N+total_count,≤~2k token 级),不倒原始表;与页面口径逐分一致(一致性测试钉死)。
2. 助手 LLM=**纯内嵌端侧单路**:随包 llama-server 边车+Qwen3-4B,断网独立运行,数据不出机器;用户面零端点/零 Key/零云选项(模型管理卡=启用/下载/状态)。
3. 语音链路端到端:push-to-talk→流式 ASR(实时字幕)→agent loop→按句流式 TTS 播报+barge-in 清队列打断;模型首跑下载有进度/失败重试。
4. 安全底线:sprint-1..3 只读;sprint-4 写操作须确定性确认门(代码层不可绕过)+幂等键+durable 审计表;外来字符串(银行备注/对方名)按数据定界防注入(F46 负面清单模式复用);工具调用审计日志(English 结构化);密钥仅 secure storage;**端侧为默认零配置,不得有「先配 Key 才能用助手」门槛**。
5. 全门:flutter test 全绿+analyze 基线不升+e2e 15 套件+新增 agent loop 集成测试(工具往返);**server 零改动(git diff yucai/server 为空)**。

## status: pending
