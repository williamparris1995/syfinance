# 御财 UI 对齐 · P0 完善实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 P0 轮 1 验证发现的 8 项 UI/数据缺陷，让御财账户列表与详情页对齐 OD v2 原型（`yucai-account-prototype-65e6`）。

**Architecture:** 8 任务分两类——3 个独立任务（列表副标题 / 服务端 SQL / topbar 毛玻璃，各改不同文件可并行）+ 5 个详情页任务（同改 `account_detail_page.dart`，**必须串行**执行，否则文件合并冲突）。详情页 5 任务按 hero → quick-stats → 近期交易分页 → info-card → 饼图顺序推进，每任务一个 review gate。汇率 API（原任务 9）拆独立 spec，不在本计划。

**Tech Stack:** Flutter (Dart, flutter_bloc, go_router) + Go (ent, raw SQL via database/sql) + TDD (flutter test / go test)。

## Global Constraints

- **原型源**：OD v2 优先（`yucai-account-prototype-65e6` 的 `detail-account.html` / `accounts.html`）；screens v1 仅备份。本计划所有"对齐原型"指 OD。
- **御财 token**（spec 第 5 节，`app_design.dart` 已定义为 `AppColors`/`AppSpacing`/`AppRadius`/`AppTypography`）：奶油白 bg `#f7f6f2` / 卡片白 surface `#ffffff` / 御财金 accent `#b08d57` / 收入绿 positive `#2d8a6e` / 支出红 negative `#c4544d` / 边框 border `#e6e3dc` / 圆角 sm 10px lg 14px / 标题 serif `displayFamily`(Georgia,'Noto Serif SC') / 数字 mono+`tabularFigures`。
- **i18n**：御财客户端无 i18n 基础设施，UI 文案硬编码中文（progress.md Task 0.6 确认；不要套用 syfinance Tauri 的 `t()` 规则）。
- **测试命令**：Flutter `cd yucai/client && flutter test test/<path>`；analyze `cd yucai/client && flutter analyze`（0 error 为准）；Go `cd yucai/server && go test ./internal/transaction/...`。
- **提交**：每任务一个 commit，前缀 `feat(client):` 或 `fix(server):`，中文描述。**不要提交 `graphify-out/`**（已 .gitignore）。
- **金额**：int64 cents，负数带 `-`，格式化用各页现有 `_fmt`/`_fmtSigned`（千分位 + 两位小数）。

---

## File Structure

| 文件 | 责任 | 改动任务 |
|------|------|----------|
| `yucai/client/lib/account/presentation/pages/accounts_page.dart` | 账户列表卡片副标题 | Task 1 |
| `yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go` | `TransactionSummary` 的 account-scope SQL | Task 2 |
| `yucai/server/internal/transaction/adapter/driven/repository/transaction_repo_test.go`（或同包测试） | scope 聚合回归测试 | Task 2 |
| `yucai/client/lib/app/widgets/app_shell.dart` | `_TopBar` 毛玻璃 | Task 3 |
| `yucai/client/lib/account/presentation/pages/account_detail_page.dart` | 详情页 hero / quick-stats / 近期交易 / info-card / 饼图 | Task 4–8 |
| `yucai/client/test/account/presentation/pages/account_detail_page_test.dart` | 详情页 widget 测试 | Task 4–8 |
| `yucai/client/test/account/presentation/pages/accounts_page_test.dart` | 列表卡副标题测试 | Task 1 |

**串行约束**：Task 4–8 全部修改 `account_detail_page.dart`，**不可并行**。执行器按 4→5→6→7→8 顺序，每任务 review 通过后再开下一个。

---

## Task 1: 列表 card 副标题 = institution · 卡号尾号

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/accounts_page.dart`（`_AccountCard.build` 内 ac-sub Text，约 L692-700）
- Test: `yucai/client/test/account/presentation/pages/accounts_page_test.dart`

**Interfaces:**
- Consumes: `Account.institution`（String）、`Account.cardNumberTail`（String，已存在 L70）、`Account.category.label`、`Account.currencyCode`
- Produces: 无（纯展示）

**Why:** 当前副标题是 `institution · currencyCode`，institution 为空时 fallback `category · currencyCode`。OD `accounts.html` 与 screens hero-sub 一致用 `机构 · 卡号尾号`。卡号尾号（`cardNumberTail`）字段已存在但未在列表卡使用。

- [ ] **Step 1: 写失败测试** — 在 `accounts_page_test.dart` 追加三分支断言（若无此文件则新建，参考现有 widget test 的 `pumpWidget` + `BlocProvider` mock 模式）：

```dart
testWidgets('card subtitle: institution · 尾号 when both present', (tester) async {
  await tester.pumpWidget(_harness(Account(
    id: 'a1', name: '招行储蓄', accountType: AccountType.asset,
    category: AccountCategory.savings, currencyCode: 'CNY',
    initialBalanceCents: 0, currentBalanceCents: 100000,
    ownership: Ownership.personal, status: AccountStatus.active,
    institution: '招商银行', cardNumberTail: '2840',
  )));
  await tester.pumpAndSettle();
  expect(find.text('招商银行 · 尾号 2840'), findsOneWidget);
});

testWidgets('card subtitle: institution only when no cardNumberTail', (tester) async {
  await tester.pumpWidget(_harness(Account(
    id: 'a2', name: '现金', accountType: AccountType.asset,
    category: AccountCategory.savings, currencyCode: 'CNY',
    initialBalanceCents: 0, currentBalanceCents: 50000,
    ownership: Ownership.personal, status: AccountStatus.active,
    institution: '微信', cardNumberTail: '',
  )));
  await tester.pumpAndSettle();
  expect(find.text('微信'), findsOneWidget);
});

