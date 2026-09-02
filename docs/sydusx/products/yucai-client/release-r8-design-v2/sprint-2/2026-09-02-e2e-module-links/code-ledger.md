# Code Ledger — F6

> task done / fix-rounds / rulings 记账(execute 阶段)。

| task | 状态 | fix-rounds | 记事 |
|---|---|---|---|
| T1 基础设施+收回链 | ✅ done | 1(round 1:NFR-1 裸跑守卫 + 还原 registrant 行尾抖动) | review 全 PASS;实现者三处有据偏差:fixedToday 用 final(DateTime 无 const 构造)/deleteTestDb 先 close 再删(Windows 句柄)/期次额以 entry.totalCents 差值断言;R7 既有测试的删库在 Windows 实际删不掉(close 缺失),新 helper 已修正——backlog:既有三套件的 tearDownAll 可迁到本 helper |
| T2 记录/聚合三文件 | pending | | |
| T3 资产/级联/备份三文件 | pending | | |
| T4 UI 链十文件 | pending | | |
| T5 全量回归门 | pending | | |

## rulings(审查裁决记录)

- T1 review 非阻断跟进:①NFR-1 守卫 → **已做**(round 1);②design HLD 共享设施清单缺 textContainingRich/deleteTestDb → T5 时顺手补全;③基线 linked_transactions_test.dart:218 的 amortizationIndex 注释错误(0=等额本息非 lumpSum)→ backlog 顺手修,不阻塞。
