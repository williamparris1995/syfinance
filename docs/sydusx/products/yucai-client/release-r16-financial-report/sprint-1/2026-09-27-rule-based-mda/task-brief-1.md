# Task Brief T1 — mda domain 纯核(F44 R16 sprint-1)

**工作目录(必须在此)**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f44`(分支 feature/r16-f44;`yucai/client/`)。

**流程**:先调 Skill 工具加载 `sydusx-tdd` 并遵循(ambiguous 则直读 C:/Users/BuHiYo-001/.agents/skills/sydusx-tdd/SKILL.md)。前置:F43 已落 `lib/report/domain/report_document.dart`(ReportDocument/章节 VO,先读——你的输入契约)。

## 任务:新建 `lib/report/domain/mda/`(纯 Dart 零外依赖,仅可 import 本模块 report_document)

1. **mda_models.dart**:MdaSeverity{risk,warn,info}/MdaFinding{ruleId,severity,conclusion(中文含溯源数字),advice,actionLink?}/MdaSection{findings(排序后),riskCount/warnCount/infoCount,factory 汇总}/MdaSupplement{templates:List<TemplateRowVO>(id,name,direction(expense?),amountCents,paused,autoRecord,nextDate,lastRecordedDate?,expectedDates),transactions:List<LargeTxnVO>(transactionId,date,description,expenseCents),trailing3mExpenseCents,cashStartCents,cashEndCents}/**MdaThresholds**(const 全具名:savingsRiskBelow=.10/savingsWarnBelow=.20/budgetOverrunRiskPct=.20/debtWarnAt=.50/debtRiskAt=.70/runwayWarnMonths=3/runwayRiskMonths=1/largeSingleDayAvgX=3/largeSingleSharePct=.20/concentrationPct=.40/spikePct=.50/spikeSharePct=.05/idleGraceDays=7,每个常量注释行业依据)。
2. **mda_rule.dart**:`abstract class MdaRule{String get id; List<MdaFinding> evaluate(ReportDocument doc, MdaSupplement sup);}`。
3. **mda_engine.dart**:@LazySingleton;规则表顺序 [R1,R6,R2,R3,R4,H1,H2,R5];输出按 severity(risk>warn>info)稳定排序(同 severity 保持规则表序)。
4. **rules/ 8 文件**(每规则一个文件,结论文案含溯源数字,advice 可执行):
   - R1 储蓄率:结余为负→risk「本期透支」;<10%→risk;10-20%→warn;≥20% 不触发。收入≤0 不触发(无法定义率)。
   - R2 预算超支:doc.budget 各 item:超支→warn;超支比例 ≥20%→risk。
   - R3 资产负债率:doc.balanceSheet.debtRatioPct(既有字段):≥70→risk;50-70→warn(结论文案带房贷语境「若含长期房贷属常见区间」)。
   - R4 闲置订阅:sup.templates 中 direction==expense 且 !paused 且 expectedDates(期内)非空 且(lastRecordedDate==null 或 < 期内首个 expectedDate-1 天)→warn;**grace**:nextDate 在期末后 idleGraceDays 内→不触发;文案疑问式「可能闲置:若仍在使用,记一笔时请关联该订阅」;多条合计月度等价(amountCents÷周期月数,周期月数=expectedDates 间距推 or 由 amount/yearly 简化——按 supplement 字段可行口径,注释说明);actionLink='/templates/subscriptions'(照订阅中心路由实际,先 grep router.dart 确认)。
   - R5 大额单笔:sup.transactions:expenseCents ≥ 日均支出×3 且 ≥ 当期总支出 20%→info;日均=doc.incomeStatement.expense÷当期天数;文案带年付语境句「若为年付/预付类支出属正常现象」。
   - R6 runway:trailing3mExpenseCents>0 时:cashEnd÷(trailing3m÷3)<1 月→risk;<3 月→warn;结论「现金可支撑约 X.X 个月」;trailing3m==0 不触发。
   - H1 集中度:doc.incomeStatement.expense 首条 pct ≥40%→warn(中性表述「支出集中于 XX 类别」)。
   - H2 环比突增:doc.incomeStatement.priorComparison 与支出构成对比?——注意 ReportDocument 只带当期构成+priorComparison 汇总,**无前期分类构成**;口径降级:仅当 priorComparison.deltaPct ≥50% 且(汇总级)时按总支出口径 warn?**不行**——按 spec H2 是类别级。处理:H2 需要 prior 期分类构成——把它也放 supplement(加 priorExpense:List<CategoryAmount>),汇编层 T2 会喂(T2 顺带算,与 trailing3m 同通道零新读取)。本票先定义 supplement.priorExpense 并实现 H2(环比+50% 且增加额≥当期总支出 5%)。
5. **mda_narrator.dart**:`abstract class MdaNarrator{Future<String> narrate(ReportDocument,List<MdaFinding>);}` + `NoopMdaNarrator`(返回空串,@LazySingleton(as:) 默认绑定)。FR-5 契约。

## 测试(yucai/client/test/report/domain/mda/ 镜像)

spec FR-2 的 4 个 scenario 逐字 oracle+每规则正反例(R4 三态:触发/grace/已推进;R6 三态 risk/warn/不触发;R5 双门槛单边不触发;H2 双门槛;R1 负结余 risk;R3 26.9% 不触发/55% warn/75% risk)+引擎排序稳定性+supplement 缺省(空模板/空交易)。全手算 oracle。

## 完成门

`flutter test test/report/domain/mda` 全绿+`flutter analyze` 446 持平+不碰既有文件(除新增)。commit `feat(report): T1 mda domain 纯核——引擎+8 规则+阈值常量+narrative port(TDD)`。回报:文件/测试数/commit/遗留。
