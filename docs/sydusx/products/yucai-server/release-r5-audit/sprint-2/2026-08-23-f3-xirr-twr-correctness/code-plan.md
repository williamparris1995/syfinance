# Code Plan — F3 xirr-twr-correctness

> 消费 [spec.md](./spec.md) + [design.md](./design.md)。inline TDD(模块内聚,零跨模块接口)。
> 每任务:RED → GREEN → 全量单测绿 → 勾选。工作目录 `yucai/server/`。

- [x] **T1 `domain/brent.go` + brent_test.go** — Brent(1973) 移植(brentRoot,scipy brentq 语义:xtol=2e-12/rtol=4·eps/逆二次+secant+bisection 回退)。测试:线性/二次/三次已知根对拍、bracket 收缩、容差收敛判据、超迭代 error。接口:`brentRoot(f, lo, hi, fa, fb, xtol, rtol) (float64, error)`
- [x] **T2 `domain/xirr.go` 求解段重写 + xirr_test 扩展** — normalize(除 max|amount|)+ bracket 几何扩展(lo=-0.999999,hi 0.1→1→×2,ceiling 1e16,maxExpand 57)+ brentRoot;签名不变。测试:1e8 收敛(F3)、1 天+10% 极端解 ≈1.28e15(F4,闭式 oracle)、包络外 ErrNoSolution、归一化等价性(同根 1e-9 相对容差)、既有 sentinel(<2 笔/全同号)、2 笔闭式根 + 多笔 NPV 残差断言
- [x] **T3 `domain/twr.go` 拆函数 + twr_test** — `CumulativeTWR(subPeriods, finalValue, lastAfterCF)`(零端值 ErrZeroValue)+ `AnnualizeTWR(cumulative, totalDays)`(days<1 返累计;cumulative<-1 → ErrInvalidCumulative);旧 TWR() 移除(唯一调用方改用新函数,见 T4)。测试:手算链乘 oracle、零端点、<-1 sentinel、days<1
- [x] **T4 `application/service.go` computeTWR 分段重写 + 集成测试** — mvCache 扩展返回 (mv, qty, ok);三态语义(中间清仓跳段重启子链/终态纯清仓链止于 lastAfterCF/qty>0&MV=0 坏价 sentinel nil+slog);逐段 CumulativeTWR 链乘 → AnnualizeTWR;totalDays<0 降级。集成测试:清仓重建 e2e(手算分段 oracle)、大额 1e8 e2e、当日清仓重建/末日清仓边界
- [x] **T5 `application/amount.go` + 4 处接线 + 一致性测试** — `TradeAmountCents(priceCents, quantity)`(math.Round);handler :104/:140 与 service :150/:244 改调;测试:非整数量 round 不截断、handler/service 两侧一致
- [x] **T6 `RecordSplit` 守卫 + 测试** — 入口 ratio<=0 → InvalidArgument 语义 error,先于 repo 写。测试:ratio=0/-1 拒绝且 holdings/lots 零变更
- [x] **T7 `debt/domain/service.go` equalPrincipal 重写 + 测试** — float 月供本金+每月 roundToInt64+末月余差;interest 按 float remaining。测试:本金总和守恒、interest 序列手算 oracle、等额本息回归不变
- [x] **T8 oracle 汇总套件(FR-7 收口)** — Excel fixture 3-5 组(actual/365 口径,来源注释:闭式/手算/research 附录 B)+ research 附录 B case + NPV(r)=0 残差;行为变更断言更新记录

依赖:T1→T2→T3→T4 串行;T5/T6/T7 独立;T8 最后收口。收尾:`go build ./...` + `go test ./...` 全绿 → `sydusx-code-review` → commit。
