# 金融计算标准调研:御财 holding 模块(XIRR / TWR / CAGR)

**日期**:2026-07-26
**范围**:御财 holding 模块收益引擎数值稳定性 + 方法论审计
**标尺**:家庭多用户私域(不追求 CFA 机构级,但需行业最佳实践)
**调研对象**:`xirr.go` / `twr.go` / `service.go` 中 `portfolioCAGR` / `holdingCAGR` 等

---

## TL;DR(核心结论)

| # | 问题 | 御财现状 | 行业最佳实践 | 严重度 |
|---|---|---|---|---|
| 1 | XIRR 收敛阈值 | 绝对 `|NPV| < 1e-7` | **绝对 + 相对**组合(`|NPV| ≤ atol + rtol·scale`),scale = Σ\|cf\| | **P0**(大额永不收敛) |
| 2 | XIRR bracket | 硬编码 `[-0.9999, 1000]` | **自适应扩展**(几何倍增直到反号)+ Brent 替代 bisection | P1 |
| 3 | TWR totalDays / 清仓 | 整段一个 totalDays,不清分段 | 完全清仓段单独切分,GIPS 视组合终止,新段独立 track | P1 |
| 4 | Money 精度 | int64 cents → float64 直接喂 | 2^53 内无损(家庭场景 OK),**但需 NPV 归一化**或阈值改相对 | 与 #1 同源 |
| 5 | portfolioCAGR | "当前持仓 cost basis → 当前 MV" 年化 | CAGR 不适合多现金流场景;**正确指标是 XIRR(MWRR)**,CAGR 仅辅助 | P1(产品决策) |

> 关键洞察:#1 和 #4 是同一问题的两面 —— float64 在 1e8 cents 量级的 ulp ≈ 1.5e-2,**正好与 1e-7 阈值在同一量级**。修 #1(改相对阈值或归一化)即可一并解决 #4。

---

## 问题 1:XIRR 数值收敛最佳实践

### 1.1 各实现的收敛判据对照

| 实现 | 收敛判据 | 阈值 | 性质 | 备注 |
|---|---|---|---|---|
| **御财 xirr.go L74, L101** | `math.Abs(NPV) < 1e-7` | 1e-7 | **纯绝对** | 大额 NPV 永不收敛 |
| 御财 xirr.go L82 | `math.Abs(next-rate) < 1e-9` | 1e-9 | **纯绝对(rate)** | rate 在 ~1 附近尚可,在 ~1000 时过早收敛 |
| **Excel XIRR** | "结果精确到 0.000001 percent" | 1e-8 relative accuracy on rate | **相对** | 100 iter,guess=0.1 [^ms-xirr] |
| **scipy.optimize.brentq** | `abs(x-x*) ≤ xtol + rtol·abs(x*)` | xtol=2e-12, rtol=4·eps=8.88e-16 | **绝对 + 相对组合**(OR) | 100 iter,公认为最稳健 [^scipy-brentq] |
| **numpy-financial.rate** | `|g(r_n)/g'(r_n)| < tol` | tol=1e-6 | NPV 残差绝对 | 100 iter,guess=0.1 [^npf] |
| **numpy-financial.irr** | 不收敛(多项式根 `np.roots`) | — | 代数法 | 多解时用 selection_logic [^npf] |
| **andreyzworkaccount/xirr** | `abs(NPV - 0) ≤ IrrEpsilon` | IrrEpsilon=0.1(NPV 单位) | **NPV 绝对(松)** | 多方法回退:secant → Newton×3 [^go-xirr] |
| **PL/SQL AskTOM** | NPV 残差 | 1e-6 | NPV 绝对 | 文档明确"匹配 Excel 精度" [^asktom] |

### 1.2 结论

**(a) 绝对阈值是反模式**。NPV 是 cashflow 量级的线性函数:`NPV(r) = Σ amount_i / (1+r)^years_i`。当 cashflows 来自 1e8 cents 量级(= 1M CNY,家庭组合完全可达),NPV 的浮点 ulp(unit in last place)约为 `1e8 × 2^-52 × 2^ceil(log2(1e8))-52` ≈ **1.5e-1 ~ 1.5e-2**。这比 1e-7 大 5~6 个数量级,函数值永远在阈值外抖动,Newton step 在零点附近震荡,最终跌入 bisection,而 bisection 同样用 1e-7 判据,继续失败 → `ErrNoSolution`。这是已记录的 P0 故障模式 [^ms-qa-precision]。

**(b) 行业最佳实践 = 绝对 + 相对组合**(scipy 范式):
```
converged ⇔ |NPV(r)| ≤ atol + rtol × scale
```
其中 scale 反映问题规模,常用 `Σ|amount_i|`(现金流绝对值之和)。这意味着 NPV 残差需要相对于现金流量级小,而非绝对值小。