testWidgets('card subtitle: category · currency fallback when no institution', (tester) async {
  await tester.pumpWidget(_harness(Account(
    id: 'a3', name: '现金钱包', accountType: AccountType.asset,
    category: AccountCategory.savings, currencyCode: 'CNY',
    initialBalanceCents: 0, currentBalanceCents: 50000,
    ownership: Ownership.personal, status: AccountStatus.active,
    institution: '', cardNumberTail: '',
  )));
  await tester.pumpAndSettle();
  expect(find.text('储蓄 · CNY'), findsOneWidget);
});
```

`_harness` 是测试辅助：包 `MaterialApp` + `BlocProvider<AccountBloc>(mock)` emit `AccountsLoaded([account])` + `BlocProvider<TransactionBloc>`。若现有测试文件已有类似 harness，复用之；否则按 accounts_page 依赖的最小 Provider 集搭建（AccountBloc + 顶层 GoRouter optional）。

- [ ] **Step 2: 运行测试验证失败**

Run: `cd yucai/client && flutter test test/account/presentation/pages/accounts_page_test.dart`
Expected: FAIL（当前渲染 `招商银行 · CNY` 而非 `招商银行 · 尾号 2840`）

- [ ] **Step 3: 实现** — 在 `_AccountCard` 内把 ac-sub 的 `Text` 改为调 `_subline(account)`，并新增方法（放在 `_sublineWidget` 附近）：

```dart
// ac-sub（机构 · 卡号尾号；institution 空时 fallback category · 币种）
Text(
  _subline(account),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: const TextStyle(color: AppColors.muted, fontSize: 12),
),
```

```dart
/// 卡片副标题：机构 · 卡号尾号（对齐 OD accounts.html hero-sub）。
/// institution 空 → fallback category · 币种（保留可读性）。
String _subline(Account a) {
  if (a.institution.isNotEmpty) {
    return a.cardNumberTail.isNotEmpty
        ? '${a.institution} · 尾号 ${a.cardNumberTail}'
        : a.institution;
  }
  return '${a.category.label} · ${a.currencyCode}';
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd yucai/client && flutter test test/account/presentation/pages/accounts_page_test.dart`
Expected: PASS（3 用例）

- [ ] **Step 5: analyze + 提交**

Run: `cd yucai/client && flutter analyze`
Expected: 0 error

```bash
git add yucai/client/lib/account/presentation/pages/accounts_page.dart \
        yucai/client/test/account/presentation/pages/accounts_page_test.dart
git commit -m "feat(client): 账户列表卡副标题改为 institution · 卡号尾号"
```

---

## Task 2: 统计 SQL A1 — scope 到 asset/liability 账户的聚合修复

**Files:**
- Modify: `yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go`（`TransactionSummary`，L484-522 的 `accountScopeClause` + SQL + args）
- Test: `yucai/server/internal/transaction/adapter/driven/repository/transaction_repo_test.go`（若不存在，在同包新增 `TestTransactionSummary_AccountScope`）

**Interfaces:**
- Consumes: `domain.SummaryScope{TenantID, Year, Month, AccountID}`、表名常量 `transactionEntryTable`/`transactionTable`、`DialectPostgres`、`rebindPlaceholders`
- Produces: 修正后的 `MonthlySummary`（scope 到 asset 账户时 income/expense 不再恒 0）

**Why / 根因:** `accountScopeClause = "(? IS NULL OR e.account_id = ?)"`（L490）过滤的是 **entry 行**。当 scope.AccountID 指向 asset/liability 账户时，只剩该账户自己的 leg；而 CASE（L500-504）只对 income/expense 计值，asset/liability → `ELSE 0`。结果：账户详情页的「本月收支」恒为 0（死数据）。

**修复（A1 subquery）:** 把 scope 从「过滤 entry 行」改为「过滤 transaction（命中该账户的交易）」，保留这些交易的所有 entry leg（含对手方 income/expense 账户）：

```sql
AND (? IS NULL OR t.id IN (
  SELECT e2.transaction_id FROM <entryTable> e2 WHERE e2.account_id = ?
))
```

- [ ] **Step 1: 写失败测试** — 在 transaction_repo 测试里造一个 asset→expense 场景，验证 scope 到 asset 账户时 expense 非 0：

```go
func TestTransactionSummary_AccountScopeAggregatesCounterpartyLegs(t *testing.T) {
	// 场景：asset 账户「招行卡」本月有一笔 100 元餐饮支出。
	//   entries: Food(expense) debit 10000  +  招行卡(asset) credit 10000
	// scope 到招行卡(account_id)：修复前 expense=0（CASE 对 asset ELSE 0）；
	// 修复后 expense=10000（保留对手方 Food leg）。
	db := newTestDB(t) // 复用现有测试 harness（ent 自动建表或内存 sqlite）
	repo := newTestRepo(t, db)
	ctx := context.Background()
	tenantID := uuid.New()
	assetAcct := seedAccount(t, db, tenantID, "income_or_expense"... ) // 见下
	// 实际用现有 seed helper：建 1 个 asset 账户 + 1 个 expense 账户 + 1 笔交易双 leg
	assetID, foodID := seedAssetAndExpenseAccount(t, db, tenantID)
	seedTxn(t, db, tenantID, nowYear, nowMonth,
		[]entry{{accountID: foodID, debitCents: 10000}},
		[]entry{{accountID: assetID, creditCents: 10000}})

	summary, err := repo.TransactionSummary(ctx, domain.SummaryScope{
		TenantID: tenantID, Year: nowYear, Month: nowMonth, AccountID: &assetID,
	})
	if err != nil { t.Fatalf("summary: %v", err) }
	if summary.ExpenseCents != 10000 {
		t.Errorf("scope to asset: expense = %d, want 10000 (counterparty leg)", summary.ExpenseCents)
	}
	if summary.NetCents != -10000 {
		t.Errorf("scope to asset: net = %d, want -10000", summary.NetCents)
	}
}
```

> 注：seed helper 名按现有测试包调整（`newTestDB`/`seedTxn`/`entry` 等若已存在则复用；不存在则在本测试内联最小构造）。参考现有 `transaction_repo_test.go` 的 fixture 模式。`nowYear`/`nowMonth` 用 `time.Now()`（非脚本，测试可用）。

- [ ] **Step 2: 运行测试验证失败**

Run: `cd yucai/server && go test ./internal/transaction/adapter/driven/repository/ -run TestTransactionSummary_AccountScope`
Expected: FAIL（`expense = 0, want 10000`）

- [ ] **Step 3: 实现** — 改 L484-493 的 `accountScopeClause` 定义 + L517-522 的 args（多一个重复的 AccountID 绑定给 subquery）：

```go
// account-scope: 过滤「命中该账户的 transaction」（保留对手方 income/expense leg）。
// 旧实现 "e.account_id = ?" 过滤 entry 行 → scope 到 asset/liability 账户时
// CASE 全 ELSE 0，详情页本月收支恒 0（死数据）。改用 t.id IN (子查询命中该账户
// 的 transaction_id)，让聚合涵盖这些交易的全部 leg（含对手方分类账户）。
accountScopeClause := "(? IS NULL OR t.id IN (SELECT " +
	transactionEntryTable + "." + transactionEntryFieldTransactionID + " FROM " +
	transactionEntryTable + " WHERE " +
	transactionEntryTable + "." + transactionEntryFieldAccountID + " = ?))"
if r.rawDialect == DialectPostgres {
	accountScopeClause = "(?::uuid IS NULL OR t.id IN (SELECT " +
		transactionEntryTable + "." + transactionEntryFieldTransactionID + " FROM " +
		transactionEntryTable + " WHERE " +
		transactionEntryTable + "." + transactionEntryFieldAccountID + " = ?::uuid))"
}
```

> 若 `transactionEntryFieldTransactionID` 常量不存在，先在常量块（L391 附近）补 `transactionEntryFieldTransactionID = "transaction_id"`（参考已有 `transactionEntryFieldAccountID`）。

args 调整（L517-522）—— scope 参数从 2 个变 3 个（`? IS NULL` 的 1 个 + subquery `account_id = ?` 的 1 个；原 `e.account_id = ?` 也是 1 个，净增 1 个用于 `IS NULL` 判空；实际上新子句有 2 处 `?` 对应 AccountID：判空 + 子查询）。最终 args：

```go
args := []any{
	accountTypeIncome, accountTypeExpense,
	scope.TenantID,
	start, end,
	scope.AccountID, // (? IS NULL OR ...)
	scope.AccountID,  // subquery WHERE account_id = ?
}
```

- [ ] **Step 4: 运行测试验证通过 + 全包回归**

Run: `cd yucai/server && go test ./internal/transaction/adapter/driven/repository/`
Expected: PASS（新测试 + 既有 summary 测试全过；确认无 scope=null 回归——`? IS NULL` 为 true 时短路，子查询不执行）

- [ ] **Step 5: 提交**

```bash
git add yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go \
        yucai/server/internal/transaction/adapter/driven/repository/transaction_repo_test.go
git commit -m "fix(server): TransactionSummary account-scope 聚合对手方 leg（修死数据 0）"
```

---

## Task 3: topbar 半透明米色 + 毛玻璃

**Files:**
- Modify: `yucai/client/lib/app/widgets/app_shell.dart`（`_TopBar.build`，L380-426）
- Test: `yucai/client/test/app/widgets/app_shell_test.dart`（若不存在则新建）

**Interfaces:**
- Consumes: `dart:ui` 的 `ImageFilter`、`AppColors.bg`(#f7f6f2)
- Produces: 无

**Why:** OD `.topbar` = `background:rgba(247,246,242,.85); backdrop-filter:blur(10px)`。当前 `_TopBar` 是 `color: AppColors.bg`（纯色不透明），缺毛玻璃通透感。

- [ ] **Step 1: 写失败测试** — 验证 `_TopBar` 渲染了 `BackdropFilter`：

```dart
testWidgets('TopBar uses BackdropFilter for frosted glass', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: _TopBar(title: '账户管理'),  // 需 export 或包 public harness
  ));
  // _TopBar 是私有类；测试需通过 AppShell 整体 pump 或在文件内 @visibleForTesting。
  // 推荐：pump AppShell（带 mock AuthBloc + NavigationShell），find BackdropFilter。
  expect(find.byType(BackdropFilter), findsOneWidget);
});
```

> `_TopBar` 私有 → 测试走 `AppShell`（需 mock `AuthBloc` emit `Authenticated` + `StatefulNavigationShell` stub）。若 AppShell 难 pump，最小可行：把 `_TopBar` 抽成 `@visibleForTesting` 或直接 pump 整页。执行器按现有 app_shell 测试惯例选（若已有 app_shell_test.dart 则在其中追加）。

- [ ] **Step 2: 运行验证失败**

Run: `cd yucai/client && flutter test test/app/widgets/app_shell_test.dart`
Expected: FAIL（无 BackdropFilter）

- [ ] **Step 3: 实现** — 顶部加 `import 'dart:ui';`，改 `_TopBar.build`：

```dart
@override
Widget build(BuildContext context) {
  return ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        // OD .topbar: rgba(247,246,242,.85)
        color: const Color(0xFFF7F6F2).withValues(alpha: 0.85),
        child: Row(children: [
          Text(title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.fg,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback,
              )),
          const Spacer(),
          if (!compact)
            SizedBox(
              width: 220,
              child: TextField(
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '搜索交易、账户…',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: AppColors.muted),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: '通知',
            icon: const Icon(Icons.notifications_none_outlined,
                color: AppColors.muted),
            onPressed: () {},
          ),
          if (!compact)
            IconButton(
              tooltip: '设置',
              icon: const Icon(Icons.settings_outlined,
                  color: AppColors.muted),
              onPressed: () {},
            ),
        ]),
      ),
    ),
  );
}
```

> `ClipRect` 约束 `BackdropFilter` 的模糊范围不越过 topbar 边界。下方 `Divider`（L45）保持不变。

- [ ] **Step 4: 运行测试验证通过 + analyze**

Run: `cd yucai/client && flutter test test/app/widgets/app_shell_test.dart && flutter analyze`
Expected: PASS + 0 error

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/app/widgets/app_shell.dart yucai/client/test/app/widgets/app_shell_test.dart
git commit -m "feat(client): topbar 半透明米色 + 毛玻璃 blur(10)（对齐 OD）"
```

