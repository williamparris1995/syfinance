# Design — F8 标签维度

> R8 sprint-3 · 2026-09-03。

## ADRs

- **ADR-1 junction 查询单点**:`TagDao.transactionIdsForTag(tagId) → Set<String>`(+按需 watch 形态免——查询一次性);transaction DS 与 summary 复用此一方法(单一事实源)。
- **ADR-2 DS 过滤插入点**:`list()` 过滤链在 typeFilter 之后插 `tagId ∈ 集合`(集合为空=无关联交易→空结果,注意与"未传 tagId"区分);`summary(year, month, {tagId})` 聚合前同过滤;默认(无 tagId)逐位不变。
- **ADR-3 filter_bar 标签控件**:下拉(选项=TagRepository.list 实时取,含「全部标签」清空态);TxnFilterState.copyWith 哨兵齐;isDefault 覆盖。
- **ADR-4 标签页跳转**:tag page 卡片 onTap → `context.go('/transactions')` 携筛选(经路由 extra 或先 set 全局 filter?照库内 go_router 带参先例——router.dart 静态子路由惯例;最小:TransactionsPage 支持初始 filter 注入参数,tag 页 push 时传)。
- **ADR-5 报表页筛选**:报表页头部增标签下拉(同 ADR-3 控件复用或轻量版);选中→`summary(..., tagId:)` 重查;「全部」=现状。

## HLD 改动面

`core/localdb/daos/tag_dao.dart`(反查)、`transaction/domain/value_objects.dart`(+tagId)、`transaction_local_ds.dart`(list/summary 过滤)、`transaction_repository(_impl)`(summary 签名)、`filter_bar.dart`(控件)、`transaction_bloc.dart`(映射)、`tag/presentation/pages/tag_page.dart`(跳转)、`report/presentation/pages/report_page.dart`(筛选)、e2e 两处扩展。

## Risks

| 风险 | 缓解 |
|---|---|
| summary 签名变更波及调用方 | 可选参数默认 null,既有调用零改 |
| 标签下拉在交易量页的加载 | TagRepository.list 轻量(几十条) |

## Open Questions

无。
