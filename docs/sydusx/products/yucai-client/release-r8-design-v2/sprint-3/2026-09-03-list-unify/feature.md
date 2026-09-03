# Feature — F9 列表能力统一(R8 sprint-3)

> 2026-09-03 用户拍板(选项 2):列表分页/搜索/排序统一补全,按实体增长特性适配(F7 模式推广)。

## Description

把 F7 交易列表的查询能力模式(内存过滤管道 + 页码分页状态机 + 搜索/排序控件)推广到其余列表页,按各实体增长特性适配能力矩阵(analysis 定案):账户详情内嵌交易(已有 5 条/页迷你分页,统一到标准套件)、持仓/标的(中增长:分页+搜索)、债务/债权(中:搜索+排序)、账户管理(低:搜索)。低增长实体(预算/目标/分类/标签/模板)按矩阵决定。共享设施:TxnPagerBar 泛化为通用 PagerBar,F7 状态机模式提取为可复用范式;各模块本地 DS 补分页/搜索/排序 API(照 F7 in-memory 模式)。约束:make client-e2e/client-e2e-ui 回归全绿,F6/F7 既有断言不回归。

## Stories

- [ ] S1: 共享设施泛化(PagerBar 通用化 + F7 状态机模式提取)
- [ ] S2: 账户详情内嵌交易 → 标准查询套件(替换 5 条/页迷你分页)
- [ ] S3: 持仓/标的列表 → 分页+搜索
- [ ] S4: 债务/债权列表 → 搜索+排序(分页按矩阵定)
- [ ] S5: 账户管理 → 搜索
- [ ] S6: e2e 扩展 + 全量回归门

## title

F9 列表能力统一(分页/搜索/排序按实体适配)

## keywords

list-unify, pager, pagination, per-page-search, holdings-query, debt-query, account-detail, F9
