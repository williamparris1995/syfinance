# Code Plan — F9 列表能力统一

> execute 分解。约束:TDD;NFR-1/2 零回归;每任务两轴 review。

## Tasks

- [ ] **T1 共享设施**:PagerBar 泛化(core/widgets)+ PageCursorStack 提取 + 交易页迁移(行为不变,F7 测试保绿)。验证:单测绿+全量。
- [ ] **T2 账户详情套件**:内嵌交易区替换迷你分页 → 标准查询套件(分页+搜索+排序);full_audit A3 保绿。验证:单测+e2e A3 单文件绿。
- [ ] **T3 三模块查询能力**:持仓(分页+搜索)/债务债权(搜索+排序)/账户(搜索)DS+bloc+UI。验证:TDD 单测+widget 测。
- [ ] **T4 e2e 扩展+全量门**:DS 级断言+UI 抽验;make client-e2e/client-e2e-ui/flutter test 全绿;提交。

## 执行方式

T1→T2→T3→T4 串行派发,每任务两轴 review,修复循环 ≤5。
