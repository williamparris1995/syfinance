# Code Ledger — F51

## Tasks

| Task | 状态 | fix-rounds | 备注 |
|---|---|---|---|
| TA 派生函数垂直片 | done | +1(收敛) | 13 测;评审 PASS 附两条 MEDIUM(孪生实现)→ 收敛轮:HoldingBloc._summarize 与 DS._toEntity 均改委托 domain 纯函数(537 绿) |
| TB 表单降级 | done | 0 | 6/6;getIt mock 注册;新建态 verifyNever 钉死 |
| TC 两页读侧 | done | 0 | 7 测含跨页逐分;总负债/净资产维持债源本息口径(ADR-2 授权,测④钉死) |
| TD 收口 | done | +1(评审 fix) | 全量 **2559 绿**;analyze **461**(基线 463,−2=顺手删死代码);e2e 12/13(见下) |

## 整体两轴评审(2026-10-10)

**裁决 PASS**(附 fix list,已全部本票内落地):
- S1+S2(核心):月供口径分裂(表单 Σ vs 读侧单债)+ 详情三段内联 Σ → 收敛轮:聚合面月供统一 Σ(derivedLoanFields.nextPaymentCents,全无期表显「-」),详情 Σtotal/Σremaining 委托派生函数;**双口径钉死**:聚合面=Σ、F35 还款计划面板 per-debt 行=单债(设计本义,测试⑥ 3 测);Σremaining 在分组小计/总负债处保持本息口径(与派生 Σ本金是两套授权口径,注释说明)
- S4:检测未决禁保存(_attachmentCheckDone;成功/失败/未注册都置 done 防 FR-4 卡死)
- S5:降级 loan 组补回账单制说明文字
- S6:删 _valueCents 死代码+重复 import(analyze 463→461)
- S7:code-plan 勾选(本文件同批)

## e2e 记录(P4)

`make client-e2e` 于修复前树 12/13(A2 败)、修复后树 12/13(Z 败)、**main 同形 12/13(Z 败)**——A2/Z 交替单败为本机 full_audit 既有非确定红,双点复跑排除 F51 因果(本 session 第三次同协议;建议单独立票查 full_audit 环境敏感性)。

## 环境注记

- 修复代理一次 stash 参数序误触旧 stash(2026-09-16)pop,即中止恢复,两条旧 stash 完好(git stash list 复核),污染 untracked 已清。
- 待用户验收:真库无挂接形态(双表示未灌水),F51 影响面在真库为零——属治理票性质;guest 库升级 v13 无(F51 零 schema)。
