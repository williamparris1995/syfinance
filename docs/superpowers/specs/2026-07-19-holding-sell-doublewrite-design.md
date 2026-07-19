# holding sell 双写 black-box e2e · 设计 spec

- **日期**: 2026-07-19
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: main(main-driven,从 main `ebd4e2a`)
- **范围**: 补 holding **sell 双写** integration test(照 buy [holding_doublewrite_integration_test.go](../../yucai/server/tests/holding_doublewrite_integration_test.go) 范式)。**纯 test 新增**,零 proto/schema/production 改。

## 1. 背景

holding e2e 套件系列:performance 计算 ✅ done(`8694afa..3d34548`)+ CreatedAt bug ✅ fixed(`ebd4e2a`)。本 spec 是第 2 个子 spec(双写扩展)。

双写现状(handler [holding_handler.go:91-201](../../yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go)):
- **BuyHolding 双写** ✅ 有 black-box test(holding_doublewrite buy + fail-fast 余额不足)
- **SellHolding 双写** —— handler 有 `recordTradeTransaction`(cash in from + investment out holding),**但无 integration test**(扩展点)
- **RecordDividend / RecordSplit** —— **不双写**(handler 设计无 `recordTradeTransaction`;dividend 是 income 不涉 account、split 非现金流)

故"双写扩展"= **sell 双写 black-box**。

## 2. 目标

补 sell 双写 integration test(照 buy 范式):验 sell cross-module 双写(from cash 入账 + holding account 撤资 + transaction 落库 + Quantity 减)+ sell fail-fast(quantity 不足 service 拒)。

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | scope | sell 双写 only | dividend/split handler 设计无 `recordTradeTransaction`(income/非现金流,不涉 account);非 bug |
| 2 | 入口层 | handler 层(NewHoldingHandler + gRPC SellHolding) | 双写在 handler(service 不双写 account);照 buy doublewrite test 范式 |
| 3 | harness | 复用 `setupHoldingDoubleWriteHarness` | 现成(真 ent + BalanceUpdater + txnSvc + accountRepo,共享 sqlite);buy 已用 |
| 4 | fail-fast | sell quantity 不足(service.SellHolding fail) | sell 不查 from 余额(`validateTradeFromAccount` isBuy=false);fail 在 service quantity |
| 5 | black-box | `acctSvc.GetAccount` 验余额 + transaction 查 | 照 buy(不 inspect 内部,经 service black-box) |

## 4. 范围边界

| 在范围 | 不在范围 |
|---|---|
| TestHoldingSell_DoubleWrite_EndToEnd(buy+sell happy path) | dividend/split 双写(handler 设计不双写) |
| TestHoldingSell_QuantityInsufficient_FailFast | production 改(零 proto/schema/handler) |
| 复用 `setupHoldingDoubleWriteHarness` | price+snapshot 回填(第 3 spec) |
| GetAccount black-box + transaction 落库 + Quantity 验 | goal+多币种(第 4 spec) |

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| harness | `setupHoldingDoubleWriteHarness` | **复用**([holding_doublewrite_integration_test.go:73-123](../../yucai/server/tests/holding_doublewrite_integration_test.go)) |
| 入口 | `NewHoldingHandler(holdSvc, txnSvc, accountRepo)` | 照 buy doublewrite test |
| black-box | `acctSvc.GetAccount` | 验 from/holding 余额(照 buy) |
| 文件 | `yucai/server/tests/holding_doublewrite_integration_test.go` | +2 test(同文件追加) |

## 6. 核心改动

### 6.1 TestHoldingSell_DoubleWrite_EndToEnd

照 `TestHoldingBuy_DoubleWrite_EndToEnd`([:133-183](../../yucai/server/tests/holding_doublewrite_integration_test.go))范式 —— 先 buy 建 holding,再 sell,black-box 验余额/落库/Quantity。