---

## Task 4: 详情 Hero 对齐 OD（加 hero-name + hero-org）

**⚠️ 串行约束：Task 4-8 同改 account_detail_page.dart，本任务先做。**

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_detail_page.dart`（`_hero` 方法 L221-307）
- Test: `yucai/client/test/account/presentation/pages/account_detail_page_test.dart`

**Interfaces:**
- Consumes: `Account.name`、`Account.institution`、`Account.cardNumberTail`、`Account.currencyCode`、`Account.category.label`
- Produces: 无

**Why:** 当前 hero 只有 badge×3 + 余额 + 本月收支 + hero-fields。OD hero 结构：badge×2（类型 / 资产·负债类·活期）→ **hero-name（28px serif 账户名）** → **hero-org（机构 · 币种 · 卡号）** → hero-bal-label"可用余额" + 余额 + hero-bal-sub。当前缺 hero-name 和 hero-org（账户名在 AppBar title，原型放 hero）。

**决策记录:** AppBar title 保持"账户详情"（不改面包屑，避免 router 改动）；账户名移到 hero-name。

- [ ] **Step 1: 写失败测试** — 验证 hero 渲染账户名 + 机构·卡号：

```dart
testWidgets('hero shows account name + org · card tail', (tester) async {
  final account = Account(
    id: 'a1', name: '招商银行储蓄卡', accountType: AccountType.asset,
    category: AccountCategory.savings, currencyCode: 'CNY',
    initialBalanceCents: 0, currentBalanceCents: 128540000,
    ownership: Ownership.personal, status: AccountStatus.active,
    institution: '招商银行', cardNumberTail: '2840',
  );
  await tester.pumpWidget(_detailHarness(account));
  await tester.pumpAndSettle();
  expect(find.text('招商银行储蓄卡'), findsOneWidget);         // hero-name
  expect(find.text('招商银行 · CNY · 尾号 2840'), findsOneWidget); // hero-org
  expect(find.text('可用余额'), findsOneWidget);                // hero-bal-label
});
```

`_detailHarness`：`MaterialApp` + `BlocProvider<AccountBloc>`(emit `AccountDetailLoaded(account)`) + `BlocProvider<TransactionBloc>`(emit `TransactionsLoaded(transactions: [], summary: null)`)。若现有 account_detail_page_test.dart 已有 harness，复用。

- [ ] **Step 2: 运行验证失败**

Run: `cd yucai/client && flutter test test/account/presentation/pages/account_detail_page_test.dart`
Expected: FAIL（找不到 hero-name / hero-org / hero-bal-label）

- [ ] **Step 3: 实现** — 重构 `_hero` 方法（L221-307）。把 badge×3 改为 badge×2，在 badge 后、余额前插入 hero-name + hero-org，余额前加 label：

```dart
Widget _hero(Account a, int netCents) {
  final isLiability = a.accountType == AccountType.liability;
  final netPositive = netCents >= 0;
  // hero-org: 机构 · 币种 · 尾号（对齐 OD .hero-org）
  final org = a.institution.isEmpty && a.cardNumberTail.isEmpty
      ? '${a.category.label} · ${a.currencyCode}'
      : [
          if (a.institution.isNotEmpty) a.institution,
          a.currencyCode,
          if (a.cardNumberTail.isNotEmpty) '尾号 ${a.cardNumberTail}',
        ].join(' · ');
  return ClipRRect(
    borderRadius: AppRadius.lgBorder,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1E21), Color(0xFF2A2D33)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // hero-badges: 类型 + 资产·负债类·活期/定期（合并为单个 ghost badge）
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroBadge(a.category.label),
                  _heroBadge(isLiability ? '负债类' : '资产类'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // hero-name: 账户名 28px serif（对齐 OD .hero-name）
              Text(
                a.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.01,
                  height: 1.15,
                  fontFamily: AppTypography.displayFamily,
                  fontFamilyFallback: AppTypography.displayFallback,
                ),
              ),
              const SizedBox(height: 6),
              // hero-org: 机构 · 币种 · 卡号（对齐 OD .hero-org）
              Text(
                org,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // hero-bal-label
              Text(
                '可用余额',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 0.04,
                ),
              ),
              const SizedBox(height: 6),
              // 余额 40px 白字 serif/mono display
              Text(
                _fmt(a.currentBalanceCents),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: Colors.white,
                  fontFeatures: AppTypography.tabularFigures,
                  fontFamily: AppTypography.displayFamily,
                  fontFamilyFallback: AppTypography.displayFallback,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // hero-bal-sub 本月收支（正绿 #6FCF9A 负红 #E57373）
              Text(
                '本月收支 ${netPositive ? '+' : '-'}¥'
                '${(netCents.abs() ~/ 100).toString()}.'
                '${(netCents.abs() % 100).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 13,
                  color: netPositive
                      ? const Color(0xFF6FCF9A)
                      : const Color(0xFFE57373),
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _heroFields(a),
            ],
          ),
        ],
      ),
    ),
  );
}
```

> 删除了原"活期/定期"独立 badge（合并进语义；OD 用 ghost badge"资产类 · 活期"，此处简化为两个 badge：类型 + 资产/负债类）。`_heroBadge`/`_heroFields`/`_fmt` 保持不变。

- [ ] **Step 4: 运行测试通过 + analyze**

Run: `cd yucai/client && flutter test test/account/presentation/pages/account_detail_page_test.dart && flutter analyze`
Expected: PASS（新用例 + 既有 hero 测试可能需同步更新断言——若旧测试断言了 3 个 badge 或缺 name，按新结构修正）+ 0 error

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/account_detail_page.dart \
        yucai/client/test/account/presentation/pages/account_detail_page_test.dart
git commit -m "feat(client): 详情 hero 加 hero-name + hero-org（对齐 OD）"
```

