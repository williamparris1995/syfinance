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

## Review 修复轮(2026-08-22,首轮 reject:1 BLOCKER + 4 HIGH)

- **B1**:ReceivablesSummary 整面补齐——repo 双源化 + guest 聚合(核心金额字段镜像 server;trend 字段=现值,无历史 scheduler 记 accepted)。
- **H2**:debt create 摊销引擎照抄(debt/domain/service.go 三公式:等额本息/等额本金/一次性;TermInMonths/addMonths clamp 同)——schedule 随 create 同事务生成,还款链路活了。
- **H3**:updateLotSplit 修复活 bug(remaining 独立×ratio,server lot.go 语义)+测试钉(40×2=80 非 200)。
- **H4**:FIFO/split/余量改按 holdingId 取 lot(server HoldingIDEQ)——同证券跨账户不再互吃。
- **H5**:四 repo guard 补 on Failure 透传(此前正则没匹配上单行形态,手工补)。
- MED:goal unlinked 读存储值(scheduler 跳过语义)/updateGoal 不碰 isCompleted/Investment 用现价共享 helper(marketValueOf)/networth 去 liability 余额双计+口径注释改 accepted 差异/还款·borrowedOut create 补账户校验/搜索改前缀。
- 新测试 +4(等额本息 oracle 12 期/lump sum/borrowedOut create 复式/split 防复活);networth 测试更新新口径。
- 修复后:全套 +1060 -4(=基线,零新增);analyze 366 < main 398。
- **deferred(记档)**:FIFO 余量不足静默少算(server 报错)→F;goal Investment 口径依赖 updateSecurityPrice 手工价(无行情)——与持仓页一致 ✓;receivables trend 字段无历史;networth 折算/陈旧标注(NetWorthView 无 stale 字段,归 F UX)。

## Review + Test(2026-08-22,pass — 三轮)

- 首轮 reject(B1 summary 整面+H2 摊销+H3 split 复活+H4 FIFO 跨户+H5 guard)→ 修复 → 二轮 reject(**修复轮手改 DI 误删 GoalLocalDataSource 注册**+isCompleted 未实修)→ 二轮修复(根因:函数类型构造参数令生成器拒产工厂,改注入 HoldingLocalDataSource 让生成器接管)→ 三审 **pass**(冷重跑逐字节一致证据)。
- Test 裁决:**pass** — 全套 +1060 -4(=基线 4,零新增);analyze 366 < main 398;requirement coverage:FR-1 FIFO/复式/校验 oracle/FR-2 降级/FR-3 max 口径/FR-4 三源+摊销 oracle/FR-5 summary 聚合+还款复式+摊销三公式/FR-6 networth 新口径/FR-7 零改动+guard/NFR 实测。
- **教训记录(→harness 候选)**:①生成物(injection.config)手改两次事故(D 的 Uuid/E 的 Goal 删块)——规则应 PROMOTE 为"local ds 类必须让生成器注册,禁手写 DI 块";②函数类型构造参数是生成器盲区,避免。
