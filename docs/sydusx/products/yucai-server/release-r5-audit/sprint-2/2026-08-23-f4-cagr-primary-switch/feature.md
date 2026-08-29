# Feature — F4 CAGR→XIRR 主指标切换(R5 sprint-2 feature H)

> audit 06 决策 1。依赖 G(✅ done 2026-08-29,XIRR 数值已稳)。sprint-2 收官 feature。
> 源 ticket [.scratch/yucai-audit/issues/06](../../../../../../../.scratch/yucai-audit/issues/06-financial-calculation-correctness.md)。

## Description

PortfolioPerformance 的 wire 契约补主指标语义:`ReturnMetric`/`CagrScope` 两个 enum + `primary_return_metric`/`cagr_scope` 两个 optional 字段(server 恒填 XIRR / CURRENT_HOLDINGS_COST_TO_MV 常量),proto 注释口径修正(XIRR 主指标;CAGR 辅助——仅当前持仓成本→市值、忽略已实现盈亏)。向后兼容纯新增;client 消费(重命名/tooltip/头部指标切换)defer 至 client 线,契约变更在 yucai-api 记档。仅 server pb.go regen。

## Stories

1. proto:两 enum + 两 optional 字段 + 注释口径修正
2. server pb.go regen
3. dto.go + GetPortfolioPerformance 恒填两字段
4. service/handler 测试 + contracts/yucai-api 记档

## title

F4 CAGR→XIRR 主指标切换(enum 语义进 wire,client 消费 defer)

## keywords

cagr, xirr, primary-metric, return-metric, cagr-scope, proto, contract, 06, F4
