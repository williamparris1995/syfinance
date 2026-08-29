# Code Ledger — F3 xirr-twr-correctness

> 执行记录(2026-08-29,inline TDD)。每任务 RED→GREEN 证据见 git 历史。

## tasks

| task | 状态 | 说明 |
|---|---|---|
| T1 brent.go | ✅ | 6 测试(线性/二次/Dottie/陡指数/端点零/同号拒);scipy brentq 语义移植 |
| T2 xirr.go 求解段 | ✅ | RED=1 天+10% 极端解旧实现 ErrNoSolution;Excel 37.34% oracle 在 Brent-only 下命中 |
| T3 twr.go 拆函数 | ✅ | CumulativeTWR+AnnualizeTWR+ErrInvalidCumulative;零端值双侧检测 |
| T4 computeTWR 分段 | ✅ | RED=清仓重建/终态清仓/当日全换手 3 测;4/4 绿后 holdingTWR 迁移新函数 |
| T5 amount.go | ✅ | TradeAmountCents 单点;handler×2+service×2 接线 |
| T6 split 守卫 | ✅ | ratio≤0 拒绝先于持久化(spy repo 验证零 Save) |
| T7 equalPrincipal | ✅ | float 均摊+round+末月余差;守恒+interest 序列手算 oracle |
| T8 oracle 收口 | ✅ | service 层 1e8 e2e(365 天精确 10%)+ 多笔 NPV 残差表(3 样本) |

## rulings / deviations(偏离 design 的裁决记录)

1. **T4:qty 判别用独立 helper `portfolioEmptyAt` 而非 mvCache 扩展返回 qty**(design LLD 原案)。理由:mvCache 扩展波及 `marketValueAtDateAsOfWithTrades` 公共契约(XIRR 链共用,byte-identical 保证);独立 helper 只在 MV=0 的罕见路径调用(无价格查询,纯 QtyAtDate),零热路径开销。可观测行为等价。
2. **T4 行为变更断言更新**:`TestPortfolioTWRRangeDegradeEarly` → `TestPortfolioTWRRangeStartsBeforeFirstTrade`。旧断言"rangeStart 早于首笔交易 → 空仓 → nil 降级";新分段语义下这是"起点落在空仓 gap → 链从首笔买入重启"返回真值(NFR 要求的逐一记录项)。
3. **T2:F3 大额测试在旧实现上通过**(Newton 步长退出准则救场)——`TestXIRRLargeCashFlowsConverge`/`ScaleInvariance` 是回归守卫而非 RED 驱动;RED 驱动是 F4 极端短日 case。research 的"1e7+ 危险"是概率性风险(依赖 |f'| 量级),归一化为 prophylactic 修复。
4. **T3:旧 `TWR()` 组合壳删除**(design 预告);唯一残余调用方 `holdingTWR` 迁移至 CumulativeTWR+AnnualizeTWR。附带行为变更:holdingTWR 零端值 case 旧可能返 −100%,新 sentinel nil(与 F6 语义一致)。
5. **T7:测试 oracle 手算笔误被实现纠正**(41667→4167,本金量级 1000001 而非 10000001)——修测试不修实现,实现正确。

## 行为变更清单(merge PR 描述素材)

- 极端短日解(F4):旧 nil → 真值(包络至 1e16)。
- 清仓重建/终态清仓 TWR(F6):旧 nil/−100% → 分段链乘真值/终止语义真值。
- 坏价(qty>0 ∧ MV=0):旧 −100% 可能 → sentinel nil + 英文日志。
- rangeStart 落在空仓 gap:旧 nil → 重建日起真值。
- Buy/Sell AmountCents(F5):截断 → 四舍五入(分位级差异)。
- 等额本金新生成 schedule(F7):月供本金/利息序列微变(守恒不变);存量不变。
- split ratio≤0(F12):旧静默损坏 → InvalidArgument 拒绝。

## suites

- `go build ./...` ✓;`go test ./... -count=1` 全绿(exit 0,2026-08-29)。
- holding 6 包 + debt 6 包 + 全仓其余包全过。

## review round 1(2026-08-29,fresh agent 两轴 review)→ 裁决 reject → 已修

**修复项(3 Important + 3 Minor)**:
1. xirr.go NaN 下界回退算术错误((lo+1)×0.05 → 正值)→ 改逐级 ×10 上移,lo 恒 ∈ (-1,-0.99];graceful 测试锁定(多根非常规流干净 ErrNoSolution,与旧实现同判,spec 排除多根)。
2. holdingTWR 降级无日志(HARD,NFR)→ CumulativeTWR/AnnualizeTWR 两处错误路径补 slog.Warn(英文结构化)。
3. CumulativeTWR 漏 finalValue==0 哨兵 → 补 domain 守卫 + 测试(holdingTWR 坏价不再 -100%)。
4. 有效上限 2^54→包络字面 1e16(ceiling 检查移到反号测试前)。
5. portfolioTWR 过期注释(range 空仓 gap 行为已变)→ 更新。
6. design LLD ⑦ 解回代校验落地(|npv(root)| ≤ 1e-6 归一化单位,fail-closed)。

**裁决记录(不修,理由)**:
- computeTWR ~150 行 Long Method(borderline)——walk+fold 结构内聚、逐分支有注释;接受。
- ADR-5 "两侧一致测试"以结构性保证替代(单点定义 + 全仓 grep 零残留截断点);handler e2e 需完整 account 校验 harness,边际保障近零。
- Excel fixture 1/3-5——离线无法新增可信 Excel 值,闭式解 + 文档例 + 残差断言替代;记录为已知缺口。

## review round 2(2026-08-29)→ 裁决 reject(1 blocker)→ 已修

**blocker**:回代校验绝对阈值 1e-6 在陡梯度区(11 年 -97% 深亏,|f'|≈5e16)误杀机器精度级正确解 → silent nil(F3/F4 同类病)。

**修复**:噪声模型预算 `|npv(r)| ≤ 100·eps·Σ|折现项| + 8·|npv'(r)|·xtol`——物理上正确:回代残差下限 = Brent 率收敛余量(|f'|·xtol,陡区主导)+ 求值噪声(eps·Σ,平缓区主导)。reviewer 建议的纯 κ·eps·Σ(κ≈10-100)经推导在其自己的深亏 case 需 κ≈2300、且在平缓区同样误杀(残差=|f'|·xtol≈y·scale·2e-12 vs 预算 eps·scale·κ)——导数项不可省。垃圾根残差 O(Σ|折现项|) 与预算差 ~10 量级,拒绝力保持。回归测试 TestXIRRSteepGradientDeepLossResolves(-0.9697111967122702 独立对拍值)。另按 nit 修 2^53 有效上限注释。
