# Spec — F7 列表查询四件套

> R8 sprint-3 · 2026-09-03 · analysis 产出(三项产品决策经用户确认)。
> 事实基础:F6 API 查证(TxnFilterState.category 未接线/无搜索/固定序/DS 层已有 offset 分页)。

## Goal

交易列表补全四项查询能力——category 筛选接线、描述模糊搜索、日期/金额四态排序、页码分页控件——默认行为(无筛选时 transactionDate DESC, id DESC)保持不变,F6 回归门同步扩展并保持全绿。

## Requirements

### Requirement: FR-1 category 筛选接线

- [ ] 系统 SHALL 使 `TxnFilterState.category`(账户分类)经 bloc 映射进 `ListTransactionsParams` 并在 DS 层生效:仅返回 entries 涉及该分类账户的交易;筛选条上的分类下拉从"视觉存在"变为真实过滤。

#### Scenario: 按分类筛选

- GIVEN 夹具:跨分类(餐饮/交通)的已知交易
- WHEN 选择分类=餐饮
- THEN 列表仅含 entries 涉及餐饮账户的交易;UI 筛选条点选后列表同步变化

### Requirement: FR-2 描述模糊搜索

- [ ] 系统 SHALL 提供交易描述的模糊搜索(contains、大小写不敏感):筛选条搜索框 → 查询参数 → DS 层过滤;与其他筛选维度可叠加;筛选条件变化重置回第 1 页。

#### Scenario: 搜索描述

- GIVEN 夹具:描述含"午餐"/"Netflix"的交易
- WHEN 输入"午餐"
- THEN 仅描述含"午餐"(忽略大小写)的交易返回;叠加月份筛选时两者交集

### Requirement: FR-3 排序控件(日期+金额四态)

- [ ] 系统 SHALL 提供排序切换:键=日期/金额,方向=升/降,四态组合;金额口径=借方分录合计(复式 invariant 下=贷方合计);**默认仍日期降序**(现有行为与 F6 断言不动)。

#### Scenario: 金额降序

- GIVEN 夹具:金额不同的已知交易
- WHEN 排序切金额降序
- THEN 列表按借方合计降序;切回默认时恢复日期降序

### Requirement: FR-4 页码分页控件

- [ ] 系统 SHALL 提供页码控件(上一页/下一页 + 页码指示):基于既有 DS offset 分页(pageSize 维持 100),bloc 持 pageToken/hasMore;筛选/搜索/排序变化时重置第 1 页;末页禁用下一页。

#### Scenario: 翻页

- GIVEN 夹具:>100 条交易
- WHEN 第 1 页打开后点下一页
- THEN 显示第 101 条起;页码指示更新;末页下一页禁用

### Requirement: FR-5 F6 回归门同步

- [ ] 系统 SHALL 保持 `make client-e2e` 全绿并扩展断言:link_mutation_cascade 级链⑥ 补 category 维度/searchText/排序四态断言;ui_list_filter 补搜索输入/排序切换/翻页交互断言。

## NFR

- **NFR-1 默认行为不变**:无筛选/搜索/排序时结果集与序和现状逐位一致(F6 默认序断言不改)。
- **NFR-2 口径延续**:DS 层内存过滤/排序/分页(个人财务量级,不引入 SQL pushdown)。
- **NFR-3 回归绿**:单测新增(bloc/DS TDD)+ 全量 flutter test + make client-e2e 全绿。

## Scope boundary(排除项)

| 排除 | 理由 |
|---|---|
| 全文索引/拼音/搜索高亮 | 个人量级 contains 足够,YAGNI |
| 其他列表(账户/债务/持仓)的搜索分页排序 | 用户点名范围为交易列表;其他列表 defer |
| 服务器联动口径 | server 线 paused,本地 DS 先行(既有模式) |
| 搜索防抖/历史记录 | 简单重载即可,不加复杂度 |

## Grill record

| 决策 | 定案 |
|---|---|
| 搜索字段口径 | 用户选:描述模糊匹配(contains 忽略大小写);不扩账户/分类字段 |
| 排序键 | 用户选:日期+金额四态;默认日期降序不变(保护回归基线) |
| 分页形态 | 用户选:页码控件(上/下一页+页码;非推荐项 load-more,用户偏好明确) |

## Feasibility

technical ✓(DS 已有内存过滤/offset 分页,新增参数机械);economic ✓(纯本地改动,bloc+DS+filter_bar 三处);operational ✓(F6 回归门即验收)。