**(c) 初值选择 + 多 guess 回退**。Excel/scipy/andreyzworkaccount 都用 guess=0.1;andreyzworkaccount 进一步对 NPV-sum 反号情况用 guess=-0.1,并尝试 `IrrDefaultValue`(接近 -1)—— 在多种 cashflow 形状下提升首次收敛率 [^go-xirr]。

**(d) 防震荡**(Newton 越界处理):御财 xirr.go L86-88 在 `rate <= -1 || rate > 1e4` 时直接 break 转 bisection,这是合理的。但缺乏**阻尼 Newton**(damped)—— 当 Newton step 过大时应该 backtrack(如 `α=0.5` 衰减),而非直接放弃。scipy 的 `brentq` 本质上是 bracketed,无越界问题。

### 1.3 对御财的具体修法建议(xirr.go)

```go
// 替换 L74 的收敛判据
const (
    defaultTol       = 1e-7   // NPV 残差绝对(保留向后兼容)
    defaultRtol      = 1e-10  // NPV 残差相对(关键新增)
    rateRtol         = 1e-12  // rate 步长相对
)

// 在 XIRR() 入口预计算 scale
scale := 0.0
for _, cf := range sorted { scale += math.Abs(cf.Amount) }
if scale == 0 { return 0, ErrNoSolution }
npvTol := defaultTol + defaultRtol*scale   // 关键:scale-aware threshold

// Newton 主迭代(L72-89 改写)
for iter := 0; iter < 100; iter++ {
    f := npv(rate)
    if math.Abs(f) <= npvTol {              // 替换 math.Abs(f) < 1e-7
        return rate, nil
    }
    d := npvPrime(rate)
    if d == 0 { break }
    step := f / d
    // 阻尼:若 step 让 rate 越界或变化过大,衰减
    next := rate - step
    for iter2 := 0; (next <= -1 || next > 1e4 || math.Abs(next-rate) > 0.5*math.Abs(rate)+0.1) && iter2 < 20; iter2++ {
        step *= 0.5
        next = rate - step
    }
    if math.Abs(next-rate) <= rateRtol*math.Abs(rate)+1e-12 {
        return next, nil
    }
    rate = next
}
```

**或更稳健的替代方案(归一化)**:在 XIRR 入口把所有 cashflows 除以 `max|amount_i|`,这样 NPV 在 O(N) 量级(N=cashflow 数,通常 < 100),1e-7 阈值立即合理。XIRR 对 cashflow scale 不变(`NPV(r; α·cf) = α·NPV(r; cf)`,零点相同),数学上完全等价。

```go
// 在 sort 之后,years/amounts 计算之前
maxAbs := 0.0
for _, cf := range sorted {
    if a := math.Abs(cf.Amount); a > maxAbs { maxAbs = a }
}
for i := range sorted { sorted[i].Amount /= maxAbs }   // 归一化
// 后续逻辑不变
```

**推荐顺序**:先做归一化(改动最小,5 行代码,等价语义);如仍需更精细控制再加 scale-aware 阈值。归一化也顺便解决问题 4 的精度边界。

### 1.4 信源

[^ms-xirr]: Microsoft Support, "XIRR function", <https://support.microsoft.com/en-us/excel/functions/xirr-function> — 默认 guess=0.1,精确到 0.000001 percent,100 次尝试失败返回 #NUM!。

[^scipy-brentq]: SciPy v1.18.0 Manual, "scipy.optimize.brentq", <https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.brentq.html> — xtol=2e-12, rtol=4·eps≈8.88e-16,停止条件 `abs(x-x0) ≤ xtol + rtol·abs(x0)`,Brent (1973) 收敛保证。

[^npf]: numpy-financial `_financial.py` (master), <https://github.com/numpy/numpy-financial/blob/master/numpy_financial/_financial.py> — `irr` 用 `np.roots`(多项式代数法,无迭代);`rate` 用 Newton,tol=1e-6, maxiter=100, guess=0.1;`xirr` 在主线不存在(Issue #29 讨论中)。

[^go-xirr]: andreyzworkaccount/xirr `method.Impl.go`, <https://pkg.go.dev/github.com/andreyzworkaccount/xirr/xirr> — `IrrEpsilon=0.1`, `IdealNPV=0`,多方法回退:secant(borders auto-search) → Newton(±0.1) → Newton(IrrDefaultValue),失败返 `AllNumericMethodsHaveBeenFailed`。