fixture(buy 10 qty @ 5000 建 holding,then sell 5 qty @ 6000):
- buy 10 qty @ 5000 cents/share → amount 50000 cents;from 100000→50000(−50000),holding 0→50000(+50000),Quantity 10(照 buy test 现有 fixture)
- sell 5 qty @ 6000 cents/share → amount 5×6000=30000 cents
- 预期(sell 双写:cash in from + investment out holding):
  - from balance:50000 → 50000 + 30000 = **80000**(sell 现金入账)
  - holding balance:50000 → 50000 − 30000 = **20000**(投资撤资)
  - transaction 落库:Transfer(holding→from)
  - holding.Quantity:10 → **5**
- 断言:`acctSvc.GetAccount` 读 from/holding 余额 + holding.Quantity + transaction 存在

### 6.2 TestHoldingSell_QuantityInsufficient_FailFast

照 `TestHoldingBuy_InsufficientBalance_FailFast`([:189-235](../../yucai/server/tests/holding_doublewrite_integration_test.go))范式 —— sell 超过持仓 → service 拒 + 无副作用。
- buy 10 qty(holding 10)
- sell 20 qty(>holding 10)→ `service.SellHolding` fail(quantity 不足)
- 断言:
  - fail(err != nil)
  - 无 trade(`ListHoldings` holding 不变,Quantity 仍 10)
  - from/holding 余额不变(fail-fast;service fail 先于 handler `recordTradeTransaction`)

## 7. 数据流

**sell happy**:
```
buy(10 qty @ 5000: from 100000→50000, holding 0→50000, qty 10)
→ sell(5 qty @ 6000, amount 30000)
→ handler.SellHolding: service.SellHolding(holding 10→5) + recordTradeTransaction(Transfer holding→from)
→ from 50000→80000, holding 50000→20000, qty 5, txn 落库
```

**sell fail-fast**:
```
buy(holding 10 qty)
→ sell(20 qty > 10) → service.SellHolding fail(quantity 不足)
→ handler return error(先于 recordTradeTransaction)
→ from/holding 余额不变 + 无 trade
```

## 8. 测试

| 场景 | 覆盖 | 断言 |
|---|---|---|
| TestHoldingSell_DoubleWrite_EndToEnd | sell 双写 happy | from +amount / holding −amount / transaction Transfer / Quantity 10→5 |
| TestHoldingSell_QuantityInsufficient_FailFast | sell fail-fast | fail + 无 trade + 余额不变 |

零回归:全量 server 测 pass + build green(buy doublewrite test 不破,套件 S1-S4 不破)。

## 9. 风险

1. **sell 余额方向**:implementer TDD 调通(照 buy 反向:buy from −/holding +;sell holding −/from +)。`recordTradeTransaction` sell 分支(TransactionType/方向)需确认 —— 若方向与预期反,断言相应调整(诚实报告实际行为)。
2. **sell fail-fast 在 service**:`service.SellHolding` 验 quantity 不足(handler `validateTradeFromAccount` sell isBuy=false 不查余额)。fail 必须先于 `recordTradeTransaction`(handler L152-163:service fail → return,不调 recordTradeTransaction)。
3. **transaction Transfer 方向**:sell Transfer holding→from vs buy from→holding。implementer 调通确认。
4. 零 proto/schema/production 改(纯 test 追加)。

## 10. 参考

- buy 双写范式:[holding_doublewrite_integration_test.go](../../yucai/server/tests/holding_doublewrite_integration_test.go)(`setupHoldingDoubleWriteHarness` L73-123 + `TestHoldingBuy_DoubleWrite_EndToEnd` L133-183 + `TestHoldingBuy_InsufficientBalance_FailFast` L189-235)
- handler 双写:[holding_handler.go SellHolding:129-166](../../yucai/server/internal/holding/adapter/driving/grpc/holding_handler.go)(`recordTradeTransaction` L163 cash in from + investment out holding)
- holding e2e 套件:[2026-07-19-holding-e2e-design.md](2026-07-19-holding-e2e-design.md)(套件系列第 1 spec)
