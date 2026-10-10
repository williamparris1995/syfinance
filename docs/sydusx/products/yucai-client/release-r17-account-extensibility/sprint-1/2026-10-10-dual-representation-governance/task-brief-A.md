# Task Brief A — F51 派生函数垂直片(debt/domain loan 四值 + holding/domain invest 两值)

## 工作区(严格遵守)

- 一切操作在 git worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f51`(branch `feature/r17-f51`)
- 客户端代码根:`yucai/client/`;**禁止**改 proto/server、碰主仓、`git commit`

## 需求(spec FR-1/FR-2,design ADR-1/U1/U2)

1. `yucai/client/lib/debt/domain/`(落位照 F50 的 cardLoanOccupationCents 在 debt_query.dart 的先例,或独立文件按域内惯例):

```
class DerivedLoanFields {
  final int totalPrincipalCents;      // Σ debt.totalPrincipalCents
  final int remainingPrincipalCents;  // Σ debt.remainingPrincipalCents
  final int? nextPaymentCents;        // Σ 各债下一未还期 total;无期表债计 0;全无→null
  final DateTime? nextPaymentDate;    // min 各债下一未还期日;全无→null
}
DerivedLoanFields derivedLoanFields(List<Debt> debts, Map<String, DebtNextPeriod> nextByDebtId)
// DebtNextPeriod{int totalCents; DateTime date;} 最小投影,调用方从期表构造;
// 下一未还期定义 = payment_schedule paid=0 中 payment_date 最早(含逾期未付)
```

空债列表 → 返回全 0/null 的空视图(不抛)。

2. `yucai/client/lib/holding/domain/`:invest 两值纯函数——Σ成本(每持仓 数量×均价成本,与持仓页口径同源;查 holding 域既有实体/口径先例,若已有 helper 直接复用)、Σ市值(收「每持仓市值已算好」的投影,函数不依赖 price 仓库)。签名自定,贴域内惯例,注释中文。

## TDD(强制)

先失败测试再实现;单文件 RED→GREEN;完成后 `flutter test test/debt test/holding`(或对应目录)模块套件 + `flutter analyze` 无新增。测试至少:

- loan 多债聚合:2 债(总额 3,500,000+910,000 cents,剩余 2,968,344+454,032 cents;下一未还期 163,046@2026-10-12 与 44,744@2026-10-25)→ {4,410,000; 3,422,376; 207,790; 2026-10-12}
- 一债无期表投影 → 月供计 0、下期日 null;两债全付清(投影空)→ nextPaymentCents==null
- 逾期期计入:下一未还期日期在过去仍作为下期
- 空列表 → 全零视图
- invest:两持仓成本/市值求和;空列表→0

## 汇报

文件清单+要点、RED/GREEN 证据、模块套件与 analyze 结果、期表/持仓投影复用的既有类型清单(供 TB/TC 组装)。
