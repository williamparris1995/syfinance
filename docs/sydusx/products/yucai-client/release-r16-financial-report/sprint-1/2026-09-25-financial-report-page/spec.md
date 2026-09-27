# Spec — F43 报告汇编层+财务报告页(R16 sprint-1)

> analysis 2026-09-25。grill 六决策逐条挑战-辩护-用户确认(见 Grill record);release 级四拍板见 [release.md](../../../release.md) Decisions,为上游事实不重复辩护。
> 现状调查结论:本地 drift 库绑定后=全量镜像(bound_mirror.dart rebuild)、guest 恒本地;全量 Transactions+TransactionEntries 可回放任意时点余额(余额规则=balance_updater,与 server 同款);networth 历史快照全库缺失(回放为替代路径);goal 进度历史本地恒空(ADR-4)。

## 需求(FR)

### Requirement: FR-1 报告期与入口
系统 SHALL 支持按自然月或自然年选择报告期生成财务报告;入口为 /reports 页顶栏「财务报告」按钮,报告页为子路由(shell 外自带顶栏,对齐 /reports 先例)。
- [ ] FR-1
  #### Scenario:
  - GIVEN 用户进入财务报告页 WHEN 选择报告期 2026-08 THEN 报告题为「2026 年 8 月财务报告」且全部章节锚定 [2026-08-01, 2026-08-31 23:59:59]
  - GIVEN 选择报告期 2025 年 THEN 全部章节锚定 [2025-01-01, 2025-12-31 23:59:59]

### Requirement: FR-2 纯本地汇编、三态一致
报告汇编 SHALL 一律基于本地 drift 库(全量镜像),guest / bound-离线 / bound-在线三态产出同一报告;不新增 server RPC 调用。bound-在线时数据新鲜度以本地镜像为准(同步延迟由既有 sync 机制决定,报告不额外拉取,spec 显式接受)。
- [ ] FR-2
  #### Scenario:
  - GIVEN 同一账本种子 WHEN 分别以 guest 与 bound-离线(断网)生成同一报告期 THEN 报告各金额逐项相等

### Requirement: FR-3 章节结构与自适应
报告 SHALL 由六章节构成;无数据章节自适应隐藏,总览页附注逐项披露未包含项及原因:
1. **总览**:期初/期末净资产、本期结余、储蓄率(结余/收入)、现金及等价物净变动、口径附注+未包含项附注
2. **资产负债**:期初/期末时点数(FR-4)、资产/负债按 category 构成、期末−期初变动额
3. **收支**:收入/支出/结余、支出分类构成、日均、对比(月报=环比上月;年报=同比上年)
4. **现金流**:经营/投资/融资三类活动流(FR-5),净变动勾稽
5. **预算执行**:月报=当月各预算项 actuals vs 预算;年报=全年汇总;无预算→隐藏+附注
6. **投资绩效**:期初/期末市值、当期净买入、估算收益、区间 TWR(FR-6);无持仓→隐藏+附注
- [ ] FR-3
  #### Scenario:
  - GIVEN 无任何预算 WHEN 生成报告 THEN 预算执行章节不出现,且总览附注含「未包含:预算执行(本期无预算)」
  - GIVEN 有持仓 WHEN 生成年报 THEN 投资绩效章节呈现期初/期末市值与区间 TWR

### Requirement: FR-4 时点数回放重建
资产负债章节期初/期末时点数 SHALL 由本地全量分录回放重建:账户余额@T = initialBalanceCents + Σ(T 前该账户分录 delta)(delta 规则与 balance_updater 同款);持仓市值经 LocalPerformanceAssembler 时点回放(qty@T × price@T,成交价 ffill)。报告 SHALL 附注披露回放近似口径(已实现盈亏与 server 的 documented 分歧、历史汇率近似)。
- [ ] FR-4
  #### Scenario:
  - GIVEN 账户 X initialBalance=0,仅 2026-08-15 一笔 debit 1000 分录 WHEN 生成 2026-08 月报 THEN 该账户期初余额=0、期末余额=1000
  - GIVEN 报告生成 THEN 总览附注含回放口径说明(含与 dashboard 现值可能存在小差额的提示)

### Requirement: FR-5 现金流分类与勾稽(严格口径)
现金及等价物 SHALL 仅含 savings 类账户(定存无到期日字段,一律按 >3 个月保守处理,经附注披露);活动分类:涉及 income/expense 科目的现金收支=**经营**;与投资类非现金资产(investment/fixedDeposit/goldFx/storedValue/realEstate/otherAsset)往来=**投资**;与负债/权益科目往来(借入/还款/信用卡还款)=**融资**;非现金科目间往来不出现金流(如储值卡消费)。现金流净变动 SHALL 等于期末−期初现金余额(勾稽不变式,测试钉死)。
- [ ] FR-5
  #### Scenario:
  - GIVEN 储蓄→储值卡充值 500 WHEN 生成月报 THEN 投资活动流出 500、经营/融资为 0、现金净变动 −500
  - GIVEN 储蓄→expense 消费 300 WHEN 生成月报 THEN 经营活动流出 300
  - GIVEN 信用卡刷卡 300(credit 信用卡,不涉现金)+ 月末储蓄→信用卡还款 300 WHEN 生成月报 THEN 经营现金流出 0、融资流出 300
  - GIVEN 任意账本 WHEN 生成任意报告期 THEN 三类活动净额之和 == 期末现金余额 − 期初现金余额