---

## Task 5: 详情 quick-stats 类型专属 4 卡

**⚠️ 依赖 Task 4（同文件）。**

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_detail_page.dart`（`_statsRow` L440-475）
- Test: 同 account_detail_page_test.dart

**Interfaces:**
- Consumes: `Account` 类型专属字段（creditLimitCents/loanOriginalCents/loanRemainingCents/loanMonthlyCents/investMarketValueCents/investCostCents/investReturnYtd）、`MonthlySummary.incomeCents/expenseCents/netCents`、`List<Transaction>` 长度
- Produces: 无

**Why:** OD `.stat-row` 只示范储蓄（本月收入/支出/净流入/交易数）。按决策③做类型专属变体，仅用现有字段（无积分/未出账数据源的指标不显示）。

**类型变体表:**
| category | 卡1 | 卡2 | 卡3 | 卡4 |
|----------|-----|-----|-----|-----|
| savings/otherAsset/otherLiability | 本月收入 | 本月支出 | 本月净流入 | 交易数 |
| creditCard | 信用额度 | 已用额度 | 可用额度 | 账单日 |
| loan | 原始本金 | 剩余本金 | 月供 | 已还比例 |
| investment | 当前市值 | 投入成本 | 今年收益率 | 持仓交易数 |
| fixedDeposit | 本金 | 到期日 | 年化利率 | 本月收支 |
| goldFx | 现值 | 买入价 | 涨幅 | 本月收支 |
| realEstate | 现估值 | 买入价 | 增值率 | 本月收支 |

- [ ] **Step 1: 写失败测试** — 信用卡 + 贷款 + 储蓄三类型断言：

```dart
testWidgets('credit card stats: 额度/已用/可用/账单日', (tester) async {
  final account = Account(
    id: 'c1', name: '招行信用卡', accountType: AccountType.liability,
    category: AccountCategory.creditCard, currencyCode: 'CNY',
    initialBalanceCents: 0, currentBalanceCents: -30000,
    ownership: Ownership.personal, status: AccountStatus.active,
    creditLimitCents: 500000, creditBillingDay: 9,
  );
  await tester.pumpWidget(_detailHarness(account));
  await tester.pumpAndSettle();
  expect(find.text('信用额度'), findsOneWidget);
  expect(find.text('已用额度'), findsOneWidget);
  expect(find.text('可用额度'), findsOneWidget);
  expect(find.text('账单日'), findsOneWidget);
});

testWidgets('loan stats: 原始/剩余/月供/已还比例', (tester) async {
  final account = Account(
    id: 'l1', name: '房贷', accountType: AccountType.liability,
    category: AccountCategory.loan, currencyCode: 'CNY',
    initialBalanceCents: 0, currentBalanceCents: 0,
    ownership: Ownership.personal, status: AccountStatus.active,
    loanOriginalCents: 100000000, loanRemainingCents: 60000000,
    loanMonthlyCents: 500000,
  );
  await tester.pumpWidget(_detailHarness(account));
  await tester.pumpAndSettle();
  expect(find.text('已还比例'), findsOneWidget);
  expect(find.text('40.0%'), findsOneWidget); // (100w-60w)/100w
});

