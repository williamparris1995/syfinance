# Task Brief T5 — 卡面分期徽标(FR-4a)

## 上下文
worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f49`;客户端 `yucai/client`。**前置:T4 已完成 accounts_page 过滤接线**(同一文件,注意 rebase 其改动)。
先读 spec.md(FR-4a 场景「卡面摘要」)与 design.md(单元5)。视觉基准:prototype/v12/ui/f49-carrier-compare.html 的 fchip(「分期 1 笔 · 剩余 ¥8,400」,accent 令牌,余额下方)。

## 任务(TDD)
1. 纯函数:`debt/domain/debt_query.dart` 增 `({int count, int remainingCents}) cardInstallmentSummary(List<Debt> debts, String cardId)` —— 归集 `subtype==cardLoan && collectionAccountId==cardId && 未结清` 的剩余(本金口径=totalPrincipal−Σpaid,与 F36 同式;注释钉死「与 F50 额度占用同源单实现」)。单测:挂接归集/多笔求和/未结清口径(已清偿不计)/无挂接空态。
2. 徽标:accounts_page 信用卡卡片(accounts_page 现有 _debts 数据通道,T4 已滤载体——徽标数据走全量 debts 流不受过滤影响,核对数据源)余额下加 fchip 行:`分期 N 笔 · 剩余 ¥X`(N≥1 才渲染;context.yucai accent 令牌+tabular 数字,照 v12)。widget 测:挂 1 笔断文案与金额;0 笔不渲染。

## 约束
只动 debt_query.dart+accounts_page+两测试文件;禁碰 detail/form/repairs。

## 完成判据
四单测+两 widget 测绿;analyze 零新增;报告 fchip 挂接行号+改动清单。
