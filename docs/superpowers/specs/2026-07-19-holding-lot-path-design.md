# holding lot 路径 e2e + service newLot ID fix · 设计 spec

- **日期**: 2026-07-19
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: main(main-driven,从 main `d042f6e`)
- **范围**: 补 lot 路径 integration(FIFO lot consume + realized)+ **fix 陷阱 A production bug**(service newLot ID)。含 1 production fix + harness 扩展 + test。

## 1. 背景

holding e2e 套件系列全 4 spec 完成(performance + sell 双写 + price+snapshot + goal scheduler)+ 2 production fix(CreatedAt + Source)。本 spec 是 **future #1 lot 路径 e2e**(reviewer 在 performance/sell/price+snapshot/goal final review 多次 flag)。

lot 路径现状:
- domain `ConsumeLotsFIFO` 单测 7 个(完整)
- application BuyHolding/SellHolding lotRepo!=nil 单测(`memLotRepo` fake)
- lot_repo 单测(seed 不 Set ID)
- **integration gap**:doublewrite harness `lotRepo=nil` → lot 路径 integration **完全未覆盖**

**🚨 陷阱 A production bug**(调研发现):`service.BuyHolding` 预生成 `newLot.ID = uuid.New()`(service.go:106,非 Nil),`lot_repo.SaveAll` 用 `if l.ID == uuid.Nil` 判 Create vs Update(lot_repo.go:50)→ 非 Nil ID 走 `UpdateOneID` → **ent NotFound**。production wire 有 lotRepo → **BuyHolding 创 lot 在 ent 后端失败**。lot_repo_test 通过只因 seed 不 Set ID;service_test 通过只用 memLotRepo(容忍任意 ID)→ **production bug 隐藏**(第 3 个,继 CreatedAt + Source)。

## 2. 目标

- 补 lot 路径 integration(FIFO lot consume + realized)via doublewrite harness 扩展
- **fix 陷阱 A**(service newLot ID,production bug)

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | fix 陷阱 A | **方案 B**:service.go:106 newLot 去 ID(zero Nil),让 lot_repo Create Default | 最简(1 行 service);buy 创 lot(Default uuid.New),sell lots 来自 FindByHolding(有 ID → Update);newLot.ID 不被 service 读回(LotAvgCost/SaveAll 不用 ID);不动 lot_repo |
| 2 | 不用方案 A(改 lot_repo Create SetID) | 否 | 需改 lot_repo Create/Update 判定逻辑(ID==Nil 判失效);复杂;方案 B 等效且简 |
| 3 | harness 扩展 | doublewrite harness 加 `NewLotRepository` + `SetLotRepository` + 返 `holdClient`/`lotRepo` | 现成 harness 复用;返值加 holdClient/lotRepo 验 lot rows;现有 4 doublewrite test 改 `_` 接住新返值 |
| 4 | realized 验 | `tradeRepo.FindAll`(非 gRPC) | proto `tradeToProto` 剥 RealizedPnLCents(无此字段);走 tradeRepo.FindAll domain 字段 |
| 5 | FIFO consume 验 | `lotRepo.FindByHolding` RemainingQuantity | 验 lot 消耗(lot1 remaining 0 / lot2 remaining 部分) |

## 4. 范围边界

| 在范围 | 不在范围 |
|---|---|
| fix service newLot ID(陷阱 A,方案 B) | split lot 调整(domain 单测覆盖) |
| doublewrite harness 加 lotRepo + 返值扩展 | range-period(performance future) |
| TestLotPath_FIFOConsumeAndRealized(buy+sell FIFO + realized) | networth 多币种(独立) |
| realized via tradeRepo.FindAll + lot RemainingQuantity via lotRepo.FindByHolding | multi-account/savings-debt goal(goal future) |

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| production fix | [service.go:106](../../yucai/server/internal/holding/application/service.go) | newLot 去 `ID: uuid.New()`(zero Nil)→ lot_repo Create Default |
| harness | `setupHoldingDoubleWriteHarness`([:73-123](../../yucai/server/tests/holding_doublewrite_integration_test.go)) | 加 `NewLotRepository` + `SetLotRepository` + 返 `holdClient`/`lotRepo`(现有 test 改 `_` 接住) |
| test | `TestLotPath_FIFOConsumeAndRealized` | buy(创 lot)+ sell(FIFO consume)+ 验 lot RemainingQuantity + trade.RealizedPnLCents |
| 文件 | service.go(改)+ holding_doublewrite_integration_test.go(改,harness 返值 + 新 test) | fix + harness + test |

## 6. 核心改动

### 6.1 fix service newLot ID(陷阱 A,方案 B)

[service.go:104-109](../../yucai/server/internal/holding/application/service.go) BuyHolding newLot,去 `ID: uuid.New()`:
```go
tradeID := uuid.New()
newLot := domain.HoldingLot{
    // ID 留 zero(uuid.Nil)—— lot_repo SaveAll Create 分支(==Nil)走 ent Default(uuid.New)。
    // (修陷阱 A:原 ID: uuid.New() 非 Nil → lot_repo Update 分支 → ent NotFound。
    //  buy 后 newLot 不读回 ID;LotAvgCost/SaveAll 不用 ID;sell lots 来自 FindByHolding 有 ID。)
    TenantID: req.TenantID, HoldingID: h.ID, SecurityID: req.SecurityID,
    AcquiredDate: req.TradeDate, AcquiredTradeID: tradeID,
    PriceCents: req.PriceCents, Quantity: req.Quantity, RemainingQuantity: req.Quantity,
}
```

