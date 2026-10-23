---
feature: f65-chat-ui
status: confirmed
---

# F65 聊天 UI 闭环 — spec

> R22 sprint-1 次票(依赖 F64 地基,已合 main 5a09c68f)。**用户执行门(2026-10-23 拍板):OD 原型经用户确认后方可进 execute——design 阶段出对比页后停,等确认。**

## ADDED Requirements

### Requirement: FR-1 助手入口与聊天界面
- [ ] 应用 SHALL 提供助手入口(基线=侧栏新增「助手」导航项+`/assistant` 页面;最终形态经 OD 对比页用户终拍,悬浮面板等变体可替换基线)与聊天界面:消息流+输入框+发送;助手回复 SHALL 流式渲染(TextDelta 增量上屏);工具调用过程 SHALL 可视化(ToolCallStart/End 状态条,如「正在查询净资产…」);SHALL 提供「新对话」重置当前会话。

#### Scenario: 流式上屏与工具状态
- GIVEN 助手端点已配置
- WHEN 发送一个需查数的问题
- THEN 助手回复逐字上屏;期间工具调用显示状态条;完成后内容定格

#### Scenario: 未就绪引导态
- GIVEN 助手未启用或模型未就绪
- WHEN 进入助手页
- THEN 显示引导态(去启用/查看下载进度),不发起任何 LLM 调用

#### Scenario: 错误可重试
- GIVEN 一次往返中 LLM 调用失败
- THEN 会话内显示错误消息且提供重试,历史输入不丢

### Requirement: FR-2 全量只读工具×5
- [ ] 系统 SHALL 提供 F64 范式的五个只读工具:holdings_list(持仓面板口径:成本/市值/浮动盈亏+百分比)/transactions_search(时间范围+账户+分类+关键词+收支方向+分页)/budgets_status(预算执行度)/goals_list(目标进度)/performance_range({start?,end?} 缺省年初至今,包 F43 报告汇编器区间计算:期初/期末市值+净买入+估算收益+区间 TWR);全部返回 cents+元双口径聚合摘要。

#### Scenario: performance_range 报告口径
- GIVEN 任一时间区间
- WHEN performance_range 与财务报告页同区间输出比对
- THEN TWR/估算收益/期初期末市值逐分一致

#### Scenario: holdings 面板口径
- WHEN holdings_list 与持仓面板同库同源比对
- THEN 成本/市值/浮动盈亏逐分一致

#### Scenario: transactions 六项过滤+分页
- WHEN 按时间范围+账户+分类+关键词+收支方向组合查询
- THEN 结果为过滤后聚合摘要(总额+top-N+total_count+分页),超界页空而汇总不丢

### Requirement: FR-3 端侧模型管理卡
- [ ] 设置页 SHALL 提供独立「AI 助手」卡(与 F46「AI 解读」并列,语义彻底分离):启用开关+模型下载(首跑引导/进度/断点续传)+模型状态(版本/磁盘占用)+引擎状态(运行中);**用户面零端点/零 Key/零云选项**(纯内嵌独立运行,2026-10-23 用户拍板;引擎与下载能力由 F66/F67 供给,本票做 UI 面与接线)。

#### Scenario: 首次启用引导下载
- GIVEN 模型未下载
- WHEN 在助手卡点启用
- THEN 引导进入模型下载(进度可见,可断点续传),完成前助手页显示下载进度态

#### Scenario: 引擎状态可见
- GIVEN 边车进程已拉起
- THEN 助手卡显示「运行中」状态;异常退出显示可重试状态

### Requirement: FR-4 会话形态
- [ ] 会话 SHALL 为内存态单会话(F64 loop 既有语义):应用重启即清空(已知明确行为,非缺陷);「新对话」SHALL 清空当前会话上下文。

#### Scenario: 新对话重置
- GIVEN 会话含历史消息
- WHEN 点击「新对话」
- THEN 消息流清空且 loop 会话上下文重置(system prompt 重新注入)

### Requirement: FR-5 意图澄清原则
- [ ] 助手 SHALL 遵循:意图/范围/口径不明时先反问澄清(给具体选项)再执行;超出 v1 工具面的问题 SHALL 明说局限并给最接近的可答路径;SHALL 禁止编造数字(与 F64 system prompt 同源,本票将该原则一般化)。

#### Scenario: 歧义范围先澄清
- GIVEN 用户问句时间范围有歧义(如「今年的收益」未指明口径)
- WHEN 助手响应
- THEN 先输出澄清问句而非直接执行(system prompt 原则断言+集成回放钉)

#### Scenario: 超界明局限
- GIVEN 用户询问 v1 不支持的能力(如按标签筛选)
- THEN 助手说明局限并给出替代可答路径(如按分类/关键词),不编造结果

### Requirement: NFR-1 口径一致断言全量
- [ ] 八个工具(含 F64 三件)SHALL 全部纳入参数化口径断言(vs 同源页面/repository/汇编器逐分)。

