# Feature — F3 XIRR/TWR 财务计算正确性(R5 sprint-2 feature G)

> audit 06 决策 2/3/4 + Q5(决策 resolved 2026-07-26,research 14 信源),折入 F12 最小守卫。sprint-2 第三个 feature(E/F done 后);feature H(cagr-primary-switch)依赖本 feature。
> 源 ticket [.scratch/yucai-audit/issues/06](../../../../../../../.scratch/yucai-audit/issues/06-financial-calculation-correctness.md)。

## Description

收益引擎数值正确性整改:XIRR 入口归一化(修大额不收敛 F3 + float64 精度边界 F11)+ 求解器改 Brent-only(自适应 bracket 几何扩展,修极端短日漏解 F4,对齐 scipy/MATLAB 行业默认,上界 1e16);TWR 完全清仓段切分子链乘(GIPS,F6)+ 零端值与 cumulative<-1 可判别 sentinel(F10;wire/proto 零改动,nil 降级 + 英文结构化日志);AmountCents 4 处统一 math.Round(F5);等额本金浮点均摊 + 每月四舍五入 + 末月余差(F7;存量 schedule 不变);split ratio≤0 fail-closed 入口守卫(F12);真实样本端到端 oracle 测试(大额 1e8 / 清仓重建 / Excel+scipy 对拍,防 mock 掩盖)。主指标切换(portfolioCAGR→portfolioXIRR)= feature H 紧跟。

## Stories

1. XIRR 入口归一化 + scale=0 防御(F3/F11)
2. 删 Newton;自适应几何 bracket 扩展 + Brent 求根(F4;包络上界 1e16,超出 ErrNoSolution)
3. TWR 清仓段切分子链乘 + 零端值/cumulative<-1 可判别 sentinel(F6/F10;nil 降级 + 英文日志,wire 零改动)
4. AmountCents 4 处 math.Round(F5;层级归属留 design)
5. 等额本金浮点均摊 + 末月余差吸收(F7;存量 schedule 不变)
6. split ratio≤0 fail-closed 守卫(F12)
7. 真实样本 e2e oracle 测试套(FR-7)

## title

F3 XIRR/TWR 财务计算正确性(归一化 + Brent-only + 清仓分段 + round + oracle)

## keywords

xirr, twr, brent, bracket, normalization, liquidation, segment-chain, amortization, equal-principal, math.Round, oracle, 06, F3
