# Task Brief C — F50 两页显示注入(账户页卡片 + 详情页四卡)

## 工作区(严格遵守)

- 一切操作在 git worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f50`(branch `feature/r17-f50`)
- 客户端代码根:`yucai/client/`;**禁止**改 proto/server、碰主仓、`git commit`
- 前置 TA 已落:`debt/domain/debt_query.dart` 的 `cardLoanOccupationCents(List<Debt>, String cardId)`(仅剩余本金口径+开关过滤)
- **先例参照**:`git -C <worktree> show 794bc677` 是 2026-09-30 被回退的同位实现(注入形态/组件参数可直接参照,但口径不同:那次是 本金+息费 且无开关;这次只调 `cardLoanOccupationCents`,金额语义已由 TA 的纯函数保证)

## 需求(spec FR-1/FR-3,design ADR-3/U4)

1. `account/presentation/pages/accounts_page.dart`:
   - `occupationFor: (a) => cardLoanOccupationCents(_debts, a.id)` 注入 `_GroupBlock/_AccountColumn`(照 794bc677 diff 形态,含 `_zeroOccupation` 缺省,测试 harness 不受影响)
   - creditCard 卡片「已用 X / 额度」= `abs(currentBalanceCents) + occupation`;利用率条分子同式,clamp(0,1) 保留
2. `account/presentation/pages/account_detail_page.dart`:四卡「已用/可用额度」:已用 = `abs(balance)+occupation`;**可用 = limit − 已用**(现行 7245465c 是 limit−欠款 单减法,改为再减占用;`avail` 两处 1347/1351/1361 附近)
3. **display-only 铁律**:不得改任何余额/净资产/记账路径。测试必须断言:同一数据下切换某债开关,账户/负债聚合与净资产逐分不变,仅已用/可用/利用率变化。

## TDD(强制)

先失败测试再实现;单文件 RED→GREEN;完成后 `flutter test test/account`(或对应目录)模块套件 + `flutter analyze` 无新增。测试至少:①平安校准 fixture:卡欠 31,963c + 占用 1,095,207c + limit 5,000,000c → 页面级已用 1,127,170c/可用 3,872,830c(用 widget 或 bloc 层能锚到的最深断言)②e招贷未挂接 → 招行卡已用不变 ③display-only 断言(开关切换前后聚合/净资产逐分一致;净资产锚点找 dashboard/net worth 既有 provider 或聚合纯函数)。

## 汇报

文件清单+要点、RED/GREEN 证据、模块套件与 analyze 结果、display-only 断言锚点说明。
