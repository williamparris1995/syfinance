# Spec — F8 标签维度

> R8 sprint-3 · 2026-09-03 · analysis 产出(两形态决策经用户确认)。

## Goal

标签从"只有交易→标签方向"补全为可查维度:交易列表按标签筛选(反查)+ 报表页标签口径筛选——复用 F7 查询套件与 F12 前的既有管道,零新基建。

## Requirements

- **FR-1 反向查询管道**:`TagDao` 增标签→交易 id 集查询;`ListTransactionsParams` 增 `tagId`(可选)——DS 内存过滤(交易 id ∈ 标签关联集,经 junction);默认路径零变化。
- **FR-2 交易列表标签维度**:`TxnFilterState` 增 `tagId`;bloc 映射;filter_bar 增标签选择控件(下拉/弹层,多标签时取其一——v1 单选,注释);筛选变化重置第 1 页照旧;与类型/账户/分类/月份/搜索叠加。
- **FR-3 标签页入口**:标签页点标签卡 → 跳转交易列表并带 tagId 筛选(路由参数或回调,照库内跳转带参惯例)。
- **FR-4 报表标签筛选**:报表页增标签选择(含"全部");选中后 `summary` 聚合仅含带该标签的交易——`summary` 增可选 `tagId` 入参(实现:聚合前按关联集过滤,内存,与 DS 同 junction 查询复用);未选=现状零变化。
- **FR-5 回归门同步**:管道断言(tagId 过滤命中/不命中/叠加)进级链或新链;UI 断言(标签页跳转/交易列表选标签/报表筛选)进 ui_list_unify 或新文件;备份契约不变(junction 本地私有照旧,FR-10 断言零改动);三门全绿。

## NFR

- 默认行为逐位不变(无 tagId 时全部路径等价现状)。
- junction 查询单一事实源(TagDao 一处,transaction DS 与 summary 复用)。

## Scope boundary

| 排除 | 理由 |
|---|---|
| 多标签组合筛选(AND/OR) | v1 单选,YAGNI;backlog |
| 标签维度饼图(并行展示) | 用户选筛选形态,非并行视图 |
| 备份契约纳入 junction | 照旧本地私有(F6 照实断言不动) |

## Grill record

| 决策 | 定案 |
|---|---|
| 反查入口 | 用户选:交易列表+标签维度(复用 F7 套件)+标签页跳转 |
| 报表口径 | 用户选:报表页标签筛选(一个维度入口驱动全部聚合) |

## Feasibility

technical ✓(F7 套件/junction 表全在);economic ✓;operational ✓(回归门)。