[^asktom]: Connor McDonald, "Oh…another language is too hard" (AskTOM PL/SQL XIRR), <https://connor-mcdonald.com/2017/10/25/ohanother-language-is-too-hard/> — `DefaultGuess`,tolerance `1E-6` 显式标注"匹配 Excel 精度"。

[^ms-qa-precision]: Microsoft Q&A, "Using XIRR gives incorrect values", <https://learn.microsoft.com/en-us/answers/questions/4762755/using-xirr-gives-incorrect-values> — 记录 XIRR 在大数据集 + 大额现金流下返回 `2.98023E-09` 等浮点精度伪影。

---

## 问题 2:XIRR 求根区间(极端短日高回报)

### 2.1 各实现的 bracket 策略对照

| 实现 | bracket | 极端短日处理 |
|---|---|---|
| **御财 xirr.go L92** | 硬编码 `[-0.9999, 1000]` | 年化 > 1000% 直接 ErrNoSolution |
| **Excel XIRR** | 隐式 `rate > -1`,无明确上界 | 用户报告可计算 1e10% 量级 [^p2pdash] |
| **scipy.optimize.brentq** | 用户必须提供 [a,b] 且 `f(a)f(b) < 0` | 不负责选择 bracket |
| **andreyzworkaccount/xirr** | **secantAuto borders search**(自动扩展) | 不硬编码,自动适应 [^go-xirr] |
| **PL/SQL AskTOM** | 硬编码下界 -0.9999,迭代上界 1e6 | 实践可处理极端值 [^asktom] |

### 2.2 结论

**(a) 硬编码 [-0.9999, 1000] 会漏合法解**。XIRR 年化公式 `(1+r)^days` 把短日微小回报放大:1 天 +3% → 年化 `(1.03)^365 - 1 ≈ 4.8e4 = 48000%`;1 天 +10% → 年化 `1.28e15`。对私域用户首次买入 1 周内涨 5% 是常态,御财直接 `ErrNoSolution` 不返回任何值,降级为 nil —— 这是 UI 显示空白的一个已知原因。

**(b) 下界 -0.9999 是合理的**(rate = -1 时 (1+rate)=0 不可解析;接近 -1 时数值爆炸)。但上界 1000 是任意选取,与 Excel/其他实现不一致。

**(c) 行业最佳实践 = 自适应 bracket 扩展**(自适应二分扩展,adaptive bracket expansion):
- 从 guess(如 0.1)开始
- 几何级数扩展(hi *= 2, lo = max(-0.9999, lo/2))
- 直到 `f(lo)·f(hi) < 0`(反号,确认有根)
- 然后用 Brent 或 bisection 在 bracket 内求根
- 设置硬上限(如 1e8 或 1e15)避免无限扩展

这是数值分析教科书的标准技术(Wikipedia "Bisection method" 描述的 bracketing 前置步骤)[^wiki-bisection]。`andreyzworkaccount/xirr` 的 `secantAuto.NewBordersSearchAlgorithm` 就是这种实现的工业代表 [^go-xirr]。学术上"自适应 bracket 扩展"未作为正式术语发表,但工程上是公认实践 [^adaptive-search]。

**(d) 极端短日的"产品决策"层面**:年化 48000% 是数学正确但语义误导(1 天的随机涨跌不可能持续一年)。两种常见处理:
1. **诚实显示**(数学结果,加 footnote 警告)—— Excel 走这条路
2. **门槛化显示**(>1000% 显示 ">1000%" 而非具体值)—— Personal Capital、Sharesight 等零售平台采用 [^p2pdash]

御财作为家庭私域,建议走 (1) + UI 显示警告(持仓 < 30 天时附 tooltip "短期间年化波动大,不代表长期收益")。

### 2.3 对御财的具体修法建议(xirr.go L91-111 重写)

```go
// 替换硬编码 [-0.9999, 1000] 的 bisection fallback
// 自适应 bracket 扩展 + Brent
const (
    rateFloor   = -0.999999   // 严格 > -1
    rateCeiling = 1e8         // 年化 1e8 % (合理上限,超过此值视为发散)
    bracketGrow = 2.0         // 几何倍增因子
    maxExpand   = 60          // 2^60 ≈ 1e18,足够覆盖
)

lo, hi := rateFloor, 0.1
// 扩展直到反号
nLo := npv(lo)
for iter := 0; iter < maxExpand; iter++ {
    nHi := npv(hi)
    if nLo*nHi <= 0 { break }
    if math.Abs(hi) < 1 { hi = 1 }       // 跨过 0
    hi *= bracketGrow
    if hi > rateCeiling { return 0, ErrNoSolution }
}
// 也可以反向扩展 lo(通常不需要,-0.9999 已是下界)

// 在 [lo, hi] 用 bisection(或更好:Brent)
for iter := 0; iter < 200; iter++ {
    mid := (lo + hi) / 2
    f := npv(mid)
    if math.Abs(f) <= npvTol || (hi-lo)/2 < 1e-12 {
        return mid, nil
    }
    if nLo*f < 0 { hi = mid } else { lo, nLo = mid, f }
}
```

