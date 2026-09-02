# Task Brief T4 — UI 链十文件(入口 B)

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f6`,客户端 `yucai/client/`。**不改生产代码,只新增 UI 测试文件 + Makefile 的 E2E_UI_FILES。**

## 先读(必读)

1. `docs/.../2026-09-02-e2e-module-links/design.md` 的 ADR-1/2/4 + LLD-11 + 风险表(UI flake 缓解)
2. `yucai/client/integration_test/full_audit_test.dart` — **UI 走查范式**(导航/菜单/表单可达/主题切换;侧栏标签 find.text;pumpAndSettle 用法)——本任务主样板
3. `yucai/client/integration_test/app_pages_test.dart` — pump 真实 app 的方式(guest 本地模式)+ textContainingRich
4. `yucai/client/integration_test/link_support.dart` — 复用(resetTestDb/fundsAccount/balanceOf/fixedToday/deleteTestDb/textContainingRich)
5. 生产代码(只读):`lib/main.dart`(启动序列)、`lib/core/notifications/notifications_bootstrap.dart`(bootstrapNotifications;注意它内部 run(**DateTime.now()**) 用真实时钟)、各模块 presentation/pages(表单字段/按钮文案)

## 总体模式(每文件)

- 文件头中文注释(ui_ 前缀,FR-12;单独跑警告;运行命令 `flutter test integration_test/<file> -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`;注明属 `make client-e2e-ui` 入口)。
- setUpAll `resetTestDb()` → 需要的夹具经 DS 预置(UI 前置数据用管道铺,UI 只测交互)→ `await tester.pumpWidget(const YucaiApp())`(照 app_pages_test 的 app 构造方式,读它用的具体 widget/参数)+ pumpAndSettle。
- 断言用 `textContainingRich`(富文本感知);`pumpAndSettle(const Duration(seconds: 2))` 起步,慢页面加时。
- tearDownAll `deleteTestDb()`。
- 每文件 1-3 个 testWidgets,聚焦本链交互。

## 十个文件与断言

1. **`ui_boot_subscription_test.dart`**(ADR-4 启动接线,本任务核心):resetTestDb → DS 预置 autoRecord 订阅模板(**nextDate 必须早于真实 now**,用 DateTime.now() 相对算,别用 fixedToday——bootstrapNotifications 内部是 run(DateTime.now()) 真实时钟)→ **复刻 main.dart 启动序列**:`bootstrapNotifications(getIt<AppDatabase>())`(读 main.dart:40-60 确认还调了什么,照抄必要步骤;bootstrap 有 try/catch 降级,托盘/通知失败不影响调度)→ pump app → 断言:DS 查交易已自动生成(description=模板名)且模板 nextDate 已前移越过 now;订阅管理页打开显示模板状态。注释锚点:"main.dart 启动序列变更需同步本文件"(ADR-4 维护责任)。
2. **`ui_record_form_test.dart`**:新建交易表单——收入一笔+支出一笔(真实点按输入:金额/选账户/选分类/提交),断言交易出现在交易记录列表(textContainingRich);若表单校验有必填提示,断言空提交被拦。
3. **`ui_transfer_form_test.dart`**:转账表单(两账户),提交后断言列表出现转账条目。
4. **`ui_collect_form_test.dart`**:DS 预置应收(borrowedOut 借出链产物)→ 打开债权详情 → 收回第一期(表单/按钮交互)→ 断言期次状态 UI 变化(已还)。
5. **`ui_buy_form_test.dart`**:DS 预置标的+资金账户 → 持仓买入表单提交 → 断言持仓/交易列表出现。
6. **`ui_contribution_form_test.dart`**:DS 预置目标 → 目标详情注资交互 → 断言进度 UI 变化。
7. **`ui_budget_page_test.dart`**:预算页新建预算(表单)→ 断言列表出现;若易做再 DS 记一笔支出后断言预算页已用/进度显示变化。
8. **`ui_tag_page_test.dart`**:标签页新建/重命名/删除标签交互(行菜单),断言列表变化。
9. **`ui_backup_entry_test.dart`**:设置页归档区入口可达——**只断言按钮/区块存在可见,绝不点击会触发 FilePicker 的按钮**(原生对话框无头不可关,点了测试挂死;design 决策 3:到入口可达为止)。注释写明原因。
10. **`ui_list_filter_test.dart`**:DS 预置多笔已知交易(跨类型/账户)→ 交易页筛选器点选(类型分段/月份/账户)→ 断言列表按筛选变化(用夹具独有描述串匹配)。

## Makefile

`E2E_UI_FILES :=` 填入十文件(integration_test/ 前缀),`client-e2e-ui` 目标自然生效(空列表守卫不再是空)。

## 验证(全部执行并贴证据)

1. 逐文件单跑(杀残留+define)→ 各 0 failures
2. `cd yucai && make client-e2e-ui` → 十文件串行全绿(这就是最终验收命令)
3. `flutter analyze` 新文件 0 条
4. 抽查一个文件跑后 yucai_test.db 已删

## 约束与风险预案

- **绝对不触发 FilePicker/原生对话框**(backup 文件);其他表单若提交弹 confirm 对话框,点确认即可(Material 对话框可测)。
- 页面文案以实际代码为准(先读页面源码找按钮/标签文案,别猜);找不到入口时读 router(静态子路由 /new /edit 在 /:id 前——architecture 约定)。
- flake 缓解:pumpAndSettle 分层等待;失败重跑一次确认是 flake 还是真红,真红就修测试或上报(若疑生产缺陷,记录不修生产)。
- 中文注释;不改生产代码;不 commit。完成后报告:文件清单+每文件输出摘要+make client-e2e-ui 证据+analyze。
