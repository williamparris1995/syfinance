# Task Brief F8-T2 — UI 层:标签筛选控件+跳转+报表筛选

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f8`,客户端 `yucai/client/`。**TDD。** T1 已就绪(管道 tagId 全链)。

## 先读(必读)
1. `docs/.../2026-09-03-tag-dimension/{spec.md FR-2/3/4,design.md ADR-3/4/5}`
2. `lib/transaction/presentation/widgets/filter_bar.dart`(TxnFilterState + F7 搜索/排序控件形态——标签下拉照 F9 category 下拉形态抄)
3. `lib/transaction/presentation/bloc/transaction_bloc.dart`(_params 映射——tagId 透传点)
4. `lib/tag/presentation/pages/tag_page.dart`(卡片 onTap 现状——跳转挂点)与 `lib/app/router.dart`(/transactions 路由形态——带初始 filter 的先例)
5. `lib/report/presentation/pages/report_page.dart`(_load/_loadMonthlyComparison——tagId 注入点)
6. **T1 review 观察 1**:boundRemote 在线态 junction 本地私有→tagId 被远端静默忽略——UI 必须处理(见交付物 4)

## 交付物
1. **filter_bar 标签下拉**(ADR-3):选项=TagRepository.list 实时(下拉打开时取或 initState 预取,选实现简单者注释);「全部标签」清空态;TxnFilterState+tagId(copyWith 哨兵/isDefault);bloc _params 映射 tagId。
2. **标签页跳转**(ADR-4):tag 卡 onTap → 交易列表带 tagId 初始筛选(TransactionsPage 初始 filter 注入——router 带参或 push extra,照库内先例选最小;mobile 同)。
3. **报表页标签筛选**(ADR-5):头部标签下拉(轻量版);选中 → summary(..., tagId:) 重查含月对比锚月;「全部」=现状。
4. **boundRemote 态处理**(T1 review 观察 1):交易列表与报表页的标签控件在 `route==boundRemote`(在线绑定)时**隐藏**(resolveDataRoute 判定,注释论证:junction 本地私有,远端 proto 无标签维度,静默忽略会造成"选了没反应";guest/boundOffline 本地管道完整生效)。
5. **顺手**:value_objects.dart isUnfilteredServerSide doc 补 tagId 一词(T1 review nit)。
6. TDD:bloc(tagId 映射/重置第 1 页);widget(下拉选项/选择回调/清空/boundRemote 隐藏/标签页跳转带参/报表重查参数含 tagId)。

## 验证
新单测绿(先红后绿)+`flutter test` 全量不回归(≥1430)+analyze 新文件 0 条+`make client-e2e F=integration_test/app_pages_test.dart` 抽验。

## 约束
R8 语义令牌;中文注释;T1 管道零改动;不 commit。完成后报告。
