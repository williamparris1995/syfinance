# Task Brief T1 — F6 基础设施 + 收回链冒烟

> 工作目录(所有路径基于此):`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f6`
> Flutter 客户端在 `yucai/client/`。**不改任何生产代码(lib/ 下),只新增测试文件与改 Makefile。**

## 先读(必读,按序)

1. `docs/sydusx/products/yucai-client/release-r8-design-v2/sprint-2/2026-09-02-e2e-module-links/design.md` — ADR 与 LLD(本任务的契约)
2. `yucai/client/integration_test/linked_transactions_test.dart` — 既有管道链模式(setUpAll 删库/DS 构造/夹具/断言风格),**照此风格写**
3. `yucai/client/integration_test/app_pages_test.dart` 前 60 行 — `textContainingRich` finder 与 tearDownAll 删库收尾模式
4. `yucai/Makefile` 第 60-75 行 — 现有 `client-e2e` 目标

## 交付物

### 1. `yucai/client/integration_test/link_support.dart`(新)

共享测试 helper(仅测试代码),中文注释,含:

- `Future<void> resetTestDb()`:删 `yucai_test.db`(ApplicationSupport 目录)→ `configureDependencies()` → `seedDemoData(getIt<AppDatabase>())`(幂等种子,照 linked_transactions_test 的 setUpAll)。
- `Future<String> fundsAccount(String name, int initialBalanceCents)`:建 CNY 储蓄资产账户(AccountLocalDataSource.create,ownership personal),返回 id。
- `Future<int> balanceOf(AppDatabase db, String accountId)`:raw drift select `accounts.currentBalanceCents`。
- `const DateTime fixedToday = DateTime(2026, 9, 2);` — 冻结"今天",全部相对日期夹具与调度器入参的基准。
- `Finder textContainingRich(String needle)` — 从 app_pages_test 提取的富文本感知 finder(Text.rich/RichText 明文拼接匹配)。
- `Future<void> deleteTestDb()` — tearDownAll 用的删库收尾。

### 2. `yucai/client/integration_test/link_receivable_collect_test.dart`(新)— FR-1 债权收回链

文件头注释:F6 FR-1;文件须单独跑(Windows 设备竞争)。

模式:照 linked_transactions_test —— setUpAll `resetTestDb()` 后直接构造 `TransactionLocalDataSource(db, BalanceLocalUpdater(db))` / `DebtLocalDataSource(db, txns)` / `AccountLocalDataSource(db)`;夹具账户用独立前缀(如 `收链*`),断言用前后差值。

链路(查证过的 API 语义):

1. 夹具:资金账户(初始 200,000.00 元即 20000000 cents);`DebtLocalDataSource.create(accountId: 应收账户, type: DebtType.borrowedOut, sourceAccountId: 资金账户, totalPrincipalCents: 600000, counterparty: '收链好友', interestRate/amortizationIndex/startDate/dueDate 照 linked_transactions_test 借出链的参数形态)` —— 借出双写:资金 −本金、应收 +本金。
2. 取第一期:`DebtDao.getScheduleByDebt(debtId)`(经 db.debtDao 或 DS 暴露的途径,照既有测试的取法)第一个未付期次。
3. 动作:`debts.recordPayment(debtId:, scheduleEntryId:, fromAccountId: 资金账户)`。
4. 断言(前后差值 + 状态):
   - 资金账户余额 +entry.totalCents;应收账户余额 −entry.totalCents;
   - scheduleEntry.paid == true 且 paidCents == totalCents、transactionId 非空;
   - 再对同一期次 recordPayment → 抛 ServerFailure('该期次已还款')(expect throwsA)。
5. tearDownAll:`deleteTestDb()`。

oracle 数值在手算注释里写明(如利息口径拿不准,以 schedule 生成的 entry.totalCents 为准做差值断言,不要自己复利计算)。

### 3. Makefile 修改(`yucai/Makefile`)

- `E2E_FILES` 追加 `integration_test/link_receivable_collect_test.dart`(后续任务会继续追加,保持列表有序)。
- 新增 `E2E_UI_FILES :=`(暂空,T4 填充)。
- 新增目标 `client-e2e-ui`:镜像 client-e2e 的循环杀进程/串行逻辑,遍历 `E2E_UI_FILES`(空时 echo "no UI files yet" 不报错)。
- 两目标支持 `F=` 单文件透传:`FILES := $(if $(F),$(F),$(E2E_FILES))` 形式;`.PHONY` 更新;注释保持中文、说明 F= 用法(例:`make client-e2e F=integration_test/link_budget_goal_test.dart`)。
- 不动其他目标。

## 验证(必须全部执行并贴证据)

1. 杀残留:`powershell -NoProfile -Command "Get-Process yucai_client -ErrorAction SilentlyContinue | Stop-Process -Force"`
2. `cd yucai/client && flutter test integration_test/link_receivable_collect_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db` → 0 failures(超时给足,首跑要编译 Windows 桌面)
3. `cd yucai/client && flutter analyze` → 无新增 error/warning(测试文件也要过 analyzer)
4. `cd yucai && make -n client-e2e F=integration_test/link_receivable_collect_test.dart` → dry-run 显示只跑该文件
5. 确认 `yucai_test.db` 测试后被删(tearDownAll 生效):ApplicationSupport 目录检查一次

## 约束

- 中文注释(文件头 + 关键断言处);测试描述用中文。
- 不 import 生产 .g.dart 之外的内部实现细节以外的妥协;夹具独立、与演示数据零耦合。
- 不 commit(控制器审后统一提交)。
- 完成后报告:改动文件清单 + 上述验证的实际输出摘要。
