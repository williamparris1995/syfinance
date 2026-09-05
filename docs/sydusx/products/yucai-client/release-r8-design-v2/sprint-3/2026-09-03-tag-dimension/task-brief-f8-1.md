# Task Brief F8-T1 — 管道层:反查+junction 过滤

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f8`,客户端 `yucai/client/`。**TDD。**

## 先读(必读)
1. `docs/.../2026-09-03-tag-dimension/{spec.md FR-1/4,design.md ADR-1/2}`
2. `lib/core/localdb/daos/tag_dao.dart`(junction 表 TransactionTags 现有查询)与 `lib/tag/data/tag_repository_impl.dart`(TagLocalDataSource 挂载)
3. `lib/transaction/domain/value_objects.dart`(ListTransactionsParams 现状——F7 扩展后的形态)与 `transaction_repository.dart`(summary 签名)
4. `lib/transaction/data/transaction_local_ds.dart`(list 过滤链插入点——F7 分类/搜索之后;summary 聚合前过滤点)
5. F7 测试基线:`test/transaction/data/transaction_local_ds_list_query_test.dart`(夹具/断言模式照抄)

## 交付物
1. `TagDao.transactionIdsForTag(String tagId) → Future<Set<String>>`(junction 查询单点;中文注释)。
2. `ListTransactionsParams` +`tagId`(String?);`transaction_local_ds.list()` 过滤链插 tagId(集合成员判定;**空集=无关联交易→空结果**与未传区分——注释钉死);TransactionLocalDataSource 需能访问 TagDao(AppDatabase 现有依赖形态)。
3. `summary(year, month, {accountId, scope, day, tagId})` 聚合前同过滤(复用同一 TagDao 方法);repo 接口+impl 透传(可选参,既有调用零改)。
4. TDD(照 F7 模式,内存库夹具):命中/跨标签隔离/空集空结果/tagId×搜索×分类叠加/summary 口径(含标签交易计入,不含剔出)/默认(无 tagId)逐位不变。

## 验证
新单测绿(先红后绿)+`flutter test` 全量不回归(≥1422)+analyze 新文件 0 条。

## 约束
不动 UI(T2);默认路径逐位不变;中文注释;不 commit。完成后报告。
