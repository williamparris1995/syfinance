# Code Plan — F44 规则诊断引擎 MD&A

> execute 2026-09-27。依据 spec(FR-1..5/NFR-1..3)+design(ADR-1..6)+prototype v8。生产代码全部 `yucai/client/`;零 proto/server。全局约定同 F43(DDD/中文/cents/injectable/零裸色)。

## 任务分解

- [x] **T1 mda domain 纯核**(S1/S2/S3/S4/S6):`lib/report/domain/mda/` — models(Severity/Finding/Section/Thresholds const/Supplement)+MdaRule 接口+引擎(遍历+severity 稳定排序)+8 规则(R1-R6/H1-H2,每规则 scenario oracle;R4 四道防御;R5 年付语境句)+narrative port+Noop 实现。纯 Dart TDD(fake ReportDocument+Supplement)。
- [x] **T2 port 两方法+supplement 接线**(S1 后半):`report_ledger_store.dart` +TemplateRow{...expectedDates}/TransactionRow{...description/expenseCents}+两方法;adapter 实现(**expectedDates 推演=core/recurrence/next_after.dart 直用,禁复制**;单笔支出额=交易内 expense 科目 debit 合计);汇编服务 assembling 阶段跑引擎→`ReportDocument.mda`(supplement 内 trailing3m/cashStart/cashEnd 复用既有 entries+replay 零新读取);conformance 门保持绿。
- [x] **T3 presentation**(S5):`mda_section.dart`(第七章节:分组/健康态)+`mda_summary_card.dart`(两态)挂报告页 `_chapters` 链+总览;按 prototype v8 形态;严重度→既有语义色零新令牌;widget 测试(两态/分组/逐字文案/跳转链)。
- [x] **T4 门与收尾**(S7):e2e 扩断言(诊断章节+摘要卡两态);全量 flutter test+analyze 446 持平+零 proto diff+build_runner 幂等;NFR-1 计时(8 规则 ≤500ms 测试)。

## 依赖

T1→T2→T3→T4 串行(T1 纯 domain 无依赖先行);每 task 两轴评审+修复回路(F43 同规程)。

## 验收映射

FR-1→T1/T2;FR-2→T1;FR-3→T1(R4);FR-4→T3;FR-5→T1(narrative);NFR-1→T4;NFR-2→T4;NFR-3→T3。
