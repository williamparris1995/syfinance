# Feature — F7 列表查询四件套(R8 sprint-3)

> 2026-09-03 用户拍板:补齐 F6 确认的查询功能缺口,重点分页/搜索/排序/筛选。

## Description

交易列表(TransactionsPage)补全四项查询能力:①**category 筛选接线**——`TxnFilterState.category` 存在于筛选条但 bloc 未映射进 `ListTransactionsParams`(F6 查证);②**文本搜索**——按描述等文本字段过滤(现全管线无搜索);③**排序控件**——用户可切排序键/方向(现固定 transactionDate DESC, id DESC);④**分页 UI**——DS 层已有 pageSize/pageToken offset 分页,UI 全量加载无翻页(F6 FR-14 仅 DS 层断言)。约束:离线本地口径(drift 查询层),与 UI bloc 同管道;F6 的 `make client-e2e` 回归必须保持全绿(FR-14 管道断言随功能升级同步扩展)。

## Stories

- [ ] S1: category 筛选接线(TxnFilterState.category → 查询参数,管道+UI 双层生效)
- [ ] S2: 文本搜索(搜索框 + DS 层过滤,字段口径 analysis 定)
- [ ] S3: 排序控件(排序键/方向可切,口径 analysis 定)
- [ ] S4: 分页 UI(加载模式 analysis 定:load-more/页码)
- [ ] S5: F6 回归门同步(FR-14 断言扩展;make client-e2e 全绿)

## title

F7 列表查询四件套(筛选接线/搜索/排序/分页)

## keywords

list-query, filter, category-filter, search, sort, pagination, transaction-list, F7
