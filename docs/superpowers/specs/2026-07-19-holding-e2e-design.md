# holding performance 计算 e2e · 设计 spec

- **日期**: 2026-07-19
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: 待定(main-driven,从 main `5ee50c7`)
- **范围**: holding performance 计算(XIRR / TWR / CAGR,full + range,单标的 + 组合)的 enttest SQLite integration test。方案 A(固定时序 fixture + 精确数值断言)。**主体为 server-only 测试新增**;含一处最小生产改动 = Service `now` 注入(`time.Now()` 内部化,test 可控评估日,见决策 6 + §9.3)。

## 1. 背景

holding performance 计算(XIRR/TWR/CAGR)是系统最复杂、最易回归的部分。memory `holding-asset-management-todo` 反复记载靠 Excel `=XIRR()` / GIPS 手推验证绝对正确性(XIRR 0.373362535 误差 1.49e-09、TWR GIPS 三场景手推、CAGR 复合年化),但**这些验证从未进自动化测试**。

现有覆盖缺口:
- **domain 单测**([xirr_service_test.go](../../yucai/server/internal/holding/application/xirr_service_test.go) 等):fake repo + struct literal `Service`,断言**极弱** —— 只验方向/非空(`if *full <= 0 { want positive }`、`if out.AnnualizedPct == nil`),不锁数值。
- **codegraph 警告**:`portfolioXIRR`、`portfolioTWR` **零测试覆盖**(组合级 XIRR/TWR 从未被测);`portfolioCAGR` 仅单测。
- **integration test 层**:holding 已有 [holding_integration_test.go](../../yucai/server/tests/holding_integration_test.go)(CRUD/trade 动作,断言弱)+ [holding_doublewrite_integration_test.go](../../yucai/server/tests/holding_doublewrite_integration_test.go)(buy 双写 black-box,强),但 performance 计算层**零 integration 覆盖**。

本 spec 是 holding e2e 分 spec 系列的**第 1 个**(performance 计算)。后续 3 个独立 spec:双写扩展(sell/dividend/split)/ price+snapshot 回填 / goal 集成 + 多币种。

## 2. 目标

- 把 Excel/GIPS 手算验证固化为**精确数值回归网**(±1e-6 容差)
- 补 `portfolioXIRR` / `portfolioTWR` 零覆盖
- 锁定 cache 透明性(byte-identical)+ split-adjusted(split 日 BV 修正)不变式

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 方案 | 固定 fixture + 精确数值(方案 A) | memory 核心关注绝对正确性;方向/行为断言不能防精度回归(0.373→0.385 都"正向"通过) |
| 2 | 入口层 | service 层(非 handler) | handler 薄(tenant 校验 + proto 转换);service 层直接验计算,延续 domain 单测模式 |
| 3 | 范围管理 | 分 spec,performance 先 | 4 子系统独立(performance/双写/price+snapshot/goal+多币种);先攻最大风险 |
| 4 | 形式 | enttest SQLite integration(项目范式) | grpcurl 真 server e2e 项目从未脚本化;enttest 范式已就绪(setupHoldingDoubleWriteTestDB) |
| 5 | 期望值来源 | Excel `=XIRR()` / GIPS 手推 / memory 既有值,固化为常量;±1e-6 容差 | 锁定绝对正确性;容差容忍浮点误差 |
| 6 | time.Now 处理 | Service 加 `now func() time.Time` 字段(默认 `time.Now`),内部 `time.Now()` → `s.now()`;test struct literal 注入固定评估日 2021-01-01 | 年化本质依赖评估日;S1 期望 0.30 成立前提;真实今天致 flaky |
| 7 | 不变式 | cache 透明(byte-identical)+ split 中性 + range⊂full | 补充精确值的数学性质锁定 |

