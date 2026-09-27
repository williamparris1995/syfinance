# Spec — F44 规则诊断引擎 MD&A(R16 sprint-1)

> analysis 2026-09-27。grill 三决策用户逐条确认(见 Grill record);上游:release 级「规则为主+预留 AI」拍板+F43 ReportDocument 契约。技术调查实证:闲置订阅只能近似口径(本地交易行无模板关联、record_log 不镜像);大额单笔可由 entries() 按 transaction 分组算出(缺 description→port 补投影)。

## 需求(FR)

### Requirement: FR-1 规则引擎与 Finding 模型
系统 SHALL 提供规则引擎:`MdaRule` 接口(输入=ReportDocument+MdaSupplement,输出=List<MdaFinding>)+执行器(全规则遍历、按严重度排序);`MdaFinding{ruleId, severity(risk/warn/info), conclusion(中文结论文案,含溯源数字), advice(可执行建议), actionLink?(如跳订阅中心)}` immutable。MdaSupplement 由汇编层顺带产出:{templates(含 expectedDates 预推演), transactions(transactionId/date/description/单笔支出额), trailing3mExpenseCents, cashStartCents, cashEndCents}(经 ReportLedgerStore port 扩展,ADR-2 同模式)。
- [ ] FR-1
  #### Scenario:
  - GIVEN 任意账本 WHEN 引擎执行 THEN 输出按 severity(risk>warn>info)稳定排序,每条含规则名/结论/建议

### Requirement: FR-2 规则集 R1-R6+H1-H2(阈值常量单点)
系统 SHALL 实现下表规则,阈值全部具名常量(单点定义+注释溯源行业依据,用户可配置=backlog):
| # | 规则 | 触发线 | 级别 |
|---|---|---|---|
| R1 | 储蓄率分层 | 结余为负→risk;<10%→risk;10-20%→warn;≥20% 通过 | risk/warn |
| R2 | 预算超支 | 任一预算项超支→warn;超支 ≥20%→risk | warn/risk |
| R3 | 资产负债率 | ≥70%→risk;50-70%→warn(房贷语境附注);<50% 通过 | risk/warn |
| R4 | 闲置订阅 | 见 FR-3 | info/warn |
| R5 | 大额单笔 | 单笔支出 ≥ 当期日均支出×3 且 ≥ 当期总支出 20%(双门槛) | info |
| R6 | runway 备用金 | 现金及等价物期末 ÷ 近 3 月均支出 <3 个月→warn;<1 个月→risk;近 3 月均支出为 0→不触发 | warn/risk |
| H1 | 支出集中度 | 最大类别支出占比 ≥40%→warn(中性表述,不用「恩格尔」标签) | warn |
| H2 | 环比突增 | 某类别环比 +50% 且增加额 ≥ 当期总支出 5%(双门槛防小基数) | warn |
- [ ] FR-2
  #### Scenario:
  - GIVEN 收入 32,500/支出 31,000(储蓄率 4.6%) WHEN 月报诊断 THEN R1=risk,结论含「储蓄率 4.6%,低于 10%」
  - GIVEN 期末现金 45,200/近 3 月均支出 17,000 WHEN 诊断 THEN R6=warn「现金可支撑约 2.7 个月」(45200/17000=2.66)
  - GIVEN 餐饮 2,850/3,000 预算且购物 4,120/3,500(118%) WHEN 诊断 THEN R2:餐饮 warn?否——未超支不触发;购物 warn(超支但 <20%)
  - GIVEN 期初市值 10,000→期末 12,000/净买入 5,000 支出侧无关 WHEN 诊断 THEN 投资数据不触发任何支出类规则

### Requirement: FR-3 闲置订阅近似口径与防御
R4 SHALL 用近似口径:direction==Expense 且 paused==false 的模板,报告期内存在应扣日但 lastTransactionId 未推进到期内→触发;**四道防御**:①疑问式文案「可能闲置:若仍在使用,记一笔时请关联该订阅」(禁断言);②grace 宽限(nextDate 落在期末后 7 天内不报);③级别 ≤warn;④actionLink 跳订阅中心。多条闲置合计月度等价金额入结论。
- [ ] FR-3
  #### Scenario:
  - GIVEN 未暂停年付模板(期内有应扣日,lastTransactionId=null) WHEN 月报 THEN R4=warn,文案为疑问式且含月度等价合计,附跳订阅中心链接
  - GIVEN 模板 nextDate=期末后 3 天 WHEN 诊断 THEN 不触发(grace)

