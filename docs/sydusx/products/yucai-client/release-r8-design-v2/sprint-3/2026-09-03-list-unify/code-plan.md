# Code Plan — F9 列表能力统一

> execute 分解。约束:TDD;NFR-1/2 零回归;每任务两轴 review。

## Tasks

- [x] **T1 共享设施**:PagerBar 泛化(core/widgets)+ PageCursorStack 提取 + 交易页迁移(行为不变,F7 测试保绿)。验证:单测绿+全量。
- [x] **T2 账户详情套件**:内嵌交易区替换迷你分页 → 标准查询套件(分页+搜索+排序);full_audit A3 保绿。验证:单测+e2e A3 单文件绿。
- [x] **T3 三模块查询能力**:持仓(分页+搜索)/债务债权(搜索+排序)/账户(搜索)DS+bloc+UI。验证:TDD 单测+widget 测。
- [x] **T4 e2e 扩展+全量门**:DS 级断言+UI 抽验;make client-e2e/client-e2e-ui/flutter test 全绿;提交。

## 执行方式

T1→T2→T3→T4 串行派发,每任务两轴 review,修复循环 ≤5。


## Ledger 记账

| task | 状态 | fix-rounds | 记事 |
|---|---|---|---|
| T1 共享件 | ✅ | 1(2 注释 nit:FR 编号/先例措辞) | 逐位等价迁移(机械 diff 验证);PageCursorStack 落点 core/widgets 依依赖方向 |
| T2 账户详情 | ✅ | 0 | 复用路由层 TransactionBloc 单源(比简报更彻底);观察项:Loading 态「暂无交易」占位(Task6 时代既有,polish) |
| T3 三模块 | ✅ | 1(3 注释) | listPaged 新方法保旧 list;debt_query 收编单一事实源;security_page 已有搜索零改动 |
| T4 e2e+门 | ✅ | 0 | A2 金图因账户页搜索框合法重生成(断言零改动);统UI① 101 笔真翻页;Windows 实测坑两则钉入文件头 |

## holistic review(2026-09-03)PASS 记录

两轴 PASS,fix list 空。可选改进 backlog:①持仓 chips 计数口径对齐 accounts/debt(搜索作用域);②持仓搜索谓词抽 domain 单一实现(照 debt_query 范式);③debts_page:194 缩进归一。
