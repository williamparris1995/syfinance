# Task Brief F7-T3 — e2e 断言扩展 + 全量回归门

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f7`,客户端 `yucai/client/`。T1(DS 层 a6738eba)+ T2(bloc/UI 4948393c)已就绪:category/searchText/sortKey/sortDir 全链路生效,页码分页条落地。

## 先读(必读)

1. `docs/.../2026-09-03-list-query-suite/spec.md` 的 FR-5 + NFR-1/3
2. `yucai/client/integration_test/link_mutation_cascade_test.dart` 级链⑥(列表查询断言现状:账户/月份窗/typeFilter/默认排序/分页 offset)
3. `yucai/client/integration_test/ui_list_filter_test.dart`(UI 筛选器点选断言现状)
4. `yucai/client/lib/transaction/domain/value_objects.dart`(新枚举与参数)

## 交付物

### 1. `link_mutation_cascade_test.dart` 级链⑥ 扩展(管道层,DS 直调)

在既有断言后追加(照既有夹具模式,新断言用新 testWidgets 或并入⑥,自包含前缀照旧):
- **category 维度**:`list(category: AccountCategory.xxx)` 只剩 entries 涉及该分类账户的交易(夹具需含跨分类交易——若⑥夹具不够,加建)。
- **searchText**:按夹具已知描述串过滤(命中/忽略大小写各一)。
- **四态排序**:date asc / amount asc / amount desc 三新态(默认 date desc 已有),金额口径 Σdebit,同额 tie 验证。
- **组合**:category×search×amount desc×分页 一条。

### 2. `ui_list_filter_test.dart` 扩展(UI 层,真实点按)

- **搜索**:输入夹具独有描述串(回车提交制)→ 列表只剩匹配;清除钮 → 恢复。
- **排序**:点排序控件切金额降序 → 列表顺序按金额(夹具设计成金额序≠日期序);切回默认。
- **翻页**:夹具 > pageSize?——**注意**:DS pageSize 默认 100,塞 >100 笔夹具成本高;改为小 pageSize 不可行(UI 不暴露 pageSize)。务实方案:若夹具不足 100 条,分页条不显示——则 UI 翻页断言改为**分页条隐藏断言**(单页 hasMore=false 不显示控件)+ bloc/widget 层已有翻页单测兜底;若你能低成本批量建 100+ 笔(循环 recordTransaction 100 次可行,每笔轻),则做真实翻页点按断言(下一页/页码/末页禁用)。选一,注释说明取舍。

### 3. 全量回归门(controller 项,你来跑)

1. `cd yucai && make client-e2e`(10 文件全绿,种子→断言→删库)
2. `make client-e2e-ui F=integration_test/ui_list_filter_test.dart`(扩展后单文件绿)
3. `cd client && flutter test`(全量 1224+ 不回归)+ `flutter analyze`(基线,新文件 0 条)

## 验证

上述 3 项全部执行并贴证据;杀 yucai_client 残留;测后确认测试库已删;registrant 行尾噪音最后 git checkout -- 还原。

## 约束

不改 lib/(生产代码);不改 Makefile;中文注释;oracle 手算注释;不 commit。完成后报告:两文件扩展点+各输出摘要+三门证据。