### Requirement: NFR-2 UI 惯例
- [ ] 界面 SHALL 遵守 design-v2 令牌/零裸色/AppToast/R21 整改基线(行内校验/可逆直做等)。

### Requirement: NFR-3 原型对齐
- [ ] 实现 SHALL 照 prototype/CURRENT(用户确认版)——OD 对比页未经用户确认不得进 execute(执行门)。

### Requirement: NFR-4 server 零改动
- [ ] 本票变更后 git diff yucai/server MUST 为空。

## Feasibility(裁决)

- **technical 可行**:F64 地基(事件流/工具注册表/设置档)就绪;五工具中四件为 F64 范式复制,performance_range 包现成 F43 汇编器;UI 为原生薄层。
- **economic 可行**:零新依赖零迁移;BYOK 沿用。
- **operational 可行**:内存态会话零数据管理负担;未配置引导防呆。

## Out of scope

- 对话历史持久化(跨会话) — owner: 另票(质询挑战 2) — excluded because: F65 已满票(界面+五工具+设置卡);历史表需 drift 迁移+会话列表+清理管理,产品形态值得单独想;内存态清空=已知明确行为。
- 标签/金额区间过滤、XIRR — owner: backlog(工具面扩充) — excluded because: 质询挑战 3——小模型参数面约束;机制一行可加,需求出现即补。
- 技能包形态(system prompt 按意图加载扩展) — owner: R22 backlog v2 — excluded because: 质询中用户提议的演进方向,依赖 v1 工具面稳定后才有意义。
- 端侧推理/语音/写操作 — owner: sprint-2/3/4 — excluded because: release 三段路线既定。
- 悬浮面板等入口变体 — owner: design/OD 对比页 — excluded because: 形态是设计决策,OD 变体由用户终拍(可替换基线)。
- 云服务商选项/Ollama 检测/自定义端点 — owner: none(永久排除) — excluded because: 用户 2026-10-23 拍板「只使用内嵌的端侧 LLM…纯内嵌独立运行」;F46 报告 BYOK 云端线不受影响(独立 feature)。
- MCP/R18 — owner: yucai-server R18(观望) — excluded because: release 立项拍板(应用内=进程内注册表)。

## Grill record

- 入口形态与「现成 SDK」 — challenged: 用户问能否接 Sydusx IM SDK 直接供聊天功能 — defended: 搜索零命中(该名不存在;sydusx=流程技能族非代码);IM SDK 品类错配(多人消息基建 vs 单用户本地消息列表),接外部 IM 引入账号/网络依赖违反 client-only;用户定「设计原生薄 UI」;基线=侧栏页 /assistant,OD 对比页验变体终拍。
- 通用化 vs 工具表面积 — challenged: 用户问「不能形成 SDK/skill/MCP,按意图调 API 取数行事吗」 — defended: 该机制 F64 已建成(注册表=LLM 的 SDK,意图→工具→执行已测);过滤面收窄是表面积设计非机制限制(4B 参数面实证约束);裸 SQL/裸接口为财务禁忌(错数看似对;口径须焊死工具内);MCP=R18 外部宿主场;skill 形态记 backlog v2。
- 对话历史持久化 — challenged: 内存态 vs 落库 — defended: 用户按推荐 A——F65 内存态,历史另票;重启清空=已知明确行为。
- 交易过滤维度 — challenged: v1 收哪些维度 — defended: 用户同意六项(时间范围+账户+分类+关键词+收支方向+分页),标签/金额区间 backlog(机制一行可加)。
- 纯内嵌独立运行 — challenged: 设置卡归属之争(A 独立卡 vs B 并入 F46)+用户连收两次窄(「只使用内嵌的端侧 LLM,不提供其他云服务商」→「纯内嵌独立运行」) — defended: 云预设/Ollama 检测/自定义端点全部作废,助手=随包 llama-server+Qwen3-4B 唯一路径;设置卡之争自动消解=独立「AI 助手(端侧模型管理)」卡;F46 报告 BYOK 不动;sprint 重构 F66→F67→F65(sprint-2 并入);F64 provider 收窄归 F66 返工(localhost 零 Key 路径 F64 已建,loop/流客户端零改)。
- 主入口=右下角 FAB — challenged: spec 基线原为侧栏页 — defended: 用户直接定方向「右下角 FAB 按钮作为主入口」;ADR-3 修订,OD 对比页验证共存形态(与 R19 悬浮簇同屏关系)与唤出形态(浮层 vs 全页 vs 并存)。
- 持仓收益口径与「所有问题」 — challenged: 用户质疑「今年收益率答不了」的边界 — defended: 纠正——限制非查询/计算能力,F43 汇编器现成;修订定案=holdings_list 面板口径+**performance_range 第 5 工具入列**(包 F43 汇编,报告口径);用户再定「必须能答所有问题+不明先问」→ 升格 FR-5 意图澄清原则(澄清优先/超界明局限/禁编造),「所有」诚实操作化为三层(v1 可答/反问后可答/明说局限)。
