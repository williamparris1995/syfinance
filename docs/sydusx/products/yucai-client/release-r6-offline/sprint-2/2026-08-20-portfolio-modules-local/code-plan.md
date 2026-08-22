# Code Plan — feature E 资产类模块本地化

> 消费 spec+design(均 confirmed)。inline 模式(范式第 3 轮)。

## Tasks
- [x] T1 budget local ds:嵌套 items 子表/整包替换/读时 actuals(max(Σdebit,Σcredit) 月窗口,server budget/domain/repository.go:53 照抄)
- [x] T2 goal local ds:links 联结双向聚合/patch+显式乐观锁/读时三源(Investment=Σ持仓·avgCost 兜底/Savings=Σ余额/DebtPayoff=Σ schedule paid)/history 空
- [x] T3 debt local ds:schedule 子表/显式乐观锁/还款复式(borrowedIn:credit from+debit debt;borrowedOut 反向)+schedule 同事务/borrowedOut create 双写/nextPayment 读时推导
- [x] T4 holding local ds:buy/sell 单 drift 事务四件套(持仓 upsert/lot/FIFO/复式现金联动·fee 不进现金腿)/四校验镜像/split 按 ratio 调 lot+成本/dividend 不复式(server 同款 accepted)/securities CRUD+本地搜索/展示字段读时合成/行情·收益显式降级/listInvestmentGoals 本地分支
- [x] T5 networth:NetWorthLocalDataSource 三源(资产余额+未实现利得层/liability 余额+borrowedIn remaining)/NetWorthDataSource 双源化
- [x] T6 路由:四 repo 平衡括号脚本 37 处 + guard Failure 透传 + @LazySingleton 全注册 + repo 测试构造器更新
- [x] T7 测试:oracle 8 例(buy fee 资本化+现金腿/FIFO 两 lot+realized/校验回滚/budget max 口径含跨月/goal 三源两型/还款复式/networth/路由)全绿;全套 +1056 -4(=基线 4,零新增);analyze 360 < main 398

## 执行记录(2026-08-22)
- FIFO realized 期望值自纠(140000+20000−100=159900,初稿算错非实现错);debt create 无摊销引擎(排期表 server 侧生成)——测试手工插行,ledger 记 accepted 边界。
- dart fix 范围内清理(范围外 62 文件已回滚)。

## Accepted 边界(ledger)
- guest create debt 不生成 schedule(摊销引擎 defer;还款测试手工造行)——**feature F 引用完整性时补本地摊销或记差异**。
- dividend 无现金腿(server 同款);progress history 空;行情收益降级。
- networth 未实现利得层口径(资产余额含成本基础+仅加 gain 层)——与 server HoldingMarketValueSource 的精确对拍归 F/e2e 复核。
