# Code Plan — F7 列表查询四件套

> execute 分解(2026-09-03)。约束:TDD(先红后绿);NFR-1 默认行为逐位不变;每任务后两轴 review。

## Tasks

- [ ] **T1 domain+DS 层**:`ListTransactionsParams` +4 字段与枚举;`list()` 分类过滤/描述搜索/四态排序(tie-break 稳定);TDD 单测(组合矩阵+默认序不变断言)。验证:新单测绿 + 全量 flutter test 不回归。
- [ ] **T2 bloc+UI 层**:TxnFilterState 扩展(search/sort);bloc `_params` 映射 + 分页状态/GoToPage 事件 + 重置语义;filter_bar 搜索框+排序控件;分页条;bloc/widget 单测。验证:单测绿 + analyze 净。
- [ ] **T3 e2e 扩展+全量门**:link_mutation_cascade 级链⑥ 扩(category/searchText/四态排序);ui_list_filter 扩(搜索输入/排序切换/翻页);`make client-e2e` 全绿 + `flutter test` 全绿 + 提交。

## 执行方式

T1→T2→T3 串行派发 fresh implementer(brief 交接),每任务两轴 review,修复循环 ≤5。
