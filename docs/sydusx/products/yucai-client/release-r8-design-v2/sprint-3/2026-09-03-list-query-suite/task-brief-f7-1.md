# Task Brief F7-T1 — domain+DS 层:分类过滤/描述搜索/四态排序

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f7`,客户端 `yucai/client/`。**TDD:先写红测,后实现。**

## 先读(必读)

1. `docs/sydusx/products/yucai-client/release-r8-design-v2/sprint-3/2026-09-03-list-query-suite/spec.md`(FR-1/2/3 + NFR-1/2)+ `design.md`(ADR-1/2/3 + LLD)
2. `yucai/client/lib/transaction/domain/value_objects.dart`(`ListTransactionsParams` 现状,约 :85)
3. `yucai/client/lib/transaction/data/transaction_local_ds.dart`(`list()` 现状:约 :142,_assembleAll 全量载入→内存过滤 accountId/dateFrom/dateTo/typeFilter→排序 transactionDate DESC,id DESC(约 :160-163)→pageToken offset 分页(约 :165-173))
4. `yucai/client/lib/transaction/domain/value_objects.dart` 的 AccountCategory 定义位置(account 模块 or transaction 内)

## 交付物

### 1. domain 层(`value_objects.dart`)

- `TxnSortKey { date, amount }` / `TxnSortDir { asc, desc }` 枚举(命名可随库内惯例微调,注释中文)。
- `ListTransactionsParams` 追加:`AccountCategory? category`、`String? searchText`、`TxnSortKey sortKey = TxnSortKey.date`、`TxnSortDir sortDir = TxnSortDir.desc`——全部可选带默认,既有调用方零破坏。

### 2. DS 层(`transaction_local_ds.dart` `list()`)

按 design ADR-2 顺序插入(类型过滤之后、排序之前):
- **分类过滤**:交易任一 entry 的账户 category == 参数(与 accountId 过滤的"任一 entry 涉及"口径对齐;账户 category 的取法读 _assembleAll 的组装结构)。
- **搜索**:`description.toLowerCase().contains(searchText.toLowerCase())`(null description 视空串),仅当 searchText 非空非空白时生效。
- **排序**:sortKey=amount 时按 `entries.fold(Σdebit)` 比较(ADR-3 口径,注释写明 invariant);**tie-break 恒 transactionDate DESC + id DESC**(稳定序);sortKey=date 时保持现比较器仅方向随 sortDir。**无新参数(默认值)时执行路径与现状逐位一致**(NFR-1)。

### 3. TDD 单测(`test/transaction/data/transaction_local_ds_list_query_test.dart` 新)

红→绿循环,组合矩阵:
- 分类过滤(命中/不命中/跨分类交易)
- 搜索(命中/大小写/空串=不过滤/null description)
- 排序四态(date asc/desc、amount asc/desc)+ 同额 tie-break + 金额口径(复合/转账交易 Σdebit)
- 组合:分类×搜索×排序×分页(pageSize 小页)
- **默认序不变断言**:不带新参数时结果序与带默认参数一致,且与现状规则(transactionDate DESC,id DESC)一致

单测用内存 drift 数据库建夹具(参考既有 transaction DS 测试的夹具方式,找 `test/transaction/data/` 现有文件照抄模式;若无则用 NativeDatabase.memory + 手工建表种子——读 AppDatabase 构造确认可内存构造)。

## 验证(全部执行并贴证据)

1. `cd yucai/client && flutter test test/transaction/data/transaction_local_ds_list_query_test.dart` → 全绿
2. `flutter test`(全量)→ 不回归
3. `flutter analyze` → 新文件 0 条

## 约束

中文注释;不改 presentation 层(bloc/UI 是 T2);不动既有测试;不 commit。完成后报告:文件清单+测试输出+analyze。
