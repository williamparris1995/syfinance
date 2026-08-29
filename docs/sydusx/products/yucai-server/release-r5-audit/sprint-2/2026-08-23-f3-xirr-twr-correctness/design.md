# Design — F3 xirr-twr-correctness(R5 sprint-2 feature G)

> 消费 [spec.md](./spec.md)(d985b21a,grill 5 决策已收敛 + TWR 终止语义裁决 2026-08-29)。
> 架构继承 [architecture](../../../../architecture.md)/[tech-stack](../../../../tech-stack.md) 不变——纯域内改动,无新 infra(不触发 architect)。
> branch `feature/f3-xirr-twr-correctness`,worktree `.claude/worktrees/f3-xirr-twr-correctness`。

## Context

`internal/holding` 收益引擎(XIRR 求解 `domain/xirr.go` 113 行 / TWR 链乘 `domain/twr.go` 57 行 / service 组装 `application/service.go` computeTWR 等约 600 行)+ `internal/debt` 等额本金摊销(`domain/service.go` equalPrincipal)。**硬约束:DTO/proto 零改动,debt 零 schema**(spec NFR);日志沿用 `slog` 结构化英文(`service.go:548` 先例)。

## Goals / NonGoals

- **Goals**:spec FR-1..FR-7(归一化 / Brent-only / TWR 终止-分段-sentinel / 4 处 round / 等额本金均摊 / split 守卫 / oracle 测试)。
- **NonGoals**:主指标切换(H)/ client UI / 存量 schedule / F13 / 多根语义(spec Scope boundary 表)。

## Decisions(ADRs)