## 4. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| 单标的 performance(XIRR/TWR/CAGR full+range)—— S1/S2/S3 | 双写扩展 sell/dividend/split(独立 spec) |
| 组合 performance(portfolioXIRR/TWR/CAGR)—— S4 | price+snapshot 回填(独立 spec) |
| cache 透明性 + split-adjusted 不变式 | goal 集成 + 多币种折算(独立 spec) |
| `setupPerformanceHarness` fixture helper | 真实 gRPC server + grpcurl(从未脚本化) |
| 新文件 `holding_performance_integration_test.go` | benchmark/性能测(另一维度) |

## 5. 架构

| 层 | 组件 | 说明 |
|---|---|---|
| 入口(单标的) | `Service.GetHoldingPerformance(ctx, holdingID, range, base)` | 必填 `priceHistoryRepo`(nil 则 error) |
| 入口(组合) | `Service.GetPortfolioPerformance(ctx, tenantID, accountID, range, withBenchmark, base)` | 必填 `snapshotRepo`(nil 则 error) |
| harness(新) | `setupPerformanceHarness(t)` | 扩展 `setupHoldingDoubleWriteTestDB`:共享 in-memory sqlite + wire 真 ent repo |
| wire | security/holding/trade/priceHistory/snapshot/rate repo | 全 ent-backed;`application.NewService(...)` 或 struct literal(照 domain 单测) |
| fixture | pre-fill ent 表 | securities / holdings / holding_transactions / security_price_history / holding_snapshots / currency_rate_history |
| 文件 | `yucai/server/tests/holding_performance_integration_test.go` | 新增,`package tests` |

## 6. 核心改动

### 6.1 `setupPerformanceHarness`(fixture helper)

镜像 `setupHoldingDoubleWriteTestDB`(共享 in-memory sqlite + 多 ent schema),扩展 wire performance 必需 repo:

```go
func setupPerformanceHarness(t *testing.T) (svc *application.Service, tenantID, accountID uuid.UUID) {
    // 共享 sqlite + migrate holding schema(含 price_history/snapshot/lots 表)
    // wire 真 ent repo:security/holding/trade/priceHistory/snapshot/rate
    // svc = application.NewService(...) 或 &Service{...}(照 domain 单测)
    // 返回 svc + 预置 tenant/account
}
```

pre-fill helper(按场景调用):`seedSecurity` / `seedPriceHistory` / `seedTrade` / `seedSnapshot` / `seedRate`。

### 6.2 场景(时序 fixture + 断言)

**S1 单标的 CNY 基线**(精确绝对值):
- buy 100@¥100 on 2020-01-01(¥10000)→ 当前价 ¥130,固定评估日 2021-01-01(365 天)
- 无 dividend / sell / split
- 期望:**XIRR = CAGR = TWR = 0.30**(单笔、无现金流中断、整年 → 三者重合)
- 断言:`|got - 0.30| ≤ 1e-6`(full);range 同法

**S2 + dividend**(精确关系 + Excel 绝对值):
- S1 + dividend ¥500 @ 2020-07-01(现金流切点)
- 期望:TWR ≈ S1 TWR(0.30,dividend 切点数学中性 —— memory split-adjusted 教训:BV_before==BV_after 链 telescoping);XIRR > 0.30(dividend 真实现金流增益)
- 断言:`|S2.TWR - S1.TWR| ≤ 1e-6` + `S2.XIRR > 0.30`;XIRR 绝对值实现时 Excel `=XIRR([-10000,500,13000],[2020-01-01,2020-07-01,2021-01-01])` 填入

**S3 + split**(精确关系):
- S2 + 2:1 split @ 2020-10-01
- 期望:split 前后 TWR/XIRR 不变(市值中性,split 日不作切点;split 非现金流)
- 断言:`|S3.TWR - S2.TWR| ≤ 1e-6` + `|S3.XIRR - S2.XIRR| ≤ 1e-6`

