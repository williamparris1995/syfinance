# Code Plan — F4 cagr-primary-switch

> 薄 feature:proto 契约 + 常量填充。inline TDD。

- [x] **T1 application 层枚举+填充** — RED:service 测试断言 `PrimaryReturnMetric`/`CagrScope` 字段;GREEN:dto.go 本地枚举(`ReturnMetricXIRR`/`CagrScopeCurrentHoldingsCostToMV`)+ GetPortfolioPerformance 恒填
- [x] **T2 proto + regen + handler 映射** — proto 2 enum + optional 15/16 + 注释;`make proto`(仅 server);handler 响应映射(值序与 pb 对齐);handler 测试 round-trip 断言
- [x] **T3 契约记档** — contracts/yucai-api README 变更记录(向后兼容新增,client 消费 defer)
- [ ] **收尾** — `go build ./...` + `go test ./...` 全绿 → code-review → commit