testWidgets('savings stats: 本月收支 4 卡（默认）', (tester) async {
  final account = _savingsAccount();
  await tester.pumpWidget(_detailHarness(account));
  await tester.pumpAndSettle();
  expect(find.text('本月收入'), findsOneWidget);
  expect(find.text('本月支出'), findsOneWidget);
});
```

- [ ] **Step 2: 运行验证失败**

Run: `cd yucai/client && flutter test test/account/presentation/pages/account_detail_page_test.dart`
Expected: FAIL（当前 _statsRow 恒定 4 标签，无类型分支）

- [ ] **Step 3: 实现** — 重构 `_statsRow` 为按 category 生成 `(label, value)` 列表，复用现有 `DataCard` + Row 布局：

```dart
Widget _statsRow(List<Transaction> txns, MonthlySummary? summary) {
  final stats = _statsFor(a: _lastAccount!, txns: txns, summary: summary);
  // _lastAccount 见 Step 3 末尾说明（_body 缓存当前 account 供 _statsRow 用）
  return Row(
    children: [
      for (var i = 0; i < stats.length; i++)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 7,
              right: i == stats.length - 1 ? 0 : 7,
            ),
            child: DataCard(
              child: Column(
                children: [
                  Text(stats[i].$2,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(stats[i].$1,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

/// 类型专属 4 卡 (label, value)。储蓄类用通用收支；其余按现有字段。
List<(String, String)> _statsFor({
  required Account a,
  required List<Transaction> txns,
  required MonthlySummary? summary,
}) {
  switch (a.category) {
    case AccountCategory.creditCard:
      final limit = a.creditLimitCents;
      final used = a.currentBalanceCents.abs(); // 欠款为负，取绝对值
      final avail = (limit - used).clamp(0, limit);
      return [
        ('信用额度', _fmtSigned(limit)),
        ('已用额度', _fmtSigned(used)),
        ('可用额度', _fmtSigned(avail)),
        ('账单日', '${a.creditBillingDay ?? '-'}日'),
      ];
    case AccountCategory.loan:
      final orig = a.loanOriginalCents ?? 0;
      final remain = a.loanRemainingCents ?? 0;
      final repaidPct = orig > 0 ? ((orig - remain) / orig * 100) : 0.0;
      return [
        ('原始本金', _fmtSigned(orig)),
        ('剩余本金', _fmtSigned(remain)),
        ('月供', _fmtSigned(a.loanMonthlyCents ?? 0)),
        ('已还比例', '${repaidPct.toStringAsFixed(1)}%'),
      ];
    case AccountCategory.investment:
      return [
        ('当前市值', _fmtSigned(a.investMarketValueCents ?? 0)),
        ('投入成本', _fmtSigned(a.investCostCents ?? 0)),
        ('今年收益率', '${(a.investReturnYtd ?? 0).toStringAsFixed(2)}%'),
        ('持仓交易数', '${txns.length}'),
      ];
    case AccountCategory.fixedDeposit:
      return [
        ('本金', _fmtSigned(a.fixedPrincipalCents ?? 0)),
        ('到期日', _fmtDate(a.fixedMaturityDate)),
        ('年化利率', '${(a.interestRate ?? 0).toStringAsFixed(2)}%'),
        ('本月收支', _fmtSigned(summary?.netCents ?? 0)),
      ];
    case AccountCategory.goldFx:
      final cur = a.goldCurrentPriceCents ?? 0;
      final buy = a.goldBuyPriceCents ?? 0;
      final pct = buy > 0 ? (cur - buy) / buy * 100 : 0.0;
      return [
        ('现值', _fmtSigned((cur * (a.goldQuantity ?? 0)).toInt())),
        ('买入价', _fmtSigned(buy)),
        ('涨幅', '${pct.toStringAsFixed(2)}%'),
        ('本月收支', _fmtSigned(summary?.netCents ?? 0)),
      ];
    case AccountCategory.realEstate:
      final cur = a.estateCurrentValueCents ?? 0;
      final buy = a.estatePurchasePriceCents ?? 0;
      final pct = buy > 0 ? (cur - buy) / buy * 100 : 0.0;
      return [
        ('现估值', _fmtSigned(cur)),
        ('买入价', _fmtSigned(buy)),
        ('增值率', '${pct.toStringAsFixed(2)}%'),
        ('本月收支', _fmtSigned(summary?.netCents ?? 0)),
      ];
    case AccountCategory.savings:
    case AccountCategory.otherAsset:
    case AccountCategory.otherLiability:
      return [
        ('本月收入', _fmtSigned(summary?.incomeCents ?? 0)),
        ('本月支出', _fmtSigned(summary?.expenseCents ?? 0)),
        ('本月净流入', _fmtSigned(summary?.netCents ?? 0)),
        ('交易数', '${txns.length}'),
      ];
  }
}
```

> **`_lastAccount` 说明:** `_statsRow` 原签名不含 account。最小改动：在 `_body(Account a)`（L175）开头存 `Account? _lastAccount`（State 字段），`_statsRow` 读它。或更干净：把 `_statsRow` 签名改为 `_statsRow(Account a, List<Transaction> txns, MonthlySummary? summary)`，在 `_body` L189 调用处传 `a`。**推荐改签名**（避免 State 字段冗余）。执行器二选一，改签名更优。

- [ ] **Step 4: 运行测试通过 + analyze**

Run: `cd yucai/client && flutter test test/account/presentation/pages/account_detail_page_test.dart && flutter analyze`
Expected: PASS + 0 error

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/account_detail_page.dart \
        yucai/client/test/account/presentation/pages/account_detail_page_test.dart
git commit -m "feat(client): 详情 quick-stats 类型专属 4 卡（仅现有字段）"
```

---

## Task 6: 详情近期交易页码分页

**⚠️ 依赖 Task 5（同文件）。**

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_detail_page.dart`（`_recentTxnPanel` L498-528 + `_recentTxnRow` + State 加分页字段）
- Test: 同 account_detail_page_test.dart

**Interfaces:**
- Consumes: `List<Transaction>`（已加载的 account-scoped list）
- Produces: 无（纯 UI 分页，不触发新 RPC——近期交易 panel 用已加载列表切片）

**Why:** 当前 `_recentTxnPanel` 用 `txns.take(5)` 只显示前 5 条，无翻页。OD `.panel` 近期交易是 skel 占位（无分页示范），但 progress.md 要求页码分页（用户能翻看该账户全部近期交易）。

**设计:** 客户端分页（pageSize=5），panel 底部加「‹ 1/3 ›」页码行。State 加 `_recentPage`（int，从 0 起），`_recentTxnPanel` 切片 `txns.skip(page*5).take(5)`。

- [ ] **Step 1: 写失败测试** — 造 7 条交易，验证第 2 页显示剩余 2 条 + 页码"2/2"：

```dart
testWidgets('recent txn pagination: page 2 shows remaining + page indicator', (tester) async {
  final txns = List.generate(7, (i) => _txn(id: 't$i', desc: '交易$i', amount: -1000));
  await tester.pumpWidget(_detailHarnessWithTxns(_savingsAccount(), txns));
  await tester.pumpAndSettle();
  expect(find.text('交易0'), findsOneWidget); // page 1 (0-4)
  expect(find.text('2/2'), findsOneWidget);  // ceil(7/5)=2 页
  // 点下一页
  await tester.tap(find.byTooltip('下一页'));
  await tester.pumpAndSettle();
  expect(find.text('交易5'), findsOneWidget); // page 2 (5-6)
  expect(find.text('交易0'), findsNothing);
});
```

> `_txn` / `_detailHarnessWithTxns` 测试辅助：若现有 harness 用 `TransactionsLoaded(transactions: [...])`，扩展支持传 txns。

- [ ] **Step 2: 运行验证失败**

Run: `cd yucai/client && flutter test test/account/presentation/pages/account_detail_page_test.dart`
Expected: FAIL（无翻页控件 / 无"2/2"）

- [ ] **Step 3: 实现** — State 加字段 + 分页 helper + 重构 panel：

State 类（L38 `_AccountDetailPageState`）加：
```dart
static const int _recentPageSize = 5;
int _recentPage = 0;
```

`_refreshTxn`（L691）或加载新账户时重置页码——在 `_body` 开头或 `initState` 重置。简单做法：`_body` 里若 account id 变化则 `_recentPage = 0`（用 State 字段 `_lastAccountId` 比较）。或直接在 `_recentTxnPanel` 入口 clamp。最小可行：分页按钮在越界时 clamp。

重构 `_recentTxnPanel`：
```dart
Widget _recentTxnPanel(List<Transaction> txns) {
  final pageCount = (txns.length / _recentPageSize).ceil();
  if (_recentPage >= pageCount && pageCount > 0) _recentPage = pageCount - 1;
  if (pageCount == 0) _recentPage = 0;
  final start = _recentPage * _recentPageSize;
  final page = txns.skip(start).take(_recentPageSize).toList();
  return DataCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('近期交易',
                style: TextStyle(fontWeight: FontWeight.w600)),
            Text('${txns.length} 笔',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (page.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('暂无交易',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
          )
        else
          for (final t in page) _recentTxnRow(t),
        if (pageCount > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          _recentPager(pageCount),
        ],
      ],
    ),
  );
}

Widget _recentPager(int pageCount) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: '上一页',
        icon: const Icon(Icons.chevron_left, size: 20, color: AppColors.muted),
        onPressed: _recentPage > 0
            ? () => setState(() => _recentPage--)
            : null,
      ),
      Text('${_recentPage + 1}/$pageCount',
          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      IconButton(
        tooltip: '下一页',
        icon: const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
        onPressed: _recentPage < pageCount - 1
            ? () => setState(() => _recentPage++)
            : null,
      ),
    ],
  );
}
```

> `_body`（L175）调用处 `_recentTxnPanel(txns)` 不变（签名未改）。

- [ ] **Step 4: 运行测试通过 + analyze**

Run: `cd yucai/client && flutter test test/account/presentation/pages/account_detail_page_test.dart && flutter analyze`
Expected: PASS + 0 error

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/account_detail_page.dart \
        yucai/client/test/account/presentation/pages/account_detail_page_test.dart
git commit -m "feat(client): 详情近期交易页码分页（5/页）"
```

---

## Task 7: 详情 info-card 独立字段表

**⚠️ 依赖 Task 6（同文件）。**

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_detail_page.dart`（新建 `_infoCard` + `_body` 追加；精简 `_heroFields` 为 4 字段）
- Test: 同 account_detail_page_test.dart

**Interfaces:**
- Consumes: `Account` 全字段（institution/cardNumberTail/openingDate/interestRate/initialBalanceCents/currentBalanceCents/currencyCode/notes + 类型专属）
- Produces: 无

**Why:** OD `.info-card` 是独立 3 列网格（12 cell：开户机构/卡号尾号/账户类型/初始余额/当前余额/累计利息/年化利率/开户日期/币种/备注/安全等级/最后更新），在 hero 下方、双栏下方。当前详情页字段全挤在 hero 的 `_heroFields`（4 列），无独立信息卡。按 OD：hero-fields 精简 4 字段，info-card 展开全字段表。

**决策:** 「累计利息」「安全等级」「最后更新」无数据源（entity 无对应字段）→ 不渲染（仅展示 entity 有的字段）。

- [ ] **Step 1: 写失败测试** — 验证 info-card 渲染开户机构 + 卡号尾号 + 初始余额：

```dart
testWidgets('info-card shows institution + card tail + initial balance', (tester) async {
  final account = Account(
    id: 'a1', name: '招行储蓄', accountType: AccountType.asset,
    category: AccountCategory.savings, currencyCode: 'CNY',
    initialBalanceCents: 120000000, currentBalanceCents: 128540000,
    ownership: Ownership.personal, status: AccountStatus.active,
    institution: '招商银行', cardNumberTail: '2840',
    interestRate: 1.9, openingDate: DateTime(2022, 3, 15),
  );
  await tester.pumpWidget(_detailHarness(account));
  await tester.pumpAndSettle();
  expect(find.text('账户信息'), findsOneWidget);       // section-label
  expect(find.text('开户机构'), findsOneWidget);
  expect(find.text('招商银行'), findsOneWidget);
  expect(find.text('卡号尾号'), findsOneWidget);
  expect(find.text('尾号 2840'), findsOneWidget);
});
```

- [ ] **Step 2: 运行验证失败**

Run: `cd yucai/client && flutter test test/account/presentation/pages/account_detail_page_test.dart`
Expected: FAIL（无"账户信息"section / 无"开户机构"）

- [ ] **Step 3: 实现** — 新增 `_infoCard(Account a)`，在 `_body`（L184 ListView children）末尾（类型专属 panel 之前）追加：

```dart
const SizedBox(height: AppSpacing.lg),
_infoCard(a),
const SizedBox(height: AppSpacing.lg),
```

`_infoCard` 实现（3 列网格，desktop >600 用 3 列否则 2 列，对齐 OD `.info-grid` + 响应式断点）：
```dart
/// 账户信息卡：独立 3 列字段表（对齐 OD .info-card / .info-grid）。
/// 仅展示 entity 已有字段；累计利息/安全等级/最后更新无数据源不渲染。
Widget _infoCard(Account a) {
  final cells = <(String, String)>[];
  void add(String label, String? v) {
    if (v != null && v.isNotEmpty) cells.add((label, v));
  }
  void addNum(String label, int? cents) {
    if (cents != null && cents != 0) cells.add((label, _fmtSigned(cents)));
  }
  add('开户机构', a.institution.isEmpty ? null : a.institution);
  add('卡号尾号', a.cardNumberTail.isEmpty ? null : '尾号 ${a.cardNumberTail}');
  add('账户类型', '${a.category.label} · ${_typeSuffix(a)}');
  addNum('初始余额', a.initialBalanceCents == 0 ? null : a.initialBalanceCents);
  addNum('当前余额', a.currentBalanceCents);
  add('年化利率', a.interestRate == null ? null : '${a.interestRate!.toStringAsFixed(2)}%');
  add('开户日期', a.openingDate == null ? null : _fmtDate(a.openingDate!));
  add('币种', '${a.currencyCode} ${_currencyName(a.currencyCode)}');
  add('备注', a.notes.isEmpty ? null : a.notes);
  // 类型专属补充字段
  switch (a.category) {
    case AccountCategory.creditCard:
      add('账单日', a.creditBillingDay == null ? null : '${a.creditBillingDay}日');
      add('还款日', a.creditRepaymentDay == null ? null : '${a.creditRepaymentDay}日');
      addNum('年费', a.creditAnnualFeeCents);
    case AccountCategory.loan:
      addNum('原始本金', a.loanOriginalCents);
      addNum('剩余本金', a.loanRemainingCents);
      addNum('月供', a.loanMonthlyCents);
      add('下次还款', a.loanNextPaymentDate == null ? null : _fmtDate(a.loanNextPaymentDate!));
    case AccountCategory.investment:
      addNum('市值', a.investMarketValueCents);
      addNum('成本', a.investCostCents);
      add('今年收益率', a.investReturnYtd == null ? null : '${a.investReturnYtd!.toStringAsFixed(2)}%');
    case AccountCategory.fixedDeposit:
      addNum('本金', a.fixedPrincipalCents);
      add('起息日', a.fixedStartDate == null ? null : _fmtDate(a.fixedStartDate!));
      add('到期日', a.fixedMaturityDate == null ? null : _fmtDate(a.fixedMaturityDate!));
      add('期限', a.fixedTermMonths == null ? null : '${a.fixedTermMonths}月');
    case AccountCategory.goldFx:
      add('品种', a.goldProductType.isEmpty ? null : a.goldProductType);
      add('数量', a.goldQuantity == null ? null : a.goldQuantity!.toStringAsFixed(3));
      addNum('买入价', a.goldBuyPriceCents);
      addNum('现价', a.goldCurrentPriceCents);
    case AccountCategory.realEstate:
      addNum('买入价', a.estatePurchasePriceCents);
      addNum('现估值', a.estateCurrentValueCents);
      add('买入日期', a.estatePurchaseDate == null ? null : _fmtDate(a.estatePurchaseDate!));
      add('折旧率', a.estateDepreciationRate == null ? null : '${a.estateDepreciationRate!.toStringAsFixed(2)}%');
    case AccountCategory.savings:
    case AccountCategory.otherAsset:
    case AccountCategory.otherLiability:
      break;
  }
  return DataCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('账户信息', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (ctx, c) {
            final cols = c.maxWidth > 600 ? 3 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              mainAxisSpacing: 14,
              crossAxisSpacing: 12,
              childAspectRatio: 2.8,
              children: [for (final cell in cells) _infoCell(cell.$1, cell.$2)],
            );
          },
        ),
      ],
    ),
  );
}

