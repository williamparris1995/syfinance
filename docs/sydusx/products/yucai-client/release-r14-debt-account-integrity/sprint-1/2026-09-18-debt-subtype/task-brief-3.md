# Task Brief T3 — client domain：9 类常量 + DebtSubtypeAffinity

## 任务
`lib/debt/domain/value_objects.dart`：
1. `DebtSubtypes` 扩 4 类：`credit_loan`(信用贷款) / `cash_installment`(现金分期) / `consumption_loan`(消费贷) / `business_loan`(经营贷)——加进 `all` 列表（顺序按 prototype v3：mortgage, auto_loan, credit_loan, cash_installment, consumption_loan, business_loan, credit_card, family, other）+ `labels` 中文映射。
2. 新增 `DebtSubtypeAffinity`（design contract，见 design.md LLD ①）：

```dart
abstract final class DebtSubtypeAffinity {
  static const Map<AccountCategory, Set<String>> compatible = {
    AccountCategory.loan: {mortgage, autoLoan, creditLoan, cashInstallment, consumptionLoan, businessLoan},
    AccountCategory.creditCard: {creditCard},
    AccountCategory.otherLiability: {family},
  };
  static String? defaultSubtypeFor(AccountCategory category); // 无兼容值返回 null
  static bool isConflict(AccountCategory? category, String subtypeKey); // other 恒 false；category null → false(未选账户不提示)
}
```
注意 `AccountCategory` 来自 `lib/account/domain/value_objects.dart`——**跨模块 import 方向**：debt domain 引 account domain 的枚举是否合规？先查 `lib/debt` 现有对 account 的依赖先例；若无先例则按项目「跨模块 port 模式」把 category 以 int/String 参数传入 affinity（调用方解耦），**不要擅自新开跨模块 import**——在代码注释与本报告里说明选择。

## TDD 周期（sydusx-tdd）
1. RED：`test/debt/domain/value_objects_test.dart`（若无则新建，沿用现有 domain 测试风格）——9 类 labels 完整；isConflict：loan×family=true / loan×credit_loan=false / creditCard×mortgage=true / otherLiability×family=false / 任意×other=false / null×任意=false；defaultSubtypeFor：loan→credit_loan / creditCard→credit_card / otherLiability→family / savings→null。
2. GREEN：实现。
3. 回归：`flutter test test/debt/` + `dart analyze lib/debt/`（零新增 info）。

## 约束
- 单一事实源（NFR-1）：分类/白名单只在此文件，别处引用常量。
- 完成后报告：改动文件 + 测试输出 + analyze 结果。
- 工作目录：`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r14-f33`（分支 feature/r14-f33-debt-subtype，勿切分支）。
