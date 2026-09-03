# Code Plan — F7 列表查询四件套

> execute 分解(2026-09-03)。约束:TDD(先红后绿);NFR-1 默认行为逐位不变;每任务后两轴 review。

## Tasks

- [x] **T1 domain+DS 层**:`ListTransactionsParams` +4 字段与枚举;`list()` 分类过滤/描述搜索/四态排序(tie-break 稳定);TDD 单测(组合矩阵+默认序不变断言)。验证:新单测绿 + 全量 flutter test 不回归。
- [x] **T2 bloc+UI 层**:TxnFilterState 扩展(search/sort);bloc `_params` 映射 + 分页状态/GoToTransactionsPageRequested 事件 + 重置语义;filter_bar 搜索框(onSubmitted 提交)+排序控件;分页条;bloc/widget 单测。验证:单测绿 + analyze 净。(fix round 1:搜索焦点缺陷改提交制+事件命名+prev 兜底+分页条瞬闪)
- [x] **T3 e2e 扩展+全量门**:link_mutation_cascade 级链⑦ 扩(category/searchText/四态排序/组合分页);ui_list_filter 扩(搜索提交制/排序点按/101 笔真实翻页);`make client-e2e` 全绿 + `flutter test` 全绿 + 提交。

## 执行方式

T1→T2→T3 串行派发 fresh implementer(brief 交接),每任务两轴 review,修复循环 ≤5。

## Ledger 记账

| task | 状态 | fix-rounds | 记事 |
|---|---|---|---|
| T1 DS 层 | ✅ | 0 | review APPROVE(Spec 零缺陷;S-3 registrant 噪音提交前还原);跨模块 import account 枚举为库内既定惯例(Minor 知悉) |
| T2 bloc+UI | ✅ | 1 | review 抓到真缺陷:desktop 搜索逐键提交致焦点丢失 → 改 onSubmitted 提交制+4 回归测;事件命名对齐 ...Requested;prev 兜底/分页条瞬闪两 minor 一并修 |
| T3 e2e 扩展 | ✅ | 0 | review 全 PASS(独立复算 oracle);级链⑦ 独立 case 不扰 F6 基线;101 笔真实翻页方案;非阻断注记:翻页夹具 2026-12 时效假设(套件共同弱点,2026-12 后需换锚) |
