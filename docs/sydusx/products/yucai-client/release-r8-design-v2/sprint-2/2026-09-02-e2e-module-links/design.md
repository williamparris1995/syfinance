# Design — F6 E2E 全模块关联链路补全

> R8 sprint-2 · 2026-09-02 · design 阶段产出(spec 修正包经用户确认)。
> API 事实清单:Explore 代理全量查证(2026-09-02,worktree f2014a07 基线),关键签名见 LLD 各链。

## Context

spec 定案 10 条管道链 + UI 链全覆盖 + 两层入口。design 阶段对全部依赖 API 做了代码级查证,产出四个改变设计的事实(标签无反查/目标注资不动账户/列表 category 筛选未接线/报表无 FX),已按用户确认回写 spec(修正包 7 项)。架构沿用现状(client DDD 四层 + drift 本地库 + getIt;architecture.md「本地 DB 未实施」为 R6 前过时记载,fast-lane 修正,见 Open Questions)。

## Goals / NonGoals

**Goals**:按 spec FR-1..FR-14 落地测试套件——7 个管道链路文件(默认回归)+ ~10 个 UI 链文件(手动)+ Makefile 双入口(`F=` 精准重跑)+ 种子/夹具扩展;全部断言对齐真实语义。

**NonGoals**:生产代码行为变更(仅测试 + Makefile;发现的功能缺口走 backlog);标签反查/category 筛选接线/文本搜索/FX(见 spec Scope boundary);CI 集成;性能优化。

## Decisions (ADRs)

### ADR-1 两层入口,`F=` 精准重跑

**Decision**:入口 A `make client-e2e` = 管道链路默认回归(种子→断言→删库);入口 B `make client-e2e-ui` = UI 链手动按需。两者均支持 `make client-e2e F=<文件名>` 单文件精准执行。
**Rationale**:用户拍板两层测试(管道优先,出问题手动调 UI 模式);隔离决策后文件数增长,精准重跑让"只验一条链"零成本。
**Alternatives**:全 UI 点按(慢脆,拒);单入口(盲区,拒)。
**Grill**:挑战"UI 点按盲区"→ 用户设计两层;挑战"3 文件粒度太粗"→ 用户定更细更精准(一链一文件 + F=)。

### ADR-2 文件布局:管道按链路组 7 文件,UI 一链一文件

**Decision**:管道文件按链路组拆 7 个(见 HLD 表),进默认回归 E2E_FILES(3 既有+7 新=10);UI 链一链一文件(~10 个),不进默认回归。
**Rationale**:管道文件每次回归都要跑,按组拆控制 boot 开销(每次文件=一次 Windows 设备启动);UI 链只在手动诊断时跑,boot 成本无所谓,一链一文件使 `F=` 粒度=链粒度,精准。
**Alternatives**:全部一文件(用户拒,选隔离);每链一文件×20(默认回归 boot 开销翻倍,拒)。
**Grill**:决策 4(隔离)+ design 决策 2(更细更精准)。

### ADR-3 断言走真实 DS 写管道,raw drift 读余额

**Decision**:管道链沿用 linked_transactions_test 模式:直接构造 `*LocalDataSource`(与 UI bloc 同一写管道),断言用 raw drift select `accounts.currentBalanceCents` + DS 返回值,oracle 手算常量内联注释。
**Rationale**:与 UI 同管道保证语义端到端;raw select 独立于被测逻辑(避免自证);既有模式已验证。
**Alternatives**:仅 bloc 层(依赖 pump,慢);仅 widget 断言(full_audit 已覆盖页面级)。
**Grill**:决策 1(两层测试)。

### ADR-4 订阅确定性触发 + UI 启动接线复刻

**Decision**:管道链直接 `AutoRecordScheduler(templates: TemplateRepoAutoRecord(...), notifier: ...).run(fixedToday)`(固定 today 常量);UI 链复刻 main.dart 启动序列(`configureDependencies → bootstrapNotifications(db) → pump app`)验证启动接线自动补账。
**Rationale**:run(DateTime) 纯入参确定性;启动接线盲区由 UI 链守住;实现无周期定时器(查证),无定时器改造必要。
**Alternatives**:用户提案"定时器改 1 秒测完恢复"——实现无周期定时器,无落点,弃;跑真实 main()(控制力弱,拒)。
**Grill**:决策 2;复刻 main.dart 序列的维护成本用户接受(main.dart 变更需同步)。

### ADR-5 备份往返数据层 + 文件内末位排序

