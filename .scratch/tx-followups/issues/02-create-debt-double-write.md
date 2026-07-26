# 02 · CreateDebt 双写原子化

Type: task
Status: open
Priority: P1
Blocked by: —

## Question

`CreateDebt`(debt handler `recordCreateTransaction` 路径)双写仍 best-effort:debt 落库 + 现金 transaction 吞错 → 债已建但现金未记。同 pre-Task-6 RecordPayment defect shape(净资产虚高)。03 实施时 D3 scope(repayment)外。

## Fix

下沉现金写到 debt service + `sqltx.WithTx`(同 D3 RecordPayment 范式,Task 6)。复用 `RepaymentCashRecorder` port 或加 CreateDebt port;handler best-effort 吞错删除。

关联:03 spec;Task 6 提供范式(`debt/domain/repayment_cash_port.go` + `transaction/application/repayment_cash_adapter.go`)。
