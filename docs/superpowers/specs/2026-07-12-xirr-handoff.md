# XIRR/TWR 收益修正 · 任务交接 Brief

- 日期:2026-07-12
- 分支:`holding-asset-management`
- 状态:**待执行**(换新会话 brainstorm → spec → plan → 实现)
- 优先级:**P0 基础正确性**(deep-research 调研结论,应优先于新增风险指标)

## 背景

御财 holding 模块**收益计算引擎有基础正确性缺陷**:现用 `totalPct = total / costBasis * 100` + 线性年化(`service.go:668` / `:907-931`,注释自标 "not CAGR")。

**问题**:组合有资金进出时(buy = contribution 贡献 / sell = withdrawal 撤资),简单收益 `(Ending-Beginning)/Beginning` **错误** —— 须用 **XIRR**(资金加权,内部收益率)或 **TWR**(时间加权收益,CFA Institute GIPS 标准:2010 起要求每次外部现金流日重估,强制 TWR)。

御财 holding 是交易驱动(BuyHolding/SellHolding/RecordDividend/RecordSplit + FIFO lots + 每日 snapshot),buy/sell 即外部现金流,满足"有现金流"前提。

## 调研依据(deep-research,2026-07-12 本会话)

- **agnifolio**(逐字):"Simple return calculations break when you add/remove money: Wrong: (Ending-Beginning)÷Beginning; Right: XIRR or time-weighted return"
- CFA Institute GIPS:2010 起要求每次外部现金流日重估,强制 TWR
- 行业:Empower 缺 IRR/MWR;Capitally 风险指标在 roadmap。XIRR/TWR 是基础正确性,优先于风险指标(Sharpe 等)。

## 现状(server)

- `server/internal/holding/application/service.go`:收益计算(`totalPct`/`annualizedPct`)
  - `:668` `totalPct = total / costBasis * 100`(简单收益)
  - `:907-931` 线性年化(`totalReturn/years×100`,注释 "not CAGR")
- 数据基础(已实现,C/holding-snapshot):
  - **FIFO lot**(`ConsumeLotsFIFO`,buy 建 lot / sell 消费)
  - **snapshot 时序表**(`holding_snapshot` 每日,组合 Σ × rate_history → CNY 日/月/年)
  - **price_history** + **rate_history**(折算)
  - 这些为 XIRR/TWR 提供现金流时序 + 每日估值数据

## 任务

修正 holding 收益引擎:**XIRR**(资金加权,反映用户实际投入/撤资的回报)或 **TWR**(时间加权,衡量投资决策本身,剔除现金流时点影响)。

**选哪个**(brainstorm 决策):
- **XIRR**:个人理财更直观(我投入的钱回报多少);考虑现金流时点
- **TWR**:行业基准(GIPS),衡量投资管理能力,剔除现金流时点
- 御财是个人理财(非机构),**XIRR 可能更贴合**(用户视角:我的钱回报多少)。但 TWR 是行业标准。brainstorm 时定(可能两者都算,展示不同维度)。

## 约束(Mandatory,CLAUDE.md)

- **server DDD 四层**:domain → application → infrastructure → presentation
- **ent schema**(非 SQL migration;新表 `holding_cash_flow` 或复用 holding_transaction)
- **wire 手改**(`wire_gen.go`,工具链坏;镜像现有 provider 声明顺序,memory `yucai-wire-handmaintained`)
- **英文结构化日志**(slog,无 CJK)
- **跨模块 port**(若 holding 暴露收益给 goal/net-worth,走 port 接口)
- 测试:Go 单测 + 集成测(enttest SQLite)+ e2e

## 执行建议(新会话)

1. 读本 handoff + memory(`holding-asset-management-todo` holding 系统 + `ui-align-visual-companion-workflow` 调研结论)
2. 读 server 现状:`server/internal/holding/application/service.go`(收益计算)+ C 持仓快照代码(spec `2026-06-30-holding-snapshot-design.md`)
3. `/superpowers:brainstorming` 与用户探索 **XIRR vs TWR**(选哪个 / 两者)
4. spec(`docs/superpowers/specs/YYYY-MM-DD-xirr-design.md`)+ plan + subagent-driven 实现
5. 验证:server go test + 真实数据 XIRR 计算(对比手动 Excel XIRR)

## 参考

- 调研结论:本会话 deep-research(holding 功能完整性,选 XIRR P0),memory `ui-align-visual-companion-workflow` / progress.md ledger
- 现状 spec:`docs/superpowers/specs/2026-06-30-holding-snapshot-design.md`(C snapshot,FIFO lot)
- memory:`holding-asset-management-todo`(holding 系统)、`yucai-wire-handmaintained`(wire 手改)、`yucai-dev-env`(dev 环境)
- 来源:[agnifolio essential metrics](https://agnifolio.com/blog/portfolio-performance-analytics-essential-metrics)