**Decision**:备份链在数据层往返(`LocalSnapshotExporter.exportAll() → 清测试库 → ArchiveImporter.importAll(bytes)`),8 类实体逐模块比对;该链所在文件内,清库测试置于文件末位(避免影响同文件其他链)。
**Rationale**:UI 归档入口走原生 FilePicker(无头不可入,查证);exporter/importer 为纯数据 API;清库是破坏性操作,末位隔离。
**Alternatives**:UI 文件对话框流(不可行);独立清库进程(过度)。
**Grill**:决策 3;TransactionTags 不入备份契约(标签关联不保全)照实断言。

### ADR-6 条件项裁决:预算滚动纳入,FX 排除

**Decision**:预算跨月滚动并入 FR-5(`getBudgetByMonth('YYYY-MM')` 纯参数,spent 无 wall-clock,查证);报表 FX 排除(无换算代码,naive 求和不固化断言)。
**Grill**:spec 修正包,用户同意。

### ADR-7 标签反查缺口:测试改形 + backlog

**Decision**:FR-4 改形为挂载/读回/幂等/移除 + UI 标签页 CRUD;按标签反查交易、报表标签维度记 backlog(sprint-2 defer 区)。
**Rationale**:功能缺失非测试缺口;F6 是测试 feature,不扩成功能 feature(工时翻倍)。
**Alternatives**:顺手实现反查(用户拒,选 A)。
**Grill**:design 决策 1。

## HLD — 文件布局与共享设施

### 管道链路文件(进 E2E_FILES,默认回归)

| 文件 | 覆盖 | 关键 API(查证签名) |
|---|---|---|
| `link_receivable_collect_test.dart` | FR-1 收回 | `DebtLocalDataSource.recordPayment({debtId, scheduleEntryId, fromAccountId})` |
| `link_subscription_template_test.dart` | FR-2 订阅 + FR-3 模板 | `AutoRecordScheduler.run(today)`;`TemplateLocalDataSource.record(id)`;endDate 截断;空 category → `订阅·<名>` fallback 账户(a7e580ac 回归) |
| `link_budget_goal_test.dart` | FR-5 预算(含跨月)+ FR-6 目标 | `BudgetLocalDataSource.getBudgetByMonth('YYYY-MM')`/`createBudget`;`GoalLocalDataSource.recordContribution`/`createGoal(linkedAccountIds:)` |
| `link_tag_report_test.dart` | FR-4 标签(改形)+ FR-8 报表 oracle | `TagLocalDataSource.addTagToTransaction`/`getTransactionTags`/`removeTagFromTransaction`;`TransactionRepository.summary(y, m, scope)` + `aggregateCategorySlices` |
| `link_holding_buy_test.dart` | FR-7 买入 | `HoldingLocalDataSource.buy({accountId, securityId, fromAccountId, quantity, priceCents, feeCents, tradeDate})`(余额前置校验含) |
| `link_mutation_cascade_test.dart` | FR-9 编辑/删除/归档 + FR-14 列表查询 | `txns.update(UpdateTransactionParams)`(reverse+re-apply)/`delete`;`accounts.delete`(非零守卫)/archived;`txns.list(ListTransactionsParams)` 筛选/排序/分页 |
| `link_backup_roundtrip_test.dart` | FR-10 备份往返 | `LocalSnapshotExporter.exportAll()` → 清库 → `ArchiveImporter.importAll(bytes)`;**清库测试文件内置末位** |

### UI 链文件(手动,make client-e2e-ui)

一链一文件(`ui_` 前缀):`ui_boot_subscription_test.dart`(启动接线,ADR-4)、`ui_record_form_test.dart`(手动收支表单)、`ui_transfer_form_test.dart`、`ui_collect_form_test.dart`、`ui_buy_form_test.dart`、`ui_contribution_form_test.dart`、`ui_budget_page_test.dart`(创建+消耗显示)、`ui_tag_page_test.dart`(标签 CRUD)、`ui_backup_entry_test.dart`(入口可达)、`ui_list_filter_test.dart`(筛选器点选)。

### 共享设施

- `integration_test/link_support.dart`(新):`resetTestDb()`(删 yucai_test.db + configureDependencies + seedDemoData;**内置 NFR-1 裸跑守卫**——YUCAI_DB_FILE 非 yucai_test.db 直接拒跑)、`fundsAccount(name, initialCents)` 账户工厂、`balanceOf(db, accountId)` raw drift 读余额、`fixedToday` 常量(冻结日期,相对日期夹具基准)、`textContainingRich(needle)` 富文本感知 finder(Text.rich/RichText 明文拼接)、`deleteTestDb()`(先 close 再删,Windows 句柄)。零生产代码依赖,仅测试 helper。
- Makefile:`E2E_FILES` 3→10;新 `E2E_UI_FILES`;两目标 `F=` 变量透传(`$(F)` 非空则只跑该文件);每文件前杀 `yucai_client` 残留(沿用现有 powershell 行)。

