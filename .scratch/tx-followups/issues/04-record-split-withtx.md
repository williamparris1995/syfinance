# 04 · RecordSplit WithTx 包裹

Type: task
Status: open
Priority: P2
Blocked by: —

## Question

`holding.RecordSplit` 未包 `sqltx.WithTx`(03 D2 scope 限 Buy/Sell)。splits 罕见且 operator-initiated,但同 holding 写(holding 更新 + split 调整)应原子。

## Fix

repo `clientFor` 已启用(D2,holding_repo),wrap 是 ~6 行:`runInTx` + body rename(`recordSplit(ctx)`),参照 BuyHolding/SellHolding 范式。

关联:03 spec 阶段 B(D2 holding)。