### ADR-1 Brent 自包含移植,domain/brent.go,零新依赖
**决策**:按 Brent(1973)自写 ~100 行(scipy brentq 语义:逆二次插值 + secant + bisection 回退;`xtol=2e-12`,`rtol=4·eps≈8.88e-16`,收敛判据 `|x−x₀| ≤ xtol + rtol·|x₀|`),unexported,仅 domain 包内使用。
**备选**:(a) 留 Newton+阻尼(research 1.3——被 grill #2 否:行业默认 bracket-first,包络内 Newton 可解集 ⊆ Brent);(b) 外部依赖 andreyzworkaccount/xirr(否:多级回退结构与 Brent-only 矛盾,新增依赖,且 D2 的 Dart 镜像要求算法自持可移植)。
**Grill**:2026-08-29 用户"对齐"(scipy/MATLAB/NR)。

### ADR-2 归一化在 XIRR 入口
排序后全部现金流除以 `max|amount|`(数学等价:`NPV(r; α·cf)=α·NPV(r; cf)`);`scale=0` → ErrNoSolution。归一化等价性单测护体(同根断言)。附带解 F11。

### ADR-3 bracket 几何扩展 + 包络 (-0.999999, 1e16)
lo 固定 `-0.999999`;hi 自 `0.1` 起(先跨到 1)×2 倍增直至 NPV(lo)·NPV(hi) ≤ 0;`maxExpand≈57`(0.1×2⁵⁷≈1.4e16)封顶;超包络 → ErrNoSolution。反号后交 Brent。
**Grill**:#5(research 2.3 的 ceiling=1e8 与其附录 B 用例内部矛盾,1 天+10% 真根 ≈1.28e15 → 上界 1e16)。

### ADR-4 TWR 三态语义:分段链乘 / 终止 / sentinel(GIPS)
- **中间清仓段**(qty=0 区间):service 切段,逐段累计链乘,重建日重启子链(ticket 决策 3;备选"分段显示/N-A"——research 3.3 标注更稳,但 ticket 已拍单数字链乘,不重开)。
- **当前纯清仓**(全 qty=0 且 finalValue=0):链**终止**于 lastAfterCF,年化按实际存续天数——不乘 0(GIPS discontinued;被拒"×0 市值诚实派":GIPS 禁止零段进链,-100% 是精确金融语义不可滥用)。
- **qty>0 但 MV=0**(退市/坏价格):sentinel 可判别降级(nil + `slog.Warn` 英文日志 `zero-market-value-with-open-quantity`)——数据错误 ≠ 收益(GIPS 数据校验原则)。
- domain 零端值 ErrZeroValue 保留可判别;`cumulative<-1` 年化前返 ErrInvalidCumulative(F10)。
**Grill**:2026-08-29 用户"同意"(行业口径收束)。

### ADR-5 AmountCents 规则单点:application helper 双调用
`application.TradeAmountCents(priceCents int64, quantity float64) int64`(`int64(math.Round(float64(priceCents)*quantity))`),handler(:104/:140,余额校验+现金 double-write)与 service(:150/:244,持仓交易记录)都调用;service **不信任** adapter 传入金额,自行调 helper 重算,测试断言两侧一致。
**备选**:(a) request 增字段传值(信任 adapter 的金额——边界 smell);(b) 两层各写 round(规则漂移温床,正是 F5 成因)。

### ADR-6 split 守卫在 service 入口
`RecordSplit` 入口 `ratio<=0` → domain error → mapError 映射 InvalidArgument,**先于任何 repo 写**(fail-closed)。domain `ApplySplit` 签名不动(单一调用方,invariant 由 service 保证——F 的 service-guard 先例)。

### ADR-7 等额本金 float/round 方案
`monthlyPrincipalF = totalF/months`(float);每月 `principalCents = roundToInt64(monthlyPrincipalF)`,末月 `roundToInt64(remaining)`;`interestCents = roundToInt64(remaining × monthlyRate)`,remaining 按实际 principalCents 扣减。镜像 equalPrincipalInterest 既有模式;存量 schedule 不动。

### ADR-8 oracle 测试架构:闭式解 + NPV 残差 + fixture
- 两笔现金流:闭式精确根 `(−A₁/A₂)^(365/days) − 1` 测试内独立计算(与求解器零共享)→ 真独立 oracle;
- 多笔:`|NPV(r_solution)| ≤ tol×scale` 残差断言;
- Excel 对拍:actual/365 口径已一致,3-5 组 fixture(值来源注释:闭式/手算/research 附录 B;冲突时以闭式解为准);
- e2e:真 trades 灌入 → service 层取数 → 值断言(防 mock 掩盖)。

## HLD(单元 + 接口 + 依赖)

| 单元 | 变更 | 依赖 |
|---|---|---|
| `holding/domain/brent.go` **新增** | `brentRoot(f func(float64) float64, lo, hi, fa, fb, xtol, rtol float64) (float64, error)` | 无(纯函数) |
| `holding/domain/xirr.go` 重写求解段 | `XIRR(cashflows)` **签名不变**;内部:validate → sort → normalize(ADR-2)→ bracket 扩展(ADR-3)→ brentRoot | brent.go |
| `holding/domain/twr.go` 拆函数 | `CumulativeTWR(subPeriods, finalValue, lastAfterCF) (float64, error)`(纯链乘,零端值 ErrZeroValue)+ `AnnualizeTWR(cumulative, totalDays) (float64, error)`(days<1 返累计;cumulative<-1 → ErrInvalidCumulative);旧 `TWR()` 改为二者组合(唯一调用方 computeTWR 直接改用新函数) | 无 |
| `holding/application/service.go` | computeTWR 重写:分段(ADR-4)+ mvCache 扩展返回 qty;`RecordSplit` 守卫;Buy/Sell 改调 helper | domain |
| `holding/application/amount.go` **新增** | `TradeAmountCents`(ADR-5) | 无 |
| `holding/adapter/driving/grpc/holding_handler.go` | :104/:140 改调 `application.TradeAmountCents` | application |
| `debt/domain/service.go` | equalPrincipal 重写(ADR-7) | 无 |
| 测试 | brent_test / xirr_test 扩展 / twr_test / service 集成(e2e)/ debt_test / handler guard | — |

依赖方向:handler → application → domain(既有,不变);零跨模块新增。

## LLD(关键单元)

**brentRoot(Brent 1973 标准流程)**:初始 a,b 及 f(a),f(b)(已反号);迭代:若 |fa|<|fb| 交换;若 f(b) 与上一迭代 f(c) 不同号 → 逆二次插值候选,否则 secant 候选;候选超出 (a,b) 或步长收缩过慢 → bisection 中点;接受后收缩 bracket;收敛判据 `|x−x₀| ≤ xtol + rtol·|x₀|` 或 f≈0;超 maxiter → error。参数取 scipy brentq 缺省。

**XIRR 新流程**:① len<2 / 全同号 → 既有 sentinel error;② sort + years 预计算;③ normalize(除 max|amount|,scale=0 → ErrNoSolution);④ npv closure(归一后金额);⑤ hi 自 0.1:先跳到 1,再 ×2,每次验 `npv(lo)·npv(hi) ≤ 0` 即停;超 maxExpand 或 hi>1e16 → ErrNoSolution;⑥ brentRoot;⑦ 解回代校验(|npv(r)| ≤ tol)后返回。

**computeTWR 分段重写**:① effectiveDays 过滤(rangeStart 之后)不变;② 逐日 cachedMV(扩展返回 `(mv int64, qty float64, ok bool)`——内部 QtyAtDate 求和已有,仅暴露);③ 组装子区间时遇 `prevAfter==0`:qty==0 → 纯清仓,跳过零区间,**重建日(首个 mv>0 日)重启子链**;qty>0 → 坏价 sentinel,整体降级 nil+log 返回;④ 终态:finalValue==0 且当前全 qty==0 → 链止于 lastAfterCF(不乘 0 因子);qty>0 → sentinel 降级;⑤ 逐段 `CumulativeTWR` → `chainProduct *= (1+segCum)`;totalDays 累加各段实际天数;⑥ `AnnualizeTWR` 收尾。**totalDays<0(rangeStart 未来)→ 降级 nil**(research 3.3 问题 B,不新增用户可见语义)。

**equalPrincipal 新步骤**:见 ADR-7;`roundToInt64` 既有 helper 复用;首月利息基于全额 remaining(不变);月序 0..months-1,PaymentDate addMonths 不变。

**TradeAmountCents**:单行语义见 ADR-5;负数防御:quantity<=0 或 priceCents<0 由各入口既有校验负责,helper 不重复(单一职责)。

## Risks

| 风险 | 缓解 |
|---|---|
| Brent 移植错误 | brent_test(多项式/三角已知根对拍)+ oracle e2e |
| 分段边界 off-by-one(清仓日/重建日 begin/end 取舍) | 手算 oracle e2e(清仓重建样本)+ 边界 case 清单(当日清仓当日重建/末日清仓/首日清仓) |
| mvCache 签名扩展波及 | 唯一调用方 computeTWR,编译期收口 |
| 既有测试断言旧行为(bracket 上限/截断值) | 逐一更新并在 PR 记录(NFR 要求) |
| handler/service 金额漂移(double-write) | helper 单点 + 两侧一致性测试 |
| 归一化引入的浮点重排差异 | 归一化等价性单测(同根,容差 1e-9 相对) |

## Migration

零 schema、零 wire、零脚本。行为变更清单(F3/F4/F6 修复后原 nil 场景返回数值;F5/F7 数值微变)在 merge PR 描述逐条记录。存量 PaymentScheduleEntry 不触碰。

## Open Questions

无(spec grill 与设计 grill 已清空;执行期若 Excel fixture 值与闭式解冲突,以闭式解为准并注释来源——ADR-8 已定规则)。
