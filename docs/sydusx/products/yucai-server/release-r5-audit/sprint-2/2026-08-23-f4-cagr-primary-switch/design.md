# Design — F4 cagr-primary-switch(R5 sprint-2 feature H)

> 消费 [spec.md](./spec.md)(4ec3b152;grill β 定案)。改动面小,薄 design。

## Context

`yucai/proto/holding/v1/holding.proto` `PortfolioPerformanceResponse`(字段 1-14 已用,新增用 15/16);server regen 走 `make proto`(buf generate,R6-G 验证可用);client `gen-dart` 不跑。service 装配点 `GetPortfolioPerformance`(`service.go:776`)+ dto.go `PortfolioPerformance`。

## Decisions

- **ADR-1 enum 进 wire(β)**:spec grill #1 定案——机器可读主指标语义是"DTO 层就位"的诚实落地;α(纯注释)否决。字段:`ReturnMetric`(RETURN_METRIC_UNSPECIFIED=0 / RETURN_METRIC_XIRR=1)+ `CagrScope`(CAGR_SCOPE_UNSPECIFIED=0 / CAGR_SCOPE_CURRENT_HOLDINGS_COST_TO_MV=1);proto 命名惯例带类型前缀防 C++ 作用域冲突。
- **ADR-2 恒填常量**:`primary_return_metric=XIRR`、`cagr_scope=CURRENT_HOLDINGS_COST_TO_MV` 无条件填充——语义是常量,不引入 nil 分支(nil 只属于旧 server 的历史响应)。
- **ADR-3 仅 server regen**:client 零改动、无消费方;纯新增 optional 对旧 pb 无影响。契约记档于 `portfolio/contracts/yucai-api`(README 变更记录),消费 defer client 线。

## HLD

| 单元 | 变更 |
|---|---|
| `yucai/proto/holding/v1/holding.proto` | 2 enum + `optional` 字段 15/16 + 注释口径修正 |
| `internal/proto/holding/v1/holding.pb.go` | `make proto` regen(机械) |
| `internal/holding/application/dto.go` + `service.go` | PortfolioPerformance 增 2 字段 + 恒填 |
| `internal/holding/adapter/driving/grpc/holding_handler.go` | DTO→proto 映射补 2 字段(performanceToProto 处) |
| `portfolio/contracts/yucai-api/README.md` | 变更记档 |
| 测试 | service 断言填充 + handler round-trip |

## LLD

- proto:`enum ReturnMetric { RETURN_METRIC_UNSPECIFIED = 0; RETURN_METRIC_XIRR = 1; }`(顶层,复用空间留 Holding);`enum CagrScope { CAGR_SCOPE_UNSPECIFIED = 0; CAGR_SCOPE_CURRENT_HOLDINGS_COST_TO_MV = 1; }`;`optional ReturnMetric primary_return_metric = 15;` / `optional CagrScope cagr_scope = 16;`,注释:XIRR 主指标(money-weighted,全现金流);CAGR 辅助(仅当前持仓成本→市值,忽略已实现盈亏)。
- application 侧字段类型:用 pb enum 还是本地 enum?**pb enum 直引**(adapter 已依赖 pb;application 依赖 internal/proto 包在该模块现状如何——若 application 不 import pb,则用本地定义的枚举值+handler 映射。**实施时以 grep application 对 pb 的既有依赖为准**,遵循现状)。

## Risks

| 风险 | 缓解 |
|---|---|
| regen 产生大量无关 diff | buf 版本锁定,只应新增两字段相关代码;diff 审查 |
| application 层依赖方向 | LLD 决策树:照现状(pb 直引或本地枚举映射) |
| 字段号冲突 | 消息现用至 14,15/16 无冲突(已核) |

## Migration

无。契约向后兼容记档(contracts/yucai-api README);旧 client 无感。

## Open Questions

无。