### Requirement: FR-6 投资绩效区间
投资绩效 SHALL 基于 LocalPerformanceAssembler 的区间扩展(支持任意 rangeStart/rangeEnd),同时呈现金额口径(期初市值/期末市值/当期净买入/估算收益=期末−期初−净买入)与区间 TWR。
- [ ] FR-6
  #### Scenario:
  - GIVEN 期初市值 10000、期末市值 12000、当期净买入 5000 THEN 估算收益 = −3000
  - GIVEN 期内无买卖、市值不变 THEN 区间 TWR = 0

### Requirement: FR-7 ExpenseBasis 口径抽象
支出聚合 SHALL 经 ExpenseBasis 抽象接口暴露,默认实现=现金口径(现状 TransactionSummary 语义);待摊口径接入点以接口测试钉死(假 basis 替换验证章节结构不变),本票不实现待摊。
- [ ] FR-7
  #### Scenario:
  - GIVEN 假待摊 basis(测试替身)WHEN 替换默认 basis THEN 收支章节支出聚合改走新 basis 且章节结构与渲染不变

## 需求(NFR)

### Requirement: NFR-1 性能
典型账本(≥10,000 条分录)报告生成(含全量回放)SHALL ≤2s(wall clock,测试环境)。
- [ ] NFR-1

### Requirement: NFR-2 复用与设计一致性
章节图表 SHALL 复用 fl_chart 既有组件与 design-v2 语义令牌,不引入新图表库;页面 UI 经 sydusx-prototype 出原型(设计阶段)。
- [ ] NFR-2

### Requirement: NFR-3 零 proto/server 改动
本票 SHALL 不改动 yucai/proto/ 与 yucai/server/(git diff 门:两目录零变更)。
- [ ] NFR-3

## Scope boundary(排除项:owner+已权衡理由)

| 排除 | owner/拍板 | 理由(成本已权衡) |
|---|---|---|
| 目标回顾章节 | 用户 2026-09-25 | 本地进度历史恒空(ADR-4 server 快照产物),现值章节无增量;**backlog**:本地进度快照基建落地后年度报告加「目标回顾」章 |
| 待摊口径切换 | release 级 2026-09-25 | 归 R17 待摊引擎(其 spec 先决评审点③);本票仅 ExpenseBasis 接口+测试预留 |
| MD&A 诊断与建议 | release 级 | F44 同 sprint 另票(规则为主+预留 AI) |
| 报告导出(PDF/Markdown) | release 级 | F45 sprint-2,与页面同源报告模型 |
| AI 叙述生成 | release 级 | 接口预留归 F44,本期不接 |
| server 端报告聚合/新 RPC | 约束(NFR-3) | 零 proto/server 改动:规避 proto regen 工具链成本,且纯本地汇编保证三态一致 |

## Feasibility(裁决)

- **Technical: 可行** — 全量镜像+回放规则已存在,新工作=回放服务/现金流分类器/assembler 区间参数/报告页面;口径差以附注披露(用户已确认接受)。
- **Economic: 可行** — 全 client 复用零新依赖;无 proto regen(本 repo 最大成本项);体量≈F33 级(中等偏大)。
- **Operational: 可行** — 纯读路径,无迁移无写入;回滚=移除页面路由与汇编服务注册。

## Grill record(2026-09-25,一次一决策,挑战-辩护-确认)

1. **资产负债时点数=回放重建+附注披露** — 挑战:与 dashboard 现值可能对不上账,伤"规范报告"信任;辩护:分歧幅度小(已实现盈亏口径差+汇率近似),财报附注传统即为此设,替代方案(砍期初对比)使章节失去意义;用户确认。
2. **现金口径=严格(仅 savings,三类活动流)** — 挑战:储值卡/定存的用户直觉;经行业最佳实践查证(CAS 31/IAS 7 现金等价物 ≤3 个月+beancount cash-flow-role 四角色、预付卡不算现金)后**修正原推荐**(savings+storedValue→仅 savings);复式记账下消费按 expense 科目计量,现金流宽窄不影响收支准确性;用户确认。
3. **投资绩效=金额口径+区间 TWR 都做** — 挑战:assembler 区间扩展成本,金额口径已够;用户选"都做",不以成本为由降级;验收含 TWR 数值测试。
4. **空态章节=自适应隐藏+总览附注披露** — 挑战:财报章节固定才"规范";辩护:空章节对个人是纯噪音且可被读作批评,附注披露未包含项保完整性透明;用户确认。
5. **入口=/reports 顶栏+子路由** — 挑战:可发现性弱一跳 vs 侧栏 720p 拥挤前科(F41 fix-2);辩护:低频深读场景不该占常驻导航,子路由零 shell 改动;用户确认。
6. **目标章节=排除记 backlog** — 挑战:回顾场景目标最有情感分量;辩护:本地进度历史恒空(ADR-4),现值章节无增量,补快照基建撑破零改动约束;用户确认。
