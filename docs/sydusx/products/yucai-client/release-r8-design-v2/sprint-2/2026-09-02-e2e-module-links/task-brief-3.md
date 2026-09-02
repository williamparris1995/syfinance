# Task Brief T3 — 资产/级联/备份管道三文件

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f6`,客户端 `yucai/client/`。**不改生产代码,只新增测试文件 + Makefile 尾追加。**

## 先读(必读)

1. `docs/.../2026-09-02-e2e-module-links/design.md` 的 ADR-3/5 与 LLD-8/9/10 + 风险表(备份链末位/买入 fee 语义)
2. `yucai/client/integration_test/link_support.dart`(必用 helper)
3. `yucai/client/integration_test/link_receivable_collect_test.dart` 与 `link_budget_goal_test.dart`(范式样板,含 demo 种子防污染手法)
4. 生产代码(只读):`lib/holding/data/holding_local_ds.dart`(buy/sell/createSecurity)、`lib/transaction/data/transaction_local_ds.dart`(update/delete/list/summary)、`lib/account/data/account_local_ds.dart`(delete/archived)、`lib/backup/data/local_snapshot_exporter.dart` + `archive_importer.dart` + `archive_codec.dart`、`lib/core/localdb/app_database.dart`(表结构,往返比对用)

## 交付物(3 个新测试文件 + Makefile 追加)

共同模式同 T1/T2(文件头中文注释 FR 编号+单跑警告+命令;setUpAll resetTestDb;独立前缀 买链*/级链*/备链*;差值断言+oracle 注释;tearDownAll deleteTestDb)。

### 1. `link_holding_buy_test.dart` — FR-7 持仓买入

查证过的语义:
- `HoldingLocalDataSource.createSecurity({symbol, name, type(SecurityType), exchange?, currency})` 先建标的。
- `buy({accountId(持仓账户), securityId, fromAccountId(资金账户), quantity(double), priceCents, feeCents=0, tradeDate('YYYY-MM-DD'), notes?})`:一个 drift 事务 = 持仓 upsert(均价含费用化 fee)+ HoldingLots 插入 + HoldingTransactions 台账 + recordTransaction(debit 持仓账户/credit 资金账户,**金额=price×quantity,fee 不走现金腿**)。前置校验:from 必须 asset、两个账户不同 id、同币种、**资金余额 ≥ price×quantity**否则 ServerFailure('资金账户余额不足')。

断言(LLD-8):
1. 买入:资金余额 −(price×qty)(注意 fee 不减现金,显式注释这个反直觉语义);持仓数量/均价(含 fee 分摊)正确;HoldingLots/HoldingTransactions 各 1 行;台账方向为买。
2. 余额不足守卫:资金账户余额不足 → 抛'资金账户余额不足',且库内无新交易/持仓(事务回滚,差值断言)。
3. (可选加分)分两笔不同价买入 → 均价按加权口径(FIFO lots 两行)——如实现复杂可只断 lots=2 与总数量。

### 2. `link_mutation_cascade_test.dart` — FR-9 变更级联 + FR-14 列表查询

查证过的语义:
- `TransactionLocalDataSource.update(UpdateTransactionParams{id, version, entries, transactionDate?, description})`:校验 Σdebit==Σcredit + 乐观锁 version → 一个事务内 applyEntries(旧,−1) → 更新头 → 全量替换 entries → applyEntries(新,+1)。
- `TransactionLocalDataSource.delete(id)` → 余额回滚(内部实现读代码确认,按代码断言)。
- `AccountLocalDataSource.delete(id)`:账户不存在→'账户不存在';**currentBalanceCents != 0 → '账户余额非零,无法删除…'**;净零(即使有交易历史)直接删。archived:`update(... status: AccountStatus.archived)`(签名读 account_repository/DS,LLD 用实际方法)。
- 列表:`list(ListTransactionsParams{accountId?, dateFrom?, dateTo?, pageSize=100, pageToken?, typeFilter?})`:全量载入内存过滤(账户/日期窗/口味)→ 排序 **transactionDate DESC, id DESC** → pageToken=数字 offset 分页。typeFilter:all→null/transfer→TxnFlavour.transfer/income/expense→compound(inferFlavour 粗分类,**income/expense 不可分**,别断言能分)。

断言(LLD-9 + FR-14):
1. 编辑重算:记一笔已知金额 → update 改金额(同账户)→ 余额差值=新旧差;update 换账户 → 旧账户回滚+新账户入账(双腿)。
2. 删除回滚:delete → 余额回滚至基线。
3. 账户删除守卫:非零余额 → 抛'账户余额非零';把余额清零(转出/记账到 0)→ delete 成功(照实断言:净零+有历史可删,entries 成为孤儿是现状语义——注释写明)。
4. 账户归档:archived 置位 → 账户状态字段断言(status/ archived 标志,读实际字段)。
5. 列表查询:夹具 ≥5 笔(跨日期、跨类型含转账、跨账户)→ ①accountId 过滤只剩该账户相关;②月份窗(dateFrom/dateTo)只剩窗口内;③typeFilter=transfer 只剩转账;④默认排序=transactionDate DESC,id DESC(构造同日两笔验证 id 序);⑤pageSize=2 分页:第 1 页 2 笔+pageToken,取第 2 页,拼接=全量集合。

### 3. `link_backup_roundtrip_test.dart` — FR-10 备份归档往返

查证过的语义:
- `LocalSnapshotExporter.exportAll({tenantId 默认零 UUID})` → Uint8List(JSON envelope),覆盖 8 类:accounts/transactions/debts/budgets/goals/tags/templates/holdings。**TransactionTags 连接表 local-only 不入契约(标签关联不保全,照实断言)**。
- `ArchiveImporter.importAll(bytes)` 恢复(内部语义读代码:是覆盖还是追加,按代码断言)。
- ArchiveCodec 如有编解码(压缩/加密)参与,按实际调用链走。
- **注意 NFR/风险表:本文件内,清库的测试必须置于文件末位**(最后一个 testWidgets),清库动作(新库或删表)按 importer 的用法来——先读 importAll 实现决定怎么"清库"(可能是删 db 文件重建 AppDatabase,或 importer 自带 wipe;以代码为准)。

断言(LLD-10):
1. 夹具库:8 类实体各 ≥1(标签 2 个;1 笔交易挂 1 标签——用于照实断言标签关联不保全;债务含期次;预算/目标/模板/持仓/标的各 1;账户 ≥2)。
2. 导出 → 记快照(每类实体数+关键字段)→ 清库 → importAll → 逐类:数量一致+抽关键字段一致(id/金额/名称/日期)。
3. 标签关联:junction 不在导出内 → 导入后 getTransactionTags 为空(或不含原关联,按实际断言),注释写明这是契约现状非缺陷。

### 4. Makefile

`E2E_FILES` 尾部追加三文件。

## 验证(全部执行并贴证据;逐文件单独跑+杀残留+测后确认删库)

1. 每文件 `flutter test integration_test/<file> -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db` → 0 failures
2. `flutter analyze` 新文件 0 条
3. `make -n client-e2e` → 10 文件
4. 跑完 `yucai_test.db` 不存在

## 约束

中文注释;不改生产代码;oracle 手算注释;语义与简报出入时以代码为准+注释说明;不 commit。完成后报告同 T2 格式。
