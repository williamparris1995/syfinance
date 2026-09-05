# Task Brief F8-T3 — e2e 扩展(spec FR-5)

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f8`,客户端 `yucai/client/`。T1/T2 已就绪。

## 交付物(照既有文件模式,中文注释+oracle)

1. **管道断言**:`integration_test/link_tag_report_test.dart` 标链扩展(或独立 testWidgets):夹具交易打标签 → `list(tagId:)` 只剩关联交易(空集/未传区分);`summary(..., tagId:)` 口径(含标签计入/不含剔出)。
2. **UI 断言**:`integration_test/ui_list_unify_test.dart` 或 `ui_list_filter_test.dart` 扩展:①标签页点标签卡→交易列表只剩带标签交易(跳转+筛选端到端);②交易列表标签下拉切换→列表变化;③报表页选标签→汇总数字变化(oracle 夹具)。注意 guest 模式(tagFilterAvailable 恒可用)。
3. **门**:`make client-e2e` 全量+`make client-e2e-ui F=<扩展文件>` 绿+`flutter test` 全量+analyze。

## 约束
生产代码零改动;夹具独立前缀;oracle 手算;不 commit。完成后报告。
