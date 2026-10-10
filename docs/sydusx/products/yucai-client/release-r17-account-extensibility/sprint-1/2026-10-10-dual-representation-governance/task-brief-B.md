# Task Brief B — F51 表单降级态(account_form_page 只读+派生+提交不写列)

## 工作区(严格遵守)

- 一切操作在 git worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f51`(branch `feature/r17-f51`)
- 客户端代码根:`yucai/client/`;**禁止**改 proto/server、碰主仓、`git commit`
- 前置 TA 已落(未提交,直接消费):`debt/domain/debt_query.dart` 的 `derivedLoanFields(List<Debt>, Map<String, DebtNextPeriod>)` + `debtNextPeriod(List<PaymentEntry>)` + `DebtNextPeriod/DerivedLoanFields`;`holding/domain/holding_query.dart` 的 `derivedInvestFields`(收 `Holding` 实体,已带算好 marketValueCents)。期表取数路径:`DebtLocalDataSource.getDebtDetail()` 返回 `DebtDetail.schedule`(PaymentEntry 列表)。

## 需求(spec FR-1/FR-2,design ADR-3/U3)

`yucai/client/lib/account/presentation/pages/account_form_page.dart`:

1. **编辑态挂接检测**(一次性取,经 getIt 仓库——测试坑记忆:getIt 须注册 mock):
   - loan 组降级条件:编辑中账户 category==loan ∧ ∃ debt.accountId==账户id(借入债)
   - invest 组降级条件:category==investment ∧ ∃ holding.accountId==账户id
   - 新建态不降级(无既有挂接)
2. **降级渲染**:对应字段组只读——显示派生值(loan 四值:总额/剩余/月供/下期日,月供 null 显「—」;invest 成本/市值,ytd 显「—」)+ 组头提示条「以债务/持仓数据为准,请在债务/持仓页维护」(复用库内 callout/提示条既有模式)。派生数据组装:挂接债列表 + 各债 `debtNextPeriod(schedule)` → `derivedLoanFields`;挂接 Holding 列表 → `derivedInvestFields`。
3. **提交不写列**:降级态保存时,loan/invest 组的 params 字段全部传 **null**(account_local_ds `orAbsent` = 保留原列值,实证 :159)。

## TDD(强制)

先失败测试再实现;单文件 RED→GREEN;完成后 `flutter test test/account`(含既有表单测试回归)+ `flutter analyze` 无新增。测试至少:①挂债 loan 账户编辑→loan 组只读+派生值(spec 数字:总额 ¥44,100.00/剩余 ¥34,223.76/月供 ¥2,077.90/下期 2026-10-12)+提示条 ②无挂接/新建态→组可编辑原样 ③降级态保存→repo/DS 捕获 params 的 loan 组字段为 null ④invest 挂持仓同理(成本/市值/ytd「—」)。

## 汇报

文件清单+要点、RED/GREEN 证据、模块套件与 analyze 结果。
