# Design: F44 规则诊断引擎 MD&A

prototype: v8(OD 增量迭代 run 待跑;基于 v7 页加诊断章节+摘要卡,用户确认后 CURRENT→v8)

## Context

- 上游:[spec.md](spec.md)(FR-1..5/NFR-1..3,grill 三决策);F43 已落 ReportDocument 快照+报告页+ReportLedgerStore port(ADR-2 模式)。
- 技术事实(调查):本地交易行无模板关联→闲置订阅近似口径;recurrence 推演(`firstOnSeriesAfter`,server 同口径)现居 template 模块,位置待查——**若在 template/data 则不可跨模块 import**(见 Risks)。
- 约束:零 proto/server;design-v2 令牌零新色;诊断随报告快照(用户拍板)。

## Goals / Non-Goals

**Goals**:规则引擎+8 规则(R1-R6/H1-H2)+闲置防御+第七章节+摘要卡+narrative 预留。
**Non-Goals**:LLM 真实现(F46)、城市外部数据(F46)、严格订阅核对、阈值可配置(backlog)。

## Decisions(ADRs)

- **ADR-1 诊断随快照**:`ReportDocument` 增可选 `mda: MdaSection?`(findings+健康摘要);规则引擎在汇编 `assembling` 阶段执行(进度仍四阶段,规则并入第三章段);F45 导出/F46 LLM 免费复用 Findings。挑战:独立刷新更灵活;防御:报告=回望自洽文档(财报 MD&A 同构),重生成 ≤2s。**用户拍板 2026-09-27**。
- **ADR-2 规则引擎=纯 domain 无状态**:`List<MdaRule>` 不可变规则表+遍历执行器(@LazySingleton);阈值=`MdaThresholds` const 单点(具名常量+行业依据注释);备选否决:bloc 内联(不可测)/配置驱动 DSL(YAGNI 过度设计)。
- **ADR-3 Supplement 构建在汇编服务**:trailing3mExpense/cashStart/cashEnd **复用既有 entries+replay 零新读取**;port 仅扩两点——`templateRows()`(expectedDates 由 adapter 预推演,推演逻辑留在 data 侧,domain 收纯日期表)+`transactions()`(TransactionRow{transactionId,date,description,expenseCents};单笔支出额=该交易 expense 科目 debit 合计)。
- **ADR-4 严重度→既有语义色**:risk→既有 neg 红/warn→既有 warn 黄/info→中性;零新令牌(NFR-3)。
- **ADR-5 narrative port**:`Future<String> narrate(ReportDocument, List<MdaFinding>)`;注入缝+fake 替换测试;F46 真实现(BYOK)。本期报告页**不渲染** narrative(章节只画 Findings;叙述章节归 F46——避免空占位)。
- **ADR-6 渲染复用报告页框架**:第七章节挂 `_chapters` 自适应链(mda null→隐藏?否——**mda 恒非空**(健康态也是 finding 集为空的章节),只有 ReportDocument 期外异常才 null);总览摘要卡自适应两态(有发现 top-3/零发现单行徽章)。

## HLD

```
lib/report/domain/mda/
  mda_models.dart      # MdaSeverity/MdaFinding/MdaSection/MdaThresholds(const)/MdaSupplement
  mda_rule.dart        # abstract MdaRule{String id; List<MdaFinding> evaluate(ReportDocument, MdaSupplement)}
  mda_engine.dart      # @LazySingleton 遍历+severity 稳定排序
  rules/               # r1_savings_rate/r2_budget_overrun/r3_debt_ratio/r4_idle_subscription/
                       # r5_large_single/r6_runway/h1_concentration/h2_spike(8 文件)
  mda_narrator.dart    # abstract port + NoopMdaNarrator
lib/report/domain/report_document.dart        # +MdaSection?
lib/report/domain/report_assembly_service.dart # +supplement 构建+引擎调用(assembling 阶段)
lib/report/domain/report_ledger_store.dart     # +TemplateRow/TransactionRow+两方法
lib/report/data/report_ledger_store_impl.dart  # +两实现(expectedDates 预推演)
lib/report/presentation/widgets/mda_section.dart + mda_summary_card.dart
```
依赖方向不变(presentation→domain←data);mda/ 子域零外模块依赖;adapter 只依 core DAO+推演(见 Risks)。

## LLD(契约)

- `MdaFinding{ruleId, severity, conclusion, advice, actionLink?}`;`MdaSection{findings[](排序后), riskCount/warnCount/infoCount}`;总览摘要卡吃 counts+top3。
- `MdaThresholds`(const 全具名):savingsRiskBelow=0.10, savingsWarnBelow=0.20, budgetOverrunRiskPct=0.20, debtWarnAt=0.50, debtRiskAt=0.70, runwayWarnMonths=3, runwayRiskMonths=1, largeSingleDayAvgX=3, largeSingleSharePct=0.20, concentrationPct=0.40, spikePct=0.50, spikeSharePct=0.05, idleGraceDays=7(注释各带行业依据)。
- 规则表顺序=[R1,R6,R2,R3,R4,H1,H2,R5](风险类前);输出再按 severity 稳定排序(同 severity 按规则表序)。
- `templateRows()` adapter 预推演:复用 template 模块既有推演口径(`firstOnSeriesAfter` 同 server);**不得复制重写**——实现路径按 RecurrenceRule 实际所在层选择(execute 查证,见 Risks)。
- supplement:`trailing3mExpenseCents`=近三个完整月支出合计÷3(basis 口径);`cashStart/EndCents` 来自 replay savings 类账户合计。

## Risks / Trade-offs

- [recurrence 推演位置] 若在 template/data → 跨模块 import 违约 → 缓解:经 TemplateRepository domain port 暴露 `expectedDates(template, period)`(最小新增),或提纯函数至共享处;**禁止复制**。
- [误报伤信任] FR-3 四道防御已入 spec;R4 文案疑问式。
- [规则重叠] R1 与 R6 可能同红(储蓄率低+runway 短)——保留双条(口径不同),排序稳定。
- [R5 年付语境] 结论文案带「若为年付/预付类支出属正常」语境句。

## Migration Plan

纯新增:规则域+章节组件+port 两方法+ReportDocument 可选字段;回滚=移除注册与章节。

## Open Questions

(无——recurrence 位置属 execute 查证项,路径已在 Risks 预定。)