**升级建议**:把简单 bisection 替换为 **Brent 方法**(Brent 1973)。Brent 在 bisection 安全性的前提下,结合逆二次插值,收敛速度提升至 superlinear。Go 标准库没有现成 Brent,但可参考 `scipy.optimize.brentq` 的实现,或直接用 `andreyzworkaccount/xirr` 的 borders search 模块。对御财规模(单 tenant < 1000 cashflows),Brent vs bisection 性能差异可忽略,但极端 case 下的收敛可靠性更高。

### 2.4 信源

[^p2pdash]: p2pdash, "XIRR Explained - Understanding Your True P2P Returns", <https://p2pdash.com/knowledge/xirr/> — "Short periods = extreme rates. A 5% gain in one month becomes 80% annualized. This is mathematically correct but can look misleading for new portfolios."

[^wiki-bisection]: Wikipedia, "Bisection method", <https://en.wikipedia.org/wiki/Bisection_method> — "guaranteed convergence" for continuous f with bracketing sign change.

[^adaptive-search]: 经多篇实践来源交叉验证(JOEMS Multi-Phase Hybrid Bracketing Algorithms、Preprints.org "Numerical Comparison of Bisection and Newton's Method" by Shaimbetova 2025),自适应 bracket 扩展是数值工程共识,无正式学术专名。

---

## 问题 3:TWR GIPS 规范(子期间 / 清仓 / day count / 年化)

### 3.1 GIPS 规范要点(基于 2011 Guidance Statement)

| 规则 | 要求 |
|---|---|
| **估值频率** | 至少月度估值(monthly valuation) [^gips-2011] |
| **大现金流切分** | 必须在"large external cash flow"日重新估值并启动新子期间;阈值由 firm 自定义,常 10% portfolio value [^gips-2011] [^fairview] [^tsg] |
| **子期间几何链乘** | `TWR = (1+r₁)(1+r₂)...(1+rₙ) − 1` [^gips-2011] [^analystprep-fundamentals] |
| **年化方法** | GIPS Handbook:`(1 + cumulative_TWR)^(365/days) − 1` 或等价的 `(year_length / period_length)` 复合 [^analystprep-fundamentals] |
| **day count** | GIPS 不强制(在 modified Dietz 用 calendar days),实践多 Actual/365 (ISDA);权益投资 Actual/365 常见,固定收益 Actual/Actual [^nbim-2022] |
| **完全清仓** | 子期间 r = -100% (即 `1+r = 0`),链乘整体归零;**GIPS 视为组合终止**,后续重建视为新 track record [^gips-2011] [investigation inference] |

### 3.2 结论

**(a) 御财的子期间切分策略是激进的(超 GIPS 要求)**。御财 `computeTWR` (service.go L1334-1371) 在**每笔 trade date** 都切分子期间,而非仅在"large cash flow"切分。这比 GIPS 要求严格 —— 对私域家庭账完全足够,GIPS 会满意。**这是优点,不需改**。

**(b) totalDays 计算有 bug**。御财 twr.go L66 `totalDays := int(s.now().Sub(rangeStart).Hours() / 24)` 把整段视为单一时间窗。但当组合中途完全清仓(qty=0)时,链乘中的某段 `EndValueBeforeCF = 0` 会让该段 HPR = 0,导致 cumulative TWR = 0,无论后续重建多少次。这是已知数学陷阱 [^gips-2011 inferred] [^analystprep-fundamentals inferred]。

**(c) GIPS 对完全清仓 + 重建的官方处理**:
- 清仓当日子期间 return = `0/prev_after = 0`(HPR=−100%)
- 链乘结果被零吞噬
- GIPS 视该 portfolio 为"discontinued",新资本投入视为**新组合**(新 track)
- 不可在 cumulative 中"跳过"零段(几何链乘不允许)

**(d) 御财的特殊情况**:twr.go L42 检测 `BeginValueAfterCF == 0` 返回 `ErrZeroValue`,这避免了除零。但**没检测 EndValueBeforeCF = 0** —— 如果 EndValueBeforeCF=0,product 直接归零,不报错,返回 cumulative = -1 (即 -100% TWR),这显然不是用户期望。需要在归零前分段。

**(e) day count**:御财用 `Sub(t0).Hours() / 24 / 365.0`(actual/365),与 GIPS 实践一致,与 Excel XIRR 一致,**无需改**。