## LLD — 各链断言口径(design contract 级)

各链固定模式:`setUpAll resetTestDb()` → 自包含夹具(链名前缀账户)→ 动作 → oracle 断言(前后差值)。oracle 数值在测试内手算注释。

1. **收回**:借出建应收(FR 既有模式)→ `recordPayment` → 断言 `fromAccount` 余额 +期次额、应收账户余额 −期次额、scheduleEntry.paid=true 且 paidCents=totalCents、transactionId 关联。
2. **订阅**:monthly 模板 nextDate=固定今天−3 个月 → `run(fixedToday)` → 断言 3 笔交易(description=模板名,日期=各期 nextDate)、余额 −3×金额、nextDate 前移至未来;endDate=今天−1 个月 → 仅 2 笔;空 category 模板 → 自动建 `订阅·<名>` 分类账户(a7e580ac)。
3. **模板**:expense 模板(空 category)→ `record` → 交易字段=模板(direction 配对 entries)、余额联动、nextDate 推进、lastTransactionId 落位;暂停模板 → 抛"模板已暂停"。
4. **预算**:绑定分类账户预算 month='2026-09' → 该月支出 → actual=max(Σdebit,Σcredit) oracle;上月另一笔 → `getBudgetByMonth('2026-09')` 不含上月。
5. **目标**:无链目标 `recordContribution` → currentAmount 增、账户余额不变、≥100% 翻转;Savings 目标 linked 账户 → 交易改余额 → actual=B1(读时聚合)。
6. **标签**:建 2 标签 → 挂载(其一重复)→ 读回 2(幂等)→ 移除 1 → 读回 1。
7. **报表 oracle**:跨 2 月/2 分类/N 笔夹具 → `summary(y,m)` income/expense/net/byDay/byCategory 手算 oracle;`aggregateCategorySlices` 占比 oracle;月对比 6 窗口锚月正确。
8. **买入**:资金账户+标的 → `buy` → 断言资金 −(price×qty)(fee 不走现金腿,查证语义!)、持仓 avg cost 含费用、HoldingLots/HoldingTransactions 落位;余额不足 → 抛"资金账户余额不足"。
9. **变更级联**:记交易 → `update` 改金额 → 余额=新值;`delete` → 回滚基线;账户非零 delete → 守卫异常;清零后删 → 成功;archived → 状态位。列表:`list({typeFilter})`×3 维 + 排序(transactionDate DESC,id DESC)+ pageSize=2 分页拼接=全量。
10. **备份往返**:8 类实体夹具(标签含 2 个,交易含 1 笔挂标签)→ 导出快照 → 清库 → 导入 → 逐模块字段级比对;标签关联(junction)不保全照实断言。
11. **UI 链**(每文件 1-3 个 testWidgets):pump 真实 app(guest 本地模式);`ui_boot_subscription` 按 ADR-4 序列;表单链走真实点按输入提交;断言用 `textContainingRich`(富文本感知,沿用 app_pages 模式)。

## Risks

| 风险 | 缓解 |
|---|---|
| Windows 设备启动竞争(多文件) | 沿用:串行 + 每文件前杀 `yucai_client` 残留 |
| 备份链清库波及同文件 | 文件内置末位 + 清库后该文件即结束 |
| UI 链 flake(表单/时序) | 仅入口 B 手动;`pumpAndSettle` 加时限;富文本 finder 复用 |
| 默认回归 3→10 文件时长增长 | 用户接受隔离代价;F= 精准重跑缓解 |
| demo_seed 与夹具耦合 | 夹具全 `链路*` 独立前缀,断言前后差值不绝对 |
| main.dart 启动序列复刻过期 | ADR-4 记录:main.dart 变更需同步 ui_boot_subscription(注释锚点) |
| buy 现金腿不含 fee(反直觉语义) | LLD-8 显式断言该语义;若视为缺陷另立 ticket |

## Migration

- Makefile:E2E_FILES 扩容 + `client-e2e-ui` 目标 + F= 透传(一次提交,向后兼容——不带 F 行为不变)。
- 无数据库 schema 变更、无生产代码变更 → 无迁移风险。
- merge 时 fast-lane:CLAUDE.md 快速命令区补 `client-e2e-ui`;sprint-2 defer 区补标签反查/category 接线/文本搜索 backlog;architecture.md「本地 DB 未实施」过时行修正(R6 已交付)。

## Open Questions

- 标签反查 + 报表标签维度 backlog 何时 ticket 化(用户裁决,不阻塞 F6)。
- buy 现金腿不含 fee 是否产品意图(语义反直觉;测试先照实断言,疑点记录)。
- category 筛选接线缺口是否随下次 transaction 模块改动一并补。
