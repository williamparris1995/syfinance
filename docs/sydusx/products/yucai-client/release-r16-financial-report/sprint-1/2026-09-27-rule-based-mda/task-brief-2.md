# Task Brief T2 — port 两方法+supplement 接线(F44 R16 sprint-1)

**工作目录**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f44`(分支 feature/r16-f44;`yucai/client/`)。**流程**:先加载 sydusx-tdd。前置:T1 mda domain(aada48ea)已落;F43 的 report_ledger_store/report_assembly_service/report_document 在位。

## 任务

1. **port 扩两方法**(`lib/report/domain/report_ledger_store.dart` + adapter 实现 `report_ledger_store_impl.dart`):
   - `templateRows()`:读 TransactionTemplates 全量→TemplateRowVO(T1 已定义字段);**expectedDates 期外预推演在 adapter 做**:推演函数直用 `lib/core/recurrence/next_after.dart`(core 共享基建,禁复制);lastRecordedDate=lastTransactionId→Transactions 日期(一次 join);direction/paused/nextDate 等直读列。
   - `transactions()`:Transactions 全量头行+按 transactionId 聚合 expenseCents(该交易 expense 科目 debit 合计,复用 entries 读法)→LargeTxnVO(description 直投影)。
2. **汇编接线**(`report_assembly_service.dart`):assembling 阶段构建 MdaSupplement——trailing3mExpenseCents(近三个完整月支出,复用既有 entries+basis,注意月报/年报期型:取 period.start 前 3 个完整月)、cashStart/EndCents(savings 类 replay 合计,既有计算复用)、priorExpense(上一期支出构成,复用既有聚合)、templates/transactions(新 port 方法)→跑 MdaEngine→`ReportDocument.mda`(T2 给 ReportDocument 加可选字段 mda,默认 null 兼容既有构造/测试)。
3. **DI**:`dart run build_runner build --delete-conflicting-outputs` 注册 MdaEngine/NoopMdaNarrator;injection.config 仅 regen 差异。
4. **顺手修**(T1 评审 trivial):r5_large_single_test.dart 头注「9.7%」上界改「对天数 ≥15 的报告期占比门恒更严」严谨表述。
5. **测试**:adapter 两方法(drift 内存库种子:模板含年付/月付/paused 三态+expectedDates 断言+lastRecordedDate join);汇编集成(fake store 全链→doc.mda 非空+supplement 数字手算 oracle:trailing3m 三月构造/priorExpense=上一期构成/mda 章节随快照生成);**conformance 门保持绿**;ReportDocument.mda 默认 null 兼容测试既有零改。

## 完成门

`flutter test test/report` 全绿+全量绿+analyze 446 持平+build_runner 幂等。commit `feat(report): T2 mda 接线——port 两方法+supplement 构建+ReportDocument.mda 快照章节`。回报:文件/测试数/commit/遗留。