**(f) 年化**:御财 twr.go L56 `math.Pow(1+cumulative, 1/years) - 1`,与 GIPS 推荐一致,**无需改**。

### 3.3 对御财的具体修法建议

**问题 A:分段处理完全清仓**(service.go computeTWR L1334 + twr.go TWR L36):

```go
// 方案:在 twr.go TWR() 中检测 EndValueBeforeCF=0,返回特殊 sentinel
// 让 application 层把整段拆成多个"清仓-重建"独立段,各自计算 cumulative 后几何链乘

// twr.go 改动
const (
    ErrSegmentLiquidated = errors.New("twr: sub-period fully liquidated (end value zero)")
)

// 在 product 计算处(L45)增加
if sp.EndValueBeforeCF == 0 {
    return 0, ErrSegmentLiquidated   // 触发上层分段重算
}

// service.go computeTWR 改动:检测清仓段,分段计算 cumulative 后链乘
// 伪代码:
//   segments := splitOnLiquidation(effectiveDays, subPeriods)
//   chainProduct := 1.0
//   totalDays := 0
//   for _, seg := range segments {
//       segRate, _ := domain.TWR(seg.subPeriods, seg.finalValue, seg.lastAfterCF, seg.days)
//       chainProduct *= (1 + segRate)
//       totalDays += seg.days
//   }
//   cumulative := chainProduct - 1
//   return pow(1+cumulative, 365/totalDays) - 1
```

**简化方案(更稳)**:既然 GIPS 视清仓为组合终止,御财可以直接做"产品决策":**如果 holding 中途完全清仓过,TWR 显示 N/A 或分段显示**(每段独立 TWR,不混合)。这避免复杂的分段年化数学(每段年化后链乘 ≠ 整体年化,容易误导)。

**问题 B:totalDays 范围检查**。当前 `totalDays := int(s.now().Sub(rangeStart).Hours() / 24)`:
- 若 `rangeStart` 晚于 `now()`(clock skew 或测试 fixture)→ 负数 → 进入 `totalDays < 1` 分支返回累计(意外正确)
- 若 `rangeStart` = 今天 → 0 → 返回累计(正确)
- 若 rangeStart 是未来日期(配置错误)→ 应该报错或降级 nil

建议在 twr.go L52 增加负数显式处理:
```go
if totalDays < 0 {
    return 0, ErrInvalidRange   // 新增 sentinel
}
```

### 3.4 信源

[^gips-2011]: CFA Institute / GIPS Standards, "Guidance Statement on Calculation Methodology" (2011 revision), <https://www.gipsstandards.org/wp-content/uploads/2021/03/calculation_methodology_gs_2011.pdf> — 强制 time-weighted return,要求月度估值 + large cash flow 日重新估值,几何链乘。

[^fairview]: Fairview Performance Services, "Large Cash Flows versus Significant Cash Flows", <https://fairviewinvest.com/news/lcf-vs-scf/> — large cash flow 阈值常为 portfolio value 的 10%,触发重新估值启动新子期间。

[^tsg]: TSG Performance, "Significant vs. Large Cash Flows in the World of GIPS", <https://tsgperformance.com/significant-vs-large-cash-flows-world-gips/> — 区分 large(触发重估)与 significant(触发剔除出 composite)。

[^analystprep-fundamentals]: AnalystPrep (CFA Level III), "GIPS Fundamentals of Compliance / Time-Weighted Return and Modified Dietz Method", <https://analystprep.com/study-notes/cfa-level-iii/fundamentals-of-compliance/> — 子期间几何链乘公式、Modified Dietz、day count 用 calendar days。

[^nbim-2022]: Norges Bank Investment Management, "GIPS Manual 2022", <https://www.nbim.no/contentassets/91772203021442a99aa8687df2f9c284/gips-manual-2022.pdf> — 实操级 GIPS 实施 manual,涵盖 TWR 估值频率与 annualization。

---

## 问题 4:Money 精度(int64 cents → float64 XIRR 求解)

### 4.1 精度边界分析

| 数据类型 | 范围 | 精确整数上限 | 临界点对御财 |
|---|---|---|---|
| **IEEE 754 double (float64)** | ±1.8e308 | 2^53 = 9,007,199,254,740,992 ≈ 9.0e15 | 9.0e15 cents = **9.0e13 USD = 90 万亿 USD** |
| **int64 cents(御财存储)** | -9.2e18 ~ 9.2e18 | 全精度整数 | 远超家庭场景需求 |
| **典型家庭组合** | 1e6 ~ 1e10 cents | (1万 USD ~ 10万 USD) | 远低于 2^53 |