### Requirement: FR-4 「诊断与建议」章节+总览摘要卡
报告 SHALL 新增第七章节「诊断与建议」(投资绩效之后):按严重度分组渲染全部 Finding(图标+结论+溯源数字+建议+可选跳转);零发现→健康态「本期诊断未发现需关注项」。总览页 SHALL 加自适应摘要卡:有 risk/warn→top-3(按严重度);零发现→单行健康徽章「本期诊断:0 风险 N 提示」。
- [ ] FR-4
  #### Scenario:
  - GIVEN 2 risk+1 warn+3 info WHEN 报告 THEN 第七章节分组渲染 6 条,总览摘要卡列 top-3(2 risk+1 warn)
  - GIVEN 零发现 WHEN 报告 THEN 章节显示健康态,总览为一行徽章

### Requirement: FR-5 AI 预留接口
系统 SHALL 提供 narrative port(输入 ReportDocument+Findings,输出叙述文本)+注入缝+fake 替换测试;**不接真实现**(F46:BYOK LLM 分析师,sprint-2 候选,与 F45 同批)。
- [ ] FR-5
  #### Scenario:
  - GIVEN fake narrative 实现 WHEN 注入 THEN 叙述章节走 fake 输出且章节结构不变

### Requirement: NFR-1 性能
规则全跑(8 规则+补充输入)SHALL ≤500ms(典型账本,测试环境)。
- [ ] NFR-1
### Requirement: NFR-2 零 proto/server 改动
本票 SHALL 不改动 yucai/proto/ 与 yucai/server/(git diff 门)。
- [ ] NFR-2
### Requirement: NFR-3 复用与一致性
章节 UI 走 design-v2 令牌零裸色;严重度色用既有语义令牌(risk=既有警示红/warn=既有黄/info=中性),不新造色;UI 原型经 sydusx-prototype(v7 扩展或 v8)。
- [ ] NFR-3

## Scope boundary(排除项:owner+已权衡理由)

| 排除 | owner/拍板 | 理由(成本已权衡) |
|---|---|---|
| LLM 分析师真实现(BYOK/脱敏包/prompt/免责) | 用户 2026-09-27 | 立新票 **F46**(sprint-2 候选,与 F45 同批);一票内同时做规则引擎+prompt 工程+设置 UI 验证面过大;规则层无论 LLM 来不来都必须有 |
| 城市物价/平均工资外部数据源 | 用户 2026-09-27 | 不接统计 API(新依赖+维护);F46 用 LLM 世界知识+城市规模档位 |
| 闲置订阅严格逐期核对 | 技术事实 | 本地无扣费日志镜像;近似口径+四道防御(FR-3) |
| 阈值用户可配置 | YAGNI | 常量单点+注释溯源;backlog |
| 标普 1234 资产配置对标 | 用户 2026-09-27(默认不加) | 偏理财师立场,v1 不做 |

## Feasibility(裁决)

- **Technical: 可行** — 规则输入三处 port 小扩(templates/transactions description/trailing 汇总)均 ADR-2 同模式;阈值纯计算;章节渲染复用报告页框架。
- **Economic: 可行** — 纯 client 零新依赖零 proto;体量≈T4+T5 之间(中等)。
- **Operational: 可行** — 纯读路径;回滚=移除章节与规则注册。

## Grill record(2026-09-27,一次一决策,挑战-辩护-确认)

1. **规则集 R1-R6+H1-H2+阈值表+LLM 分层** — 挑战:阈值是行业启发非真理(房贷期储蓄率 20% 过苛;R5 会把年付大额当异常——报告制造它要诊断的问题);辩护:分层+语境附注、R5 定 info 双门槛、常量单点 R17 重校;用户确认(并主动提出 LLM 分析师构想→评估后定 F46 分层,R6 runway 由该讨论吸收)。
2. **闲置订阅近似口径+四道防御** — 挑战:手动记账不点「关联订阅」→月月误报伤信任;辩护:疑问式文案/grace/info 级/跳转引导,规则反向引导数据变准;用户确认(否决了砍掉 R4 的备选)。
3. **第七章节+总览自适应摘要卡** — 挑战:总览过载(hero+五卡+两附注后再加卡);防御:自适应(零发现=单行徽章);用户「按推荐」确认。
