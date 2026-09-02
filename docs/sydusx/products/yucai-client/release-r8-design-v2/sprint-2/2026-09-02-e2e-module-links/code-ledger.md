# Code Ledger — F6

> task done / fix-rounds / rulings 记账(execute 阶段)。

| task | 状态 | fix-rounds | 记事 |
|---|---|---|---|
| T1 基础设施+收回链 | ✅ done | 1(round 1:NFR-1 裸跑守卫 + 还原 registrant 行尾抖动) | review 全 PASS;实现者三处有据偏差:fixedToday 用 final(DateTime 无 const 构造)/deleteTestDb 先 close 再删(Windows 句柄)/期次额以 entry.totalCents 差值断言;R7 既有测试的删库在 Windows 实际删不掉(close 缺失),新 helper 已修正——backlog:既有三套件的 tearDownAll 可迁到本 helper |
| T2 记录/聚合三文件 | ✅ done | 1(round 1:isCompleted 照实断言 + 注释文件名笔误 ×5) | review 全 PASS,oracle 全部手工复算一致;三处语义出入有据(调度含当日→夹具改 −3 月;recordContribution 不自动置完成态→照实断言钉死;demo 预算落在真实运行当月→deleteBudget 删固定月演示预算+summary accountId 作用域,任意日历日无时间炸弹,grep 0 处 DateTime.now) |
| T3 资产/级联/备份三文件 | pending | | |
| T4 UI 链十文件 | pending | | |
| T5 全量回归门 | pending | | |

## rulings(审查裁决记录)

- T1 review 非阻断跟进:①NFR-1 守卫 → **已做**(round 1);②design HLD 共享设施清单缺 textContainingRich/deleteTestDb → T5 时顺手补全;③基线 linked_transactions_test.dart:218 的 amortizationIndex 注释错误(0=等额本息非 lumpSum)→ backlog 顺手修,不阻塞。
- T2 review 非阻断:LLD-7"月对比 6 窗口锚月"由标链③ 两个月窗口间接覆盖同一 summary API;6 窗口装配是报表页代码,T4 UI 链可选显式覆盖——记 backlog,不阻塞。
- spec 勘误待办(T5 顺手):FR-6 场景 1"状态翻转为已完成"与实现不符(recordContribution 不自动置位,completeGoal 显式)→ spec 措辞改为"进度 100%/remaining 0;完成置位为显式 completeGoal 语义(照实断言)"。