Widget _infoCell(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: AppColors.muted, letterSpacing: 0.07)),
        const SizedBox(height: 5),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14,
                color: AppColors.fg,
                fontWeight: FontWeight.w500,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );

String _typeSuffix(Account a) =>
    a.accountType == AccountType.liability ? '负债' : '资产';

String _currencyName(String code) => switch (code) {
      'CNY' => '人民币',
      'USD' => '美元',
      'EUR' => '欧元',
      'HKD' => '港币',
      _ => '',
    };
```

> hero-fields（`_heroFields` L331）**保留不变**（OD 的 hero-fields 也是 4 精简字段，与 info-card 互补：hero 看概览，info-card 看全字段）。若执行器认为重复，可把 hero-fields 精简到 3（利率/开户日期/币种），但非必须。

- [ ] **Step 4: 运行测试通过 + analyze**

Run: `cd yucai/client && flutter test test/account/presentation/pages/account_detail_page_test.dart && flutter analyze`
Expected: PASS + 0 error

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/account_detail_page.dart \
        yucai/client/test/account/presentation/pages/account_detail_page_test.dart
git commit -m "feat(client): 详情 info-card 独立字段表（对齐 OD）"
```

---

## Task 8: 详情收支统计饼图 + 移除 content 内 _quickActions