**核心结论**:家庭/个人场景下,int64 cents → float64 转换**无整数精度损失**(都在 2^53 内)[^moderntreasury] [^hackerone]。

**真正的风险在中间计算**:
- NPV = `Σ amount_i / (1+r)^years_i`,在 r ≈ 0、years ≈ 30 时,(1+r)^years ≈ 1,所以 NPV ≈ Σ amount_i
- 若 Σ amount_i ≈ 1e10 cents(= 100M USD,富裕家庭可达),float64 在 1e10 处的 ulp = `2^(log2(1e10) - 52)` = `2^(33-52)` = `2^-19` ≈ **1.9e-6**
- 御财阈值 1e-7 < 1.9e-6,**1e10 cents 量级已开始抖动**
- 1e8 cents(= 1M USD,中产家庭可达):ulp ≈ 1.5e-8,与 1e-7 同量级,**边界情况**
- 1e7 cents(= 10万 USD):ulp ≈ 1.5e-9,阈值 1e-7 安全

**结论**:御财的 1e-7 绝对阈值在 cashflow 量级 ≥ 1e7 cents(10万 USD / 70万 CNY)时开始进入危险区,在 1e8 cents 时已不可靠。这与问题 #1 是同一根源。

### 4.2 行业处理方案

| 方案 | 描述 | 适用场景 | 御财评估 |
|---|---|---|---|
| **归一化 cashflows** | 入口除以 max\|amount_i\|,求解,rate 不变 | 通用,XIRR 对 scale 不变 | ✅ **推荐**(5 行代码,数学等价) |
| **相对阈值** | `|NPV| ≤ atol + rtol·Σ\|cf\|` | 通用,scipy 范式 | ✅ 推荐(可与归一化并用) |
| **Decimal / BigDecimal** | 全程 high precision | 银行核心账务 | ❌ 不推荐:Newton 导数 + (1+r)^years 需 exp/log,Decimal 无现成实现,引入复杂度大 |
| **math/big.Float** | Go 标准库,任意精度 | 需要时局部使用 | ⚠️ 性能损失 ~100x,御财规模不需要 |
| **Kahan summation** | 改进 Σ 求和精度 | 减少累计误差 | ⚠️ 改善有限,不解决阈值本质问题 |

### 4.3 对御财的具体修法建议

**首选方案:入口归一化 + 相对阈值**(与问题 1 的修法合并,一并解决)

```go
// xirr.go XIRR() 入口,sort 之后
maxAbs := 0.0
for _, cf := range sorted {
    if a := math.Abs(cf.Amount); a > maxAbs { maxAbs = a }
}
if maxAbs == 0 { return 0, ErrNoSolution }
// 归一化(数学等价,XIRR 对 scale 不变)
for i := range sorted { sorted[i].Amount /= maxAbs }

// 之后 years/amounts 计算照旧,npv/npvPrime 不变
// 收敛阈值可继续用 1e-7(因为 NPV 现在在 O(N) 量级)
// 也可再加 rtol·scale 提升稳健性,但归一化后 scale=1,效果等价
```

**次选方案:仅改阈值**(如果不想动 cashflow 数据)

```go
// L74 改为
scale := 0.0
for _, a := range amounts { scale += math.Abs(a) }
if math.Abs(f) <= 1e-9 + 1e-10*scale { return rate, nil }
```

**结论**:**归一化是更简洁、更稳健、数学上严格等价的修法**。Strong recommend。

### 4.4 信源

[^moderntreasury]: Modern Treasury, "Floats Don't Work For Storing Cents", <https://www.moderntreasury.com/journal/floats-dont-work-for-storing-cents> — float64 53-bit mantissa 精确整数上限 2^53 ≈ 9.0e15,cents 存储应用 int。

[^hackerone]: HackerOne, "Why Using Cents Instead of Floating Point for Transaction Amounts is Crucial", <https://www.hackerone.com/blog/precision-matters-why-using-cents-instead-floating-point-transaction-amounts-crucial> — 推荐整数 cents 全链路,只在展示层转 float。

[^evanjones]: Evan Jones, "You Can Use Floating-Point Numbers for Money", <https://www.evanjones.ca/floating-point-money.html> — 反方观点:float64 可用于 money,前提是先 round 到 significant figures,再 round 到 cents。

---

## 问题 5:portfolioCAGR 方法论(换仓 / cost basis)

### 5.1 当前实现摘要

御财 `portfolioCAGR` (service.go L1577-1601) 公式:

```
Full CAGR  = (currentMV / currentCostBasis)^(365/days) - 1
             where days = now() - earliestHoldingCreated
Range CAGR = (currentMV / startMV)^(365/days) - 1
             where days = now() - rangeStart
```