**S4 组合级**(补零覆盖):
- 多 holding(account 维度)+ 按月 snapshot 时序 + rate history
- 期望:`portfolioXIRR` / `portfolioTWR` / `portfolioCAGR` 非 nil + 精确值(Excel + memory 既有 0.373362535 等)
- 断言:非 nil + `|got - want| ≤ 1e-6`;cache 透明(portfolioTWR 含 mvCache,调两次结果 byte-identical)

### 6.3 断言 helper

```go
func approxFloat(t *testing.T, got *float64, want float64, msg string) {
    t.Helper()
    if got == nil { t.Fatalf("%s: nil, want %.9f", msg, want) }
    if math.Abs(*got - want) > 1e-6 {
        t.Errorf("%s: got %.9f, want %.9f", msg, *got, want)
    }
}
```

## 7. 数据流

```
pre-fill ent(security / trade / price_history / snapshot / rate)
  → svc.GetHoldingPerformance / GetPortfolioPerformance(真 ent repo 读取)
  → 计算链(holdingXIRR / portfolioTWR / portfolioCAGR … 含 mvCache)
  → 断言 |got - want| ≤ 1e-6(绝对值 or 关系)+ 不变式(cache byte-identical / split 中性)
```

## 8. 测试

| 场景 | 覆盖 | 断言 |
|---|---|---|
| S1 单标的基线 | XIRR/CAGR/TWR full+range 基线 | 绝对值 0.30 ±1e-6 |
| S2 + dividend | TWR 子区间 + XIRR 现金流 | `|S2.TWR-S1.TWR|≤1e-6` + `S2.XIRR>0.30` + Excel 绝对值 |
| S3 + split | split-adjusted | TWR/XIRR 与 S2 byte-identical ±1e-6 |
| S4 组合 | portfolioXIRR/TWR/CAGR(补零覆盖) | 非 nil + Excel/memory 绝对值 + cache 透明 |

回归:`go test ./tests/ -run TestHoldingPerformance` + 全量 `go test ./...`(仅含 Service `now` 注入的机械改动,production `NewService` 默认 `time.Now` 行为不变 → 零回归风险)。

## 9. 风险

1. **手算成本**:S2/S4 的 GIPS/Excel 手推重 —— S1/S3 用简单可手算 + 关系断言;S4 组合需 Excel 协验(请你用 Excel `=XIRR()` 验一组,或我手推简单组合)。
2. **snapshot 时序 fixture**:S4 组合需按月 pre-fill holding_snapshots —— 主要搭建工作量;复用 `snapshotRepo.Save`。
3. **`time.Now()` → `now` 注入(已决策,最小生产改动)**:年化用 `time.Since(earliest/rangeStart)`,XIRR/CAGR 与评估日强相关 —— S1 期望 0.30 的前提是评估日 = 2021-01-01(365 天);Service 内部 `time.Now()` 是真实今天(2026)→ 不注入则 XIRR/CAGR ≠ 0.30。**决策**:Service 加 `now func() time.Time` 字段,`NewService` 默认 `time.Now`(production 行为不变),所有内部 `time.Now()` call site 改 `s.now()`;test struct literal 注入固定评估日。机械改动,不动计算逻辑。
4. **rate history**:S1–S3 单币 CNY → `rateRepo` 可 nil(`rateForCode` 返 1.0 graceful);S4 若多币种 → pre-fill `currency_rate_history`。
5. **NewService 签名**:若 production `NewService` 不暴露所有 performance repo 注入点,test 用 struct literal `&Service{...}`(照 domain 单测模式)绕过。

## 10. 参考

- 既有 integration test:[holding_doublewrite_integration_test.go](../../yucai/server/tests/holding_doublewrite_integration_test.go)(harness 范式)
- 入口:[service.go `GetHoldingPerformance:955` / `GetPortfolioPerformance:646`](../../yucai/server/internal/holding/application/service.go)
- memory:`holding-asset-management-todo`(XIRR/TWR/CAGR 手算验证记录)
- 后续独立 spec:双写扩展 / price+snapshot 回填 / goal+多币种