**⚠️ 依赖 Task 7（同文件）。**

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_detail_page.dart`（`_summaryPanel` L568-601 改饼图；`_body` L191-209 移除 `_quickActions`；可删 `_quickActions`/`_actionBtn` 方法）
- Test: 同 account_detail_page_test.dart

**Interfaces:**
- Consumes: `MonthlySummary.byDay`（`List<DailySummary>`，每含 `byCategory: List<CategoryTotal>`）、`CategoryTotal.{name, accountType, amountCents}`
- Produces: 无

**Why:** 两个决策合一：
- **决策①加饼图**：OD `.pie-wrap` 用饼图 + legend 展示收支分类。需客户端从 `summary.byDay` 聚合月度 byCategory（聚合 expense 类的 amountCents）。
- **决策②移除 _quickActions**：操作集中在 AppBar（编辑/记一笔/转账/更多已存在 L82-134），content 内 `_quickActions` 重复，移除。

- [ ] **Step 1: 写失败测试** — 验证饼图渲染 + legend 有分类项 + _quickActions 已移除：

```dart
testWidgets('summary panel renders pie + legend; no quick actions card', (tester) async {
  final summary = MonthlySummary(
    year: 2026, month: 6, expenseCents: 18000, incomeCents: 24000, netCents: 6000,
    byDay: [
      DailySummary(date: '2026-06-01', totalIncomeCents: 0, byCategory: [
        CategoryTotal(categoryId: 'food', name: '餐饮', accountType: 'expense', amountCents: 12000),
        CategoryTotal(categoryId: 'tran', name: '交通', accountType: 'expense', amountCents: 6000),
      ]),
    ],
  );
  await tester.pumpWidget(_detailHarnessWithSummary(_savingsAccount(), summary));
  await tester.pumpAndSettle();
  expect(find.byType(CustomPaint), findsWidgets); // 饼图（CustomPaint 绘制）
  expect(find.text('餐饮'), findsOneWidget);       // legend
  expect(find.text('交通'), findsOneWidget);
  expect(find.text('快捷操作'), findsNothing);     // _quickActions 已移除
});
```

> 饼图用 `CustomPaint` + `Paint`..style=stroke 画环（OD 是 SVG circle + stroke-dasharray）。`findsWidgets` ≥1 即可。

- [ ] **Step 2: 运行验证失败**

Run: `cd yucai/client && flutter test test/account/presentation/pages/account_detail_page_test.dart`
Expected: FAIL（无饼图 / "快捷操作"仍存在）

- [ ] **Step 3: 实现** — 三处改动：

**(a) 新增月度 byCategory 聚合 helper**（纯客户端，遍历 byDay）：
```dart
/// 从 summary.byDay 聚合月度 expense 分类（饼图用）。
List<CategoryTotal> _monthExpenseByCategory(MonthlySummary? summary) {
  if (summary == null) return const [];
  final merged = <String, CategoryTotal>{};
  for (final day in summary.byDay) {
    for (final c in day.byCategory) {
      if (c.accountType != 'expense' || c.amountCents == 0) continue;
      final existing = merged[c.categoryId];
      if (existing == null) {
        merged[c.categoryId] = CategoryTotal(
          categoryId: c.categoryId,
          name: c.name,
          accountType: c.accountType,
          amountCents: c.amountCents,
        );
      } else {
        merged[c.categoryId] = CategoryTotal(
          categoryId: existing.categoryId,
          name: existing.name,
          accountType: existing.accountType,
          amountCents: existing.amountCents + c.amountCents,
        );
      }
    }
  }
  final list = merged.values.toList()
    ..sort((a, b) => b.amountCents.compareTo(a.amountCents));
  return list;
}
```

**(b) 重写 `_summaryPanel` 为饼图 + legend**（替换 L568-601）：
```dart
/// 收支统计 panel：饼图 + legend（对齐 OD .pie-wrap）。
/// expense 分类从 summary.byDay 聚合；无数据时显占位。
Widget _summaryPanel(MonthlySummary? summary) {
  final cats = _monthExpenseByCategory(summary);
  final total = cats.fold<int>(0, (s, c) => s + c.amountCents);
  return DataCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('收支统计',
                style: TextStyle(fontWeight: FontWeight.w600)),
            Text('本月',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (cats.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('本月暂无支出',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
          )
        else ...[
          _pieChart(cats, total),
          const SizedBox(height: AppSpacing.md),
          for (final c in cats) _legendRow(c, total),
        ],
      ],
    ),
  );
}

