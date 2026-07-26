# 06 · 财务计算正确性(portfolioCAGR + XIRR/TWR 边界 + 摊销)

Type: grilling
Status: open
Blocked by: —

## Question

正常路径逻辑严密,但数值边界与方法论有失真(详见 `findings.md` F2/F3-F10/F11-F13;F1 汇率基数归 07):

- **[F2 P0]** portfolioCAGR 全期方法论 bug:`initial=currentCostBasis`(当前头寸)配 `days=earliestHoldingCreated→now`(含已清仓最早日)→ 换仓后年化失真(例:清仓 A +5k→买 B,年末显示 10% 实应 30%+)。是 memory P1-6 的真实根因(方法论 bug,非"产品简化")。
- **[F3 P1]** XIRR 收敛阈值绝对值 1e-7,大额组合(1e8 cents)NPV 浮点噪声 > 阈值永不收敛 → ErrNoSolution → 静默 nil。
- **[F4 P1]** XIRR bracket[-0.9999,1000] 漏短日暴利解。
- **[F5 P1]** Buy/SellHolding `AmountCents=int64(float64×)` 截断非四舍五入,逐笔分位漂移进 XIRR。
- **[F6 P1]** TWR 全期 totalDays 不切分完全清仓段(GIPS 应重启子链)。
- **[F7 P1]** 等额本金摊销中间月截断 + 利息按截断后 remaining 复算,系统性偏利。
- **[F10 P1]** TWR 年化 `cumulative<-1` 返回 NaN 未防御。
- **[F11-F13 P2]** XIRR float64 精度上限、ApplySplit 不校验 ratio、LumpSum 单利口径。

**决策点:**
1. portfolioCAGR:`initial` 改 earliest 时点成本 vs `days` 改"当前头寸最早建仓日",使两者同源?
2. XIRR:收敛改相对阈值 `|f|<1e-7*sumAbsCF` + 扩 bracket + Newton 阻尼?(XIRR 求解的数值分析最佳实践可 spawn research)
3. TWR:qty=0 期间切分子链 + cumulative<-1 防御?(GIPS 规范可 spawn research)
4. AmountCents 统一 `math.Round`;等额本金浮点均摊 + 每月四舍五入?
5. 是否补"真实样本贯穿到 XIRR/TWR"端到断言测试(防 mock 掩盖)?

## Research findings(2026-07-26)

调研完成,详见 [`research/financial-calc-standards.md`](../research/financial-calc-standards.md)(14 信源:Excel / scipy / numpy-financial / GIPS / CFA)。

**对决策点的行业依据:**
- **决策 2(XIRR 收敛,F3)**:根因是 float64 大额 NPV 的 ulp 与阈值同量级(cashflow ≥ 1e7 cents 即危险)。**最简修法 = 入口归一化**(5 行,数学等价 —— XIRR 对 cashflow scale 不变,scipy 风格 atol+rtol·scale),顺便解决 Money 精度边界(F11)。**不必上 Decimal/BigFloat**。
- **决策 2(XIRR bracket,F4)**:几何倍增扩展直到反号 + Brent 替代 bisection(参照 `andreyzworkaccount/xirr`)。
- **决策 3(TWR,F6/F10)**:**优点** —— 御财按 trade date 切分子期间已超 GIPS 要求。**修法**:零端值检测返 sentinel(防 `-100%` 误导)+ `service.go` 清仓段分段链乘;GIPS 视完全清仓为组合终止,后续重建为新 track。
- **决策 1(portfolioCAGR,F2)**:确认是方法论 bug —— 当前"当前持仓 cost basis → 当前 MV"**完全忽略已实现 PnL**,清仓+重建严重低估(示例:实际 93% 年化,御财显示 20%)。行业共识:多现金流场景应用 XIRR(MWRR)。**修法**:UI 重命名 + tooltip 标口径,中期主指标切到 `portfolioXIRR`(已存在)。

→ 各决策点已有行业依据,可进入 grilling 拍板。
