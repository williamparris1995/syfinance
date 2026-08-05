# 06 · 财务计算正确性(portfolioCAGR + XIRR/TWR 边界 + 摊销)

Type: grilling
Status: resolved
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

## Answer(resolved 2026-07-26)

grilling 决策(5 点,research `financial-calc-standards.md` 14 信源支撑):

1. **Q1 portfolioCAGR(F2 P0)**:切 `portfolioXIRR` 为主指标(已存在,Q2 修后数值稳定);`portfolioCAGR` 降级辅助 + UI 重命名/tooltip 标口径(「仅当前持仓成本→市值,忽略已实现盈亏」)。research 共识:CAGR 不适合多现金流场景,正确指标是 XIRR(MWRR);当前方法论 bug(忽略已实现 PnL,清仓+重建严重失真)是 memory `holding-return-engine-audit` P1-6 真根因。修根换指标,非补丁方法论。
2. **Q2 XIRR(F3/F4/F11)**:入口归一化(除 `max|amount|`,5 行,数学等价 —— XIRR 对 cashflow scale 不变,解大额 1e8 cents 不收敛 F3 + float64 精度边界 F11)+ 自适应 bracket(几何倍增扩展直到反号,解短日暴利漏解 F4)+ Brent 替换 bisection(参照 scipy brentq / andreyzworkaccount,bracketed 无越界更稳健)。
3. **Q3 TWR(F6/F10)**:零端值检测返 sentinel(防 -100% 误导)+ `service.go` 清仓段分段链乘(GIPS:完全清仓=组合终止,重建为新 track;御财按 trade date 切分子期间已超 GIPS)+ `cumulative<-1` 返 sentinel/nil(F10 年化 NaN 防御,DTO 不再序列化为 0/null 掩盖)。
4. **Q4 数值精度(F5/F7)**:F5 `Buy/SellHolding AmountCents` 统一 `math.Round`(消除逐笔分位漂移进 XIRR)。F7 等额本金浮点均摊 + 每月四舍五入(消除中间月截断 + 按截断 remaining 复算的系统性偏利)。存量已生成 schedule 不变(实施 plan 处理)。
5. **Q5 测试**:真实样本端到端测试 —— XIRR/TWR 用真实 cashflow 样本(含大额 1e8 cents 验归一化收敛、清仓重建验分段链乘)+ Excel/scipy oracle 值断言。防 mock 掩盖(同 07 F1 决策)。

**跨 ticket**:Q1 UI 改(client 标口径)涉及 client 模块;Q2 XIRR 修后 Q1 portfolioXIRR 主指标才数值稳定(06 内部依赖)。

**F11-F13 P2**:归一化顺便解 F11(float64 精度上限);F12 ApplySplit ratio≤0 校验、F13 LumpSum 单利口径 —— P2 backlog 视反馈。

unblocks 无下游(06 叶子)。**实施留专项 plan/session**(XIRR/TWR 算法改 + service 清仓分段 + debt 摊销 + client UI 口径 + 真实样本测试,中等规模)。
