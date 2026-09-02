# Code Plan — F6 E2E 全模块关联链路补全

> execute 阶段任务分解(2026-09-02)。每 task 一个可验证单元,完成后勾选。
> 全局约束:不改生产代码;真实库零接触(YUCAI_DB_FILE=yucai_test.db);每测试文件单独 boot 串行;跑前杀 yucai_client 残留;`flutter analyze` 无新增 error。

## Tasks

- [x] **T1 基础设施**:`integration_test/link_support.dart`(resetTestDb/fundsAccount/balanceOf/fixedToday/textContainingRich 提取共享)+ Makefile(E2E_FILES 3→10、E2E_UI_FILES、`client-e2e-ui` 目标、两目标 `F=` 透传)+ `link_receivable_collect_test.dart`(FR-1 收回链,兼作 harness 冒烟验证)。验证:flutter test 该文件绿 + analyze 净。
- [x] **T2 记录与聚合管道文件**:`link_subscription_template_test.dart`(FR-2 订阅 run(today)/endDate 截断/空 category fallback + FR-3 模板 record/暂停)+ `link_budget_goal_test.dart`(FR-5 预算消耗/跨月隔离 + FR-6 目标双语义)+ `link_tag_report_test.dart`(FR-4 标签挂载/幂等/移除 + FR-8 报表 summary/aggregateCategorySlices oracle)。验证:三文件各自绿。
- [x] **T3 资产与级联管道文件**:`link_holding_buy_test.dart`(FR-7 买入,含 fee 不走现金腿语义 + 余额不足守卫)+ `link_mutation_cascade_test.dart`(FR-9 update 重算/delete 回滚/账户删除守卫/归档 + FR-14 列表筛选三维/排序/分页)+ `link_backup_roundtrip_test.dart`(FR-10 八类实体往返,清库测试文件内置末位)。验证:三文件各自绿。
- [x] **T4 UI 链全套**:`ui_boot_subscription`(ADR-4 启动序列复刻)/`ui_record_form`/`ui_transfer_form`/`ui_collect_form`/`ui_buy_form`/`ui_contribution_form`/`ui_budget_page`/`ui_tag_page`/`ui_backup_entry`/`ui_list_filter` 十文件 + fix round 1 补 `ui_template_record`(FR-12 悬空枚举项)。验证:`make client-e2e-ui` 全绿(11 文件 17 测试)。
- [x] **T5 全量回归门(controller 执行)**:`make client-e2e` 全 10 文件绿(测后测试库删除验证)+ `F=` 单文件精准重跑验证 + `flutter analyze` 净(508 基线,新文件 0 条)+ 全量单测不回归(`flutter test` 1188 全绿)+ 提交。附带修复:仓库金图卫生 bug(全局 `*.png` gitignore 挡掉 3 张金图 → 全新 checkout/worktree 必红;.gitignore 反向规则 `!yucai/client/**/goldens/**/*.png` + 3 金图入库)。

## 执行方式

T1-T4 每任务派 fresh implementer 子代理(brief 文件交接,含 design.md LLD 对应链的断言口径)+ 每任务后 code-review 子代理(Standards+Spec 两轴);修复循环 ≤5。测试运行必须串行(Windows 设备竞争),子代理逐个派发,不并发。
