# Task Brief C — F51 两页读侧统一(accounts_page numValue + account_detail_page 估值)

## 工作区(严格遵守)

- 一切操作在 git worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f51`(branch `feature/r17-f51`)
- 客户端代码根:`yucai/client/`;**禁止**改 proto/server、碰主仓、`git commit`
- 前置 TA 已落(未提交,直接消费):`debt/domain/debt_query.dart` 的 `derivedLoanFields`(估值只需 `.remainingPrincipalCents`)、`holding/domain/holding_query.dart` 的 `derivedInvestFields`(估值用市值合计)。F50 先例:accounts_page 已有 `_debts` 数据流与 `occupationFor` 闭包注入形态——本票照抄模式。

## 需求(spec FR-3/FR-4,design ADR-2/U4)

1. `yucai/client/lib/account/presentation/pages/accounts_page.dart`:
   - 新增持仓数据流 `_holdings`(照 `_debts` 既有拉取/生命周期模式;holding 仓库经 getIt/bloc 既有管道,先 grep 库内谁消费 holdings 找参照)
   - `int? derivedValueFor(Account a)` 闭包:a.category==loan ∧ 有挂接债 → Σ债剩余本金(`derivedLoanFields(...).remainingPrincipalCents`);a.category==investment ∧ 有挂接持仓 → Σ持仓市值(`derivedInvestFields(...)` 市值合计);否则 null
   - `numValue`(顶层函数,:70-100)各 category 分支**前置**该闭包:非 null 用派生值,null→原列读逻辑完全不变(FR-4);汇总头/卡片均经此路径
2. `yucai/client/lib/account/presentation/pages/account_detail_page.dart`:loan/investment 账户 hero 与卡片估值同闭包改造(与 accounts_page 数字同源);**「持仓列表」占位面板(:523)不碰**。
3. display-only:不写任何账户列/聚合落库路径。

## TDD(强制)

先失败测试再实现;单文件 RED→GREEN;完成后 `flutter test test/account` + `flutter analyze` 无新增。测试至少:①spec FR-3 Scenario:loan 账户挂债、`loanRemainingCents` 列 stale=0 → 账户页估值/汇总头显示 Σ债剩余(FR-1 数字 3,422,376 cents)②挂持仓 investment 账户列 stale → 显示 Σ持仓市值 ③未挂接账户:改动前后 numValue 输出逐分一致(对照断言)④跨页一致:同账户详情 hero == accounts_page 卡片值 ⑤占位面板文本仍在。

## 汇报

文件清单+要点、RED/GREEN 证据、模块套件与 analyze 结果、holdings 数据流接入点说明。