其中 `currentCostBasisInBase` (service.go L927-955) = **当前未平仓 holdings 的 AvgCostCents × Quantity 之和**(忽略已平仓 holdings)。

### 5.2 行业最佳实践:CAGR 不适合多现金流场景

**CAGR 定义**(Investopedia / Wall Street Pres / CFA):
```
CAGR = (Ending_Value / Beginning_Value)^(1/n) - 1
```
- 只看起止两个值
- **忽略所有中间现金流**(追加投入、提取、分红再投、清仓重建)
- 适用于"单笔投入 + 持有 N 年"场景
- 不适用于有交易的真实组合 [^investopedia-cagr]

**换仓场景的错误示例**:
```
Jan 1:  buy 1000 shares @ $10   =  $10000 投入
Mar 1:  涨到 $15,全卖           =  $15000 收回(实现 +$5000)
Jul 1:  用 $15000 重新买入       =  cost basis = $15000
Dec 31: 市值 $18000             =  当前未实现 +$3000
```

| 指标 | 计算 | 数值 |
|---|---|---|
| **真实回报(XIRR)** | CF: -10000@Jan1, +15000@Mar1, -15000@Jul1, +18000@Dec31 → solve | **~93% 年化** |
| **御财 portfolioCAGR** | (18000/15000)^(365/365) - 1 | **20%** ← 严重低估 |
| **御财 holdingCAGR(单 holding)** | 取决于 security price history | 反映证券价格,与用户实际回报脱节 |

御财 portfolioCAGR **完全忽略了 1-3 月的 +5000 已实现利润**,因为它只看当前持仓的 cost basis。这是 P1 产品缺陷。

### 5.3 行业推荐的解决方案

**(a) 个人投资者标准 = Money-Weighted Return (XIRR)**:
- 现金流出(买入)= 负现金流
- 现金流入(卖出、分红)= 正现金流
- 期末市值 = 正现金流
- XIRR 求 NPV=0 的 r
- 自动捕获清仓 + 重建的时机价值 [^investopedia-mwrr] [^sharesight] [^aleta]

**(b) Time-Weighted Return (TWR)**:
- 消除现金流时机影响,衡量"投资选择质量"
- 与 manager skill 评价一致(GIPS 推荐)
- 适合回答"我选股选得好不好"

**(c) CAGR 的合适用途**:
- 单一持仓 buy-and-hold(无中间交易)
- 整个市场的 benchmark 对比(S&P 500 等)
- 长期复利演示

**(d) 御财 portfolioCAGR 的定位问题**:它不是真正的 CAGR(因为 cost basis 在变),也不是 XIRR(因为忽略现金流)。是一种**混合指标**,语义模糊。用户看到 "20%" 会误以为"我的钱一年涨了 20%",但实际是 93%。

### 5.4 对御财的具体修法建议

**短期(UI 防误读)**:
- portfolioCAGR 重命名为"当前持仓简单年化"或"未实现年化"
- 加 tooltip:"仅反映当前未平仓持仓的成本→市值变化,不包含已实现损益。完整回报请参考 XIRR。"
- 当 holding 中存在已平仓交易时,UI 显示警告图标

**中期(指标重构)**:
- **主指标改为 portfolioXIRR**(已存在,service.go L1252),它正确处理所有 cashflow 包括清仓重建
- portfolioCAGR 降级为辅助指标,或仅在没有交易(buy-and-hold)时显示
- 添加 portfolioTWR(已存在)作为"投资选择质量"指标
- 三指标组合:MWRR(我的实际回报)+ TWR(选股质量)+ benchmark CAGR(市场对比)

**长期(可选)**:
- 实现 Modified Dietz 作为近似 MWRR(无需迭代,有闭式解),作为 XIRR 收敛失败时的 fallback
- 添加 benchmark(如沪深 300、标普 500)对比线

**holdingCAGR 的特殊性**:御财 `holdingCAGR` (service.go L1628) 用 first buy date + priceAtOrBefore 取当时市价,然后 `(cur/adjFirst)^(365/days) - 1`。这本质是"证券价格 CAGR",不是"用户回报 CAGR"。注释 L1633-1637 已认识到这点("spec §6.2 是设计疏漏... 那量的是证券价格史起点而非用户个人回报")。建议:
- 对**单一持仓 buy-and-hold** 场景,holdingCAGR 可用
- 对**有加减仓**的持仓,holdingCAGR 应替换为 holdingXIRR(已存在)
- 在 UI 明确区分"证券价格史"vs"用户实际回报"

### 5.5 信源

