# 05 · cash TransactionDate 用 trade date

Type: task
Status: open
Priority: P2
Blocked by: —

## Question

D2/D3 的 cash record `TransactionDate = time.Now()`(holding `buildTradeCashRecord` / debt `buildRepaymentCashRecord`)而非 `req.TradeDate`/schedule `PaymentDate` —— 现金侧记 wall-clock now,trade/entry 侧记 operator 日期(back-date 时分歧,报表/对账不一致)。pre-existing(03 保留未改)。

## Fix

cash record 的 TransactionDate 改用 `req.TradeDate`(holding)/ 对应 schedule entry `PaymentDate`(debt)。

关联:03 Task 5/6 concerns。
