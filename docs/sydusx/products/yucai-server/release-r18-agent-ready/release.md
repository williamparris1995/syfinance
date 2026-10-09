# Release R18 — Agent-Ready MCP 门面(agent-ready-mcp)

> /sydusx-portfolio 2026-10-09 立项落档(**动工等 R17 收官**)。product checkpoint:重读 [vision.md](../vision.md),Product Goal(可分发的商业级个人专业理财应用后端)ongoing——R18 在「对外契约」面上扩展:gRPC(对 client)之外加第二张脸 MCP(对任意 agent 宿主),直接服务「可分发」终态;vision「对外契约:经 proto/gRPC 对 client 暴露 API」措辞扩展随 R18 收官由 sydusx-envision 顺带。
> 起因:用户 2026-10-09 brainstorm,解构 [storytold/photocraft](https://github.com/storytold/photocraft) 的 agent-ready 实现(四支柱:命令注册表单一事实源 / UI·CLI·JSON 控制通道·MCP 四驱动面 / loopback+能力作用域安全模型 / AGENTS.md 开发面)。yucai 对照:开发面 agent-ready 已达标(AGENTS.md + sydusx artifacts-as-state);运行面缺 MCP 入口;server 13 服务 106 RPC(gRPC,契约 yucai-api)即现成命令面。落位结论:yucai 是数据产品,价值在数据读写面而非 UI 驱动面——取「同一命令面多张脸」思想落 server 侧,不照抄 client 控制通道;photocraft 的安全设计(token 文件/fail-closed/传输限额)随 F53 设计吸收。

## Release Goal

yucai-server 具备 agent-ready 对外服务能力:任意 MCP 宿主(Claude/ZCode/Cursor/第三方产品)经标准 MCP 接口**只读**查询御财财务数据(净资产/账户/债务/持仓/交易/预算/目标);MCP 门面为 server 第二个对外 presenter(gRPC 之外),照 gRPC presenter 范式接 application 层,领域核心零改动为原则。

## Decisions(用户拍板 2026-10-09)

- **编号 = R18**:agent-ready 包用 R18;R17 立项时「待摊引擎 R18 候选」仅为备忘,顺延为 **R19 候选**。
- **调用方定位 = 标准开放+单租户**:MCP 工具面按 MCP 标准设计,任意宿主可连;v1 单租户鉴权(每用户 token,自托管部署);多租户(token 发放/管理面/契约 SLA)留升级路径不预建。
- **读写边界 = v1 只读**:查询类工具面(零误写风险);写操作(记一笔/改预算)v2 评估(需确认回路+写审计设计)。
- **承载 = yucai-server release**:新 presenter 照 gRPC presenter 范式;工具面契约进 `portfolio/contracts/yucai-mcp/`(与 yucai-api 并列),随 design 阶段落档。
- **优先级 = 排 R17 之后**:R17 sprint-1 治欠账三票在途(F49 已 claim);R18 现在只落档,动工等 R17 收官。
- **v1 工具面 = server 数据面**:networth/account/debt/holding/transaction/budget/goal(server 既有服务投影);**report 汇编与 MD&A 诊断为 client 侧计算(F43/F44 落在 yucai-client),server 门面 v1 不含**——列 backlog(server 端移植或 client 通道,届时另立项评估)。

## Sprint roster

- [ ] sprint-1 — 端到端最小环:F53 MCP 门面骨架(SDK 选型/传输/token 鉴权/工具注册/English 结构化日志)+ F54 首批只读工具(净资产/账户/债务);验收 = 一个真实 MCP 宿主连上并查到净资产(R17 收官后立项)
- [ ] sprint-2 — 全量+契约+部署:F55 其余只读工具(持仓含收益指标/交易查询/预算/目标)+ F56 contracts/yucai-mcp 契约+自托管部署物+README 接入指南(sprint-1 收官后立项)

## Done criteria

1. MCP 门面为独立入口(cmd/ 新入口或既有进程开关,design 拍板),照 gRPC presenter 范式接 application 层;领域核心零改动为原则,需要的读侧扩展照 port 范式在对应 design 显式声明。
2. v1 只读工具面覆盖:净资产快照/账户(含卡贷与载体户口径)/债务(欠款=正数口径不变式)/持仓(含收益指标)/交易查询(时间范围+过滤)/预算/目标;工具描述与返回结构对 LLM 友好(语义命名+稳定 schema+错误信息可自解释)。
3. 鉴权 fail-closed:每用户 token,单租户自托管部署形态;未授权/超限请求拒绝;结构化日志(English,无 CJK)覆盖连接/工具调用/错误。
4. 契约落档:`portfolio/contracts/yucai-mcp/`(工具清单+参数+返回 schema+版本化 CURRENT);README 三步接入指南(任意 MCP 宿主连上)。
5. 全门:`go test ./...` + `go build ./...` 全绿;新增集成测试覆盖真实 MCP 握手+工具调用往返;**零 proto 改动**(yucai-api 不动)。

## status: pending