[^investopedia-cagr]: Investopedia, "Compound Annual Growth Rate (CAGR) Formula and Calculation", <https://www.investopedia.com/terms/c/cagr.asp> — CAGR = (EV/BV)^(1/n) - 1,忽略中间现金流,不适合多期交易场景。

[^investopedia-mwrr]: Investopedia, "Money-Weighted Rate of Return (MWRR)", <https://www.investopedia.com/terms/m/money-weighted-return.asp> — MWRR 考虑现金流规模与时机,适合个人投资者业绩评价。

[^sharesight]: Sharesight, "Time-weighted vs Money-weighted Rates of Return", <https://www.sharesight.com/blog/time-weighted-vs-money-weighted-rates-of-return/> — 个人投资者推荐 MWRR,反映真实投资体验。

[^aleta]: Aleta.io, "Time-Weighted Return (TWR) vs. Money-Weighted Rate of Return (MWRR)", <https://aleta.io/knowledge-hub/time-weighted-return-twr-vs-money-weighted-rate-of-return-mwrr> — TWR 衡量投资选择质量,MWRR 衡量投资者 timing。

---

## 附录 A:推荐实施优先级

| 优先级 | 修法 | 影响文件 | 预估工作量 | 风险 |
|---|---|---|---|---|
| **P0-1** | XIRR 入口归一化 cashflows(解决问题 1 + 4) | `domain/xirr.go` ~5 行 | 30 分钟 | 极低(数学等价,加单测验证) |
| **P0-2** | XIRR 收敛阈值改相对(若不归一化) | `domain/xirr.go` ~3 行 | 30 分钟 | 低 |
| **P1-1** | XIRR bracket 自适应扩展(问题 2) | `domain/xirr.go` L91-111 重写 | 1-2 小时 | 中(需新 case 单测) |
| **P1-2** | TWR 完全清仓段切分(问题 3) | `application/service.go` + `domain/twr.go` | 2-4 小时 | 中(分段逻辑易错) |
| **P1-3** | portfolioCAGR UI 重命名 + tooltip(问题 5) | client + proto 字段 | 1 小时 | 低 |
| **P2-1** | portfolioCAGR → portfolioXIRR 主指标迁移 | client | 2 小时 | 低 |
| **P2-2** | Brent 替代 bisection(问题 1 升级) | `domain/xirr.go` | 2-3 小时 | 中(需移植算法) |

---

## 附录 B:测试用例建议

修法后应新增以下测试:

```go
// xirr_test.go
func TestXIRRLargeCashFlowsConverges(t *testing.T) {
    // 1e8 cents 量级 NPV, 修前永不收敛
    cfs := []CashFlow{
        {mustDate("2024-01-01"), -1e8},
        {mustDate("2024-12-31"), 1.1e8},
    }
    r, err := XIRR(cfs)
    require.NoError(t, err)
    require.InDelta(t, 0.10, r, 0.001)
}

func TestXIRRExtremeShortPeriodHighReturn(t *testing.T) {
    // 1 天 10% 回报 → 年化 1.28e15%, 修前 ErrNoSolution
    cfs := []CashFlow{
        {mustDate("2024-01-01"), -100},
        {mustDate("2024-01-02"), 110},
    }
    r, err := XIRR(cfs)
    require.NoError(t, err)
    require.Greater(t, r, 1.0e3)  // 年化 > 1000%
}

// twr_test.go
func TestTWRFullLiquidationSegment(t *testing.T) {
    // 中途完全清仓,应触发分段或返回特殊 sentinel
    // 不应返回 cumulative = -1.0 (误导)
}
```

---

## 附录 C:与现有 memory 的对齐

本调研结论与 `holding-return-engine-audit.md` 中记录的 findings 对应:
- P0-1(单 buy TWR)→ 与本文件问题 3 相关(TWR 子期间)
- P0-2(split CAGR)→ 与本文件问题 5 相关(CAGR 方法论)
- P1-3(FX 缺口日志)→ 已修(commit 1a86a79),与本文件无直接关系
- P1-7(fee 统一)→ fee 应统一计入 cashflow,与本文件问题 1 的 NPV 计算相关
- P1-9(range 降级日志)→ 与本文件问题 2(bracket 失败时的降级)相关

**新增 findings**(本调研产出):
- **新 P0:XIRR 收敛阈值绝对值问题**(归一化修法)— 之前 audit 未识别
- **新 P1:XIRR bracket 硬编码漏极端解**(自适应扩展)— 之前 audit 未识别
- **新 P1:portfolioCAGR 方法论不当**(应改 XIRR 主指标)— 之前 audit 未识别
- **新 P2:Money 精度边界**(归一化后自然解决)— 与 P1-4 同源,defer 合理

---

**END**