Widget _pieChart(List<CategoryTotal> cats, int total) {
  return Center(
    child: SizedBox(
      width: 128,
      height: 128,
      child: CustomPaint(
        painter: _DonutPainter(cats, total),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_fmtSigned(total),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabularFigures)),
              const Text('支出',
                  style: TextStyle(color: AppColors.muted, fontSize: 10)),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _legendRow(CategoryTotal c, int total) {
  final pct = total > 0 ? (c.amountCents / total * 100) : 0.0;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: _categoryColor(c.categoryId),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        Text(c.name.isEmpty ? '未分类' : c.name,
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const Spacer(),
        Text('${pct.toStringAsFixed(0)}% · ${_fmtSigned(c.amountCents)}',
            style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    ),
  );
}

/// 分类色：按 categoryId 哈希到御财调色板（稳定着色）。
Color _categoryColor(String id) {
  const palette = [
    Color(0xFFB08D57), Color(0xFFC4544D), Color(0xFF2D8A6E),
    Color(0xFF3B6FB0), Color(0xFF8A6FB0), Color(0xFFB08D33),
  ];
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}
```

**`_DonutPainter`**（文件底部新增，与 `_AccountDetailPageState` 同文件顶层）：
```dart
class _DonutPainter extends CustomPainter {
  _DonutPainter(this.cats, this.total);
  final List<CategoryTotal> cats;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const thickness = 16.0;
    // 背景环
    canvas.drawCircle(
        center,
        radius - thickness / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..color = const Color(0xFFEFECE4));
    if (total == 0) return;
    // 分类扇区
    final rect = Rect.fromCircle(center: center, radius: radius - thickness / 2);
    var start = -pi / 2; // 12 点起
    for (final c in cats) {
      final sweep = (c.amountCents / total) * 2 * pi;
      canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness
            ..color = _categoryColorForPaint(c.categoryId));
      start += sweep;
    }
  }

  Color _categoryColorForPaint(String id) {
    const palette = [
      Color(0xFFB08D57), Color(0xFFC4544D), Color(0xFF2D8A6E),
      Color(0xFF3B6FB0), Color(0xFF8A6FB0), Color(0xFFB08D33),
    ];
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return palette[h % palette.length];
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.total != total || old.cats.length != cats.length;
}
```

> 文件顶部需 `import 'dart:math' show pi;`（或 `import 'dart:math';`）。`_categoryColor`（State 方法）与 `_DonutPainter._categoryColorForPaint` 重复着色逻辑——可接受（Painter 不能访问 State 方法；保持两处一致）。`CategoryTotal` 已 import（value_objects.dart，L7 已 import value_objects）。

**(c) 移除 content 内 _quickActions** — 改 `_body` L191-209 的右栏 Column：

```dart
// 右栏：收支统计饼图（移除原 _quickActions——操作集中在 AppBar，对齐 OD）。
Expanded(
  child: _summaryPanel(summary),
),
```

并把双栏改为左大右小（OD `.cols` 1.5fr:1fr）。用 `Row` + `Expanded(flex: 3, ...)` + `Expanded(flex: 2, ...)`：
```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(flex: 3, child: _recentTxnPanel(txns)),
    const SizedBox(width: AppSpacing.lg),
    Expanded(flex: 2, child: _summaryPanel(summary)),
  ],
),
```

**删除** `_quickActions`（L606-626）+ `_actionBtn`（L628-650）方法（不再使用）。

- [ ] **Step 4: 运行测试通过 + 全页 analyze**

Run: `cd yucai/client && flutter test test/account/presentation/pages/account_detail_page_test.dart && flutter analyze`
Expected: PASS + 0 error（若有 `_quickActions`/`_actionBtn` 未使用 lint，确认已删；`dart:math` pi 已 import）

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/account_detail_page.dart \
        yucai/client/test/account/presentation/pages/account_detail_page_test.dart
git commit -m "feat(client): 详情收支统计饼图 + 移除 content 快捷操作（对齐 OD）"
```

---

## Self-Review

**1. Spec coverage（P0 完善 9 任务 → 本计划 8 任务）:**
- ✅ 列表 card 副标题 → Task 1
- ✅ 统计 SQL A1 → Task 2
- ✅ 详情 Hero name+sub+balance → Task 4（hero-name + hero-org）
- ✅ quick-stats 类型专属 4 卡 → Task 5
- ✅ 近期交易页码分页 → Task 6
- ✅ info-card 字段表 → Task 7
- ✅ actions-card → **决策②移除**（并入 Task 8，遵 OD topbar-only）
- ✅ topbar 半透明米色+毛玻璃 → Task 3
- ✅ 饼图 → **决策①新增**（Task 8，遵 OD .pie-wrap）
- ⏭️ 汇率开源 API → **决策④拆独立 spec**（本计划不含）

**2. Placeholder scan:** 无 TBD/TODO；每任务 Step 3 给完整可粘贴代码；测试给真实断言。`_harness`/`_detailHarness`/`_txn`/`_savingsAccount` 测试辅助标注"复用现有或内联最小构造"——这是测试脚手架惯例，非实现占位。

**3. 类型一致性:**
- `_subline(Account)`（Task 1）独立方法，不与 `_sublineWidget`（已存在，类型专属副信息）冲突——副标题(subtitle)与副信息(subline)是 card 两个不同行，共存。
- `_statsFor` 返回 `List<(String, String)>`（Task 5），`_statsRow` 消费——签名一致。
- `_monthExpenseByCategory` 返回 `List<CategoryTotal>`（Task 8），`_pieChart`/`_legendRow` 消费——一致。
- `_DonutPainter` 与 `_categoryColor` 着色逻辑一致（palette + 哈希）。
- Task 4-8 同文件串行，无并行写冲突。

**4. 串行约束已标注:** Task 4-8 header 均有「⚠️ 依赖 Task N-1（同文件）」。
