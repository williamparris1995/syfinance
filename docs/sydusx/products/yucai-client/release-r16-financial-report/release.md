# Release R16 — 财务报告(financial-report)

> /sydusx-portfolio 2026-09-25 立项。product checkpoint:重读 [vision.md](../vision.md),Product Goal(可分发的商业级个人专业理财客户端、19 模块行业级)ongoing;report 模块在 vision Overall Scope 内,本 release=report 模块深化。
> 起因:用户 2026-09-25 brainstorm「像上市公司财务报表一样,生成一份规范报告:消费习惯+潜在问题+优化方案」。现状调查:仅 /reports 交互图表页(TransactionSummary 单 RPC,2026-07-15 dashboard-report spec 产物),汇编层与 MD&A 生成层在代码/docs 均无痕迹。

## Release Goal

用户可按月/年生成一份章节式财务报告(资产负债/收支/现金流/预算执行/投资绩效汇编 + 规则版 MD&A:消费习惯/问题诊断/优化建议),应用内阅读并可导出规范文档;client 侧汇编复用既有 RPC,零 proto/server 改动,离线/guest 一致;支出聚合经 ExpenseBasis 口径抽象,v1 现金口径,待摊引擎(后续 release)落地后接入两口径切换。

## Decisions(用户拍板 2026-09-25)

- **诊断/建议 = 规则为主 + 预留 AI**:规则库出可解释硬结论(储蓄率/类别占比突增/预算超支/负债率/闲置订阅/大额异常),接口预留 LLM 叙述生成,本期不接。厘清:2026-09-24 待摊 spec「不做自动建议类 UX」限当票范围,本 release 显式做规则版建议(不冲突)。
- **形态 = 应用内报告页 + 导出文档**:两者都要;页面先行(F43/F44 sprint-1),导出 F45 sprint-2。
- **口径 = v1 现金口径 + ExpenseBasis 抽象预留**:两口径切换归待摊引擎接入时实现(其 spec 先决评审点③),本 release 只做抽象+现金实现+接入点测试。
- **排期 = R16 财务报告先行**:否决「待摊先行」(server 体量大+3 先决评审点未解,拖出值)与「双主题同 release」(偏大出值慢);待摊引擎 R17 候选。

## Sprint roster

- [x] [sprint-1](sprint-1/sprint.md) — F43 报告汇编层+财务报告页 / F44 规则诊断引擎(MD- [ ] [sprint-1](sprint-1/sprint.md) — F43 报告汇编层+财务报告页 / F44 规则诊断引擎(MD&A)A) ✅(2026-09-28 双票收官)
- [x] [sprint-2](sprint-2/sprint.md) — F45 报告导出 / F46 LLM 分析师 ✅(2026-09-28 双票收官)

## Done criteria

1. 月/年报告:章节式页面(总览/资产负债/收支/现金流/预算执行/投资绩效),数据=既有 RPC client 侧汇编,guest/离线路径一致,零 proto/server 改动。
2. MD&A:规则库产出消费习惯分析+问题诊断+优化建议,每条结论可溯源(数据+规则名);AI 接口预留不接实现。
3. 导出:报告可导出为规范文档(格式 F45 spec 定),与页面同源同一报告模型。
4. 支出聚合经 ExpenseBasis 抽象,现金口径实现+测试钉死;待摊口径接入点预留(不做实现)。
5. 全门:flutter test 全绿 + analyze 基线 + `make client-e2e`(零 proto 改动免 go 门)。

## status: done(R16 两 sprint 四票全收官=release 功能面 done 2026-09-28;发版待用户:tag 推送走 release.yml,当前版本基线 v1.0.9)
