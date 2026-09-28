# Sprint 1 — R16 财务报告:汇编层+报告页+规则诊断(F43+F44)

> /sydusx-portfolio 2026-09-25 立项。brainstorm 三决策(规则为主+预留 AI / 页面+导出 / R16 先行)见 [release.md](../release.md) Decisions。

## Sprint Goal

用户可按月/年生成分章节的财务报告并应用内阅读:汇编层(多 RPC 聚合+现金流量表+ExpenseBasis 口径抽象)+章节式报告页(F43),叠加规则版 MD&A「诊断与建议」章节(F44);零 proto/server 改动,离线/guest 一致。

## Feature roster

- [x] **feature F43** financial-report-page — 报告汇编层+财务报告页(报告模型/纯本地汇编/回放/现金流分类器/ExpenseBasis 抽象/章节式页面) ✅ done(2026-09-25,ff 合并 `5630030b`:全流程 analysis[六决策 grill]→design[ADR×7+prototype v7 变体 B,OD run 64dbf66b]→execute[T1-T6 SDD:六任务+五回合两轴评审全修毕——1 Important×3 拍平:basis debit 单边/toLocal 时区陷阱/预算同账户翻倍]→review 门[REJECT→PASS:FR-7 假 basis 替换测试补齐,sabotage RED 证据]→test 门;**门:2168 测全绿+analyze 446 零新增+client-e2e 15/15[新成员 financial_report]+proto/server 零 diff+NFR-1 计时~1s<2s**;conformance 双门[summary 收支逐项相等+budget 口径对照];金图=亮色近同图 0.16% 带状差。backlog:页面拆分[F45 前]/金图 ThemeMode 钉死/绩效 Failure 文案细分/净额 basis[R17 候选])
- [x] **feature F44** rule-based-mda — 规则诊断引擎 MD&A(规则引擎+R1-R6/H1-H2 八规则+闲置四防御+第七章节+摘要卡+narrative 预留) ✅ done(2026-09-28,ff 合并 `1ff0ac04`:三决策 grill[规则集+阈值行业依据/闲置近似口径+四防御/诊断随快照+第七章节+自适应摘要卡;用户提出的 LLM 分析师构想评估后立 F46 分层,R6 runway 由该讨论吸收]→design[ADR-6+prototype v8=OD 增量 run 3f2be5dd]→execute T1-T4 SDD[三回合两轴评审+修复回路:T2 maxSteps 钳制+2 月跨年 oracle/T3 健康卡 runway 三指标+info chip 对齐 v8]→feature 门 PASS[两轴 clean+code↔v8 高保真]→test 门[**2262 测全绿+e2e 15 套件 66 测+analyze 446+NFR-1 引擎 9ms<500ms**];conformance 门保持绿;**顺治 main 既有 flake**:credit_card_due_source 日期漂移改 clock 注入缝[`563d9089`,独立 commit,双态复现证据]。backlog:金额格式化三处并存抽 core 单点/actionLink 标签泛化[第二条产链规则落地时]/阈值用户可配置)

## status: done(F43+F44 双票收官=sprint-1 功能 done 2026-09-28;F44 含独立 flake 治本 commit)