### 6.2 harness 扩展(setupHoldingDoubleWriteHarness)

[:89-92](../../yucai/server/tests/holding_doublewrite_integration_test.go) 加 lotRepo + SetLotRepository,返值加 holdClient/lotRepo:
```go
secRepo := holdingsec.NewSecurityRepository(holdClient)
holdRepo := holdingsec.NewHoldingRepository(holdClient)
tradeRepo := holdingsec.NewTradeRepository(holdClient)
lotRepo := holdingsec.NewLotRepository(holdClient)  // 新加
holdSvc := application.NewService(secRepo, holdRepo, tradeRepo)
holdSvc.SetLotRepository(lotRepo)                   // 新加(FIFO lot 路径)
h = holdgrpc.NewHoldingHandler(holdSvc, txnSvc, accountRepo)
```
返值签名加 `holdClient *holdingent.Client`(验 lot rows via ent)+ `lotRepo`(FindByHolding 验)。现有 4 doublewrite test 改 `_` 接住新返值(非破坏)。

### 6.3 TestLotPath_FIFOConsumeAndRealized

照 buy/sell FIFO 范式(domain ConsumeLotsFIFO 单测 + service lot 单测):
- buy 60 @ 10000(lot1: 60 qty @ 10000)+ buy 40 @ 12000(lot2: 40 qty @ 12000)→ holding 100 qty,AvgCost = LotAvgCost = (60×100+40×120)/100 = 10800
- sell 80 @ 13000 → FIFO consume:lot1 全 60(realized=(13000-10000)×60=180000)+ lot2 20(realized=(13000-12000)×20=20000)→ total realized=200000;lot1 remaining=0,lot2 remaining=20
- 验:
  - `lotRepo.FindByHolding`(via holdClient)lot1 RemainingQuantity=0,lot2 RemainingQuantity=20
  - `tradeRepo.FindAll` trade.RealizedPnLCents=200000(FIFO realized;proto 不透,走 tradeRepo)

## 7. 数据流

```
fix(service newLot ID=Nil)+ harness(lotRepo + SetLotRepository)
→ buy 60@10000: lot1(60@10000)Create(Default ID) + holding 60
→ buy 40@12000: lot2(40@12000)Create + holding 100, AvgCost=LotAvgCost=10800
→ sell 80@13000: ConsumeLotsFIFO(80, 13000, [lot1,lot2])
  → lot1 consume 60 (realized 180000) + lot2 consume 20 (realized 20000) = 200000
  → lot1 remaining=0, lot2 remaining=20, SaveAll(Update)
  → trade.RealizedPnLCents=200000
→ 验 lotRepo.FindByHolding(lot1=0, lot2=20) + tradeRepo.FindAll(realized=200000)
```

## 8. 测试

| 场景 | 覆盖 | 断言 |
|---|---|---|
| TestLotPath_FIFOConsumeAndRealized | lot 路径 integration(FIFO consume + realized) | lot1 remaining=0 / lot2 remaining=20 / trade.RealizedPnLCents=200000 |

零回归:全量 server 测 pass + build green(performance S1-S4 + sell 双写 + price+snapshot + goal scheduler + buy doublewrite 不破;现有 4 doublewrite test 改 `_` 接住 harness 新返值)。

## 9. 风险

1. **🚨 陷阱 A fix**(service newLot ID=Nil):否则套件第一个 BuyHolding 创 lot ent NotFound。fix 方案 B(1 行 service)。
2. **harness 返值扩展**(加 holdClient/lotRepo):现有 4 doublewrite test 改 `_` 接住(非破坏,加返值)。
3. **realized via tradeRepo**(陷阱 G):proto 不透 RealizedPnLCents;走 `tradeRepo.FindAll` domain 字段。
4. **ApplySell 双调用**(lot 路径 service.go:171 仍调 ApplySell 作 oversell guard + Quantity 减;realized 用 FIFO)。
5. **lots 总 remaining == holding.Quantity**(seed 一致,否则 ConsumeLotsFIFO fail;本 test 经 BuyHolding 创 lot,holding.Quantity 自动一致)。
6. **lot_repo SaveAll Update 分支**(sell lots 有 ID → UpdateOneID;buy newLot ID=Nil → Create Default)。
7. 零 proto/schema 改(仅 service.go 1 行 + test)。

## 10. 参考

- FIFO lot domain:[lot.go](../../yucai/server/internal/holding/domain/lot.go)(ConsumeLotsFIFO/LotAvgCost/HoldingLot)+ lot_test.go(7 单测)
- service lot 路径:[service.go:92-199](../../yucai/server/internal/holding/application/service.go)(BuyHolding/SellHolding lotRepo!=nil)
- lot_repo:[lot_repo.go:48-75](../../yucai/server/internal/holding/adapter/driven/repository/lot_repo.go)(SaveAll Create/Update + 陷阱 A)
- harness:[holding_doublewrite_integration_test.go:73-123](../../yucai/server/tests/holding_doublewrite_integration_test.go)(setupHoldingDoubleWriteHarness)
- holding e2e 套件:performance/sell/price+snapshot/goal scheduler spec + CreatedAt/Source fix spec
