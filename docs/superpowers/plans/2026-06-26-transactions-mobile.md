# 交易页移动端三件套 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `transactions_page` mobile 分支对齐 OD `mobile/transactions.html` 三件套:交易卡(分类 chip + HH:MM + 账户首字母方块)、筛选底部 sheet、month-bar + 可展开 sum-card。

**Architecture:** 在 `transactions_page.dart` 内新增 3 个 mobile 专属 widget(`_MobileAppBar`/`_MobileFilterSheet`/`_MobileHeader`)+ 改 `_MobileTxnCard`,`_Content.build` 用 `Breakpoints.of(context)==Breakpoint.mobile` 分支:mobile 渲染 `_MobileAppBar`+`_MobileHeader`+`_MobileList`(隐藏 desktop `_Header`/`SummaryCard`/`TxnFilterBar`)。复用既有 `_AccountTag`/`_CategoryChip`/`_TxIconBox`/`inferFlavour`/`TxnFilterState`/`TxnTypeFilter`/`FilterOption`/`ResponsiveLayout`。

**Tech Stack:** Flutter 3.44 + flutter_bloc + 御财 token(AppColors/AppSpacing/AppRadius/AppTypography)。无新依赖,硬编码中文(御财 client 无 i18n)。

## Global Constraints

- **mobile 判定**:`Breakpoints.of(context) == Breakpoint.mobile`(`responsive_layout.dart`,与 `ResponsiveLayout` 同源)。widget test 用 `tester.view.physicalSize = Size(375, 900)` + `devicePixelRatio = 1.0` + `addTearDown(resetPhysicalSize/resetDevicePixelRatio)` 触发 mobile。
- **复用既有**(不重写):`_AccountTag`(label+account,L921)、`_CategoryChip`(account,L877)、`_TxIconBox`(flavour,L845)、`inferFlavour(txn)`(top fn)、`TxnFilterState`/`TxnTypeFilter`/`FilterOption`(`filter_bar.dart`)、`_formatCents`/`_amountColor`(top fn,L附近)、`MonthlySummary`(domain)。
- **数据源**:`Transaction.transactionTime`(DateTime?,HH:MM)、`account.category.label`(分类 chip 文本)、`MonthlySummary.{income,expense,net,dailyAvg}Cents`(汇总)。
- **范围**:只改 `transactions_page.dart` + 其 test。**不动** desktop/tablet(`_TxCard`/`_TxTableRow`/`_Header`/`SummaryCard`/`TxnFilterBar` 在 tablet/desktop 仍用)、不动 filter_bar.dart / responsive_layout.dart。
- **御财 token**:income `AppColors.positive`/expense `AppColors.negative`/transfer `AppColors.accent`/`accentSoft`、border `AppColors.border`、mono `AppTypography.tabularFigures`。
- **分支**:`transactions-mobile`,BASE `d28c173`(spec commit)。

---

### Task 1: `_MobileTxnCard` 改(副行首字母方块+HH:MM + 右侧分类 chip)

**Files:**
- Modify: `yucai/client/lib/transaction/presentation/pages/transactions_page.dart`(`_MobileTxnCard` L1070-1200)
- Test: `yucai/client/test/transaction/presentation/pages/transactions_page_test.dart`

**Interfaces:**
- Consumes: 既有 `_AccountTag`/`_CategoryChip`/`_TxIconBox`/`inferFlavour`/`_formatCents`/`_amountColor`;`Transaction.transactionTime`
- Produces: `_MobileTxnCard` 副行(`_AccountTag` + `· HH:MM`)+ 右侧(`_CategoryChip` + 金额)

- [ ] **Step 1: 写失败 test**

在 `transactions_page_test.dart` 的 `main()` 内追加(复用既有 harness 的 pump 模式;若文件无 mobile viewport 先例,参考 `account_detail_page_test.dart` 的 `tester.view.physicalSize` 模式):

```dart
  testWidgets('mobile txn card: 分类 chip + HH:MM + 账户首字母方块', (t) async {
    t.view.physicalSize = const Size(375, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t); // 既有 harness,注入含分类账户 + transactionTime 的交易
    await t.pumpAndSettle();
    // 分类 chip(非转账交易的 category.label,如「餐饮」对应 expense 账户 category)
    expect(find.byType(_CategoryChip), findsWidgets,
        reason: 'mobile 交易卡右侧应渲染分类 chip');
    // HH:MM 时间(transactionTime)
    expect(find.textContaining(RegExp(r'^\d{2}:\d{2}$')), findsWidgets,
        reason: 'mobile 副行应显示 HH:MM');
    // 账户首字母方块(_AccountTag 内 20×20 Container)
    expect(find.byType(_AccountTag), findsWidgets,
        reason: 'mobile 副行应含账户首字母方块');
  });
```

> 注:`_CategoryChip`/`_AccountTag` 是私有类,test 需 `import` transactions_page 或用 `find.byWidgetPredicate`。若私有类 test 不可见,改用 `find.text(categoryLabel)` + `find.text('· HH:MM')` + `find.text(accountName)` 文本断言。**优先用文本断言**(不依赖私有类型可见性)。

- [ ] **Step 2: 运行测试，确认其失败**

Run: `flutter test test/transaction/presentation/pages/transactions_page_test.dart -F "mobile txn card"`
Expected: FAIL(当前副行是 `日期·账户` Text,无分类 chip / HH:MM 在副行 / 首字母方块)

- [ ] **Step 3: 改 `_MobileTxnCard.build`**

在 `_MobileTxnCard` class 内,`_isTransfer` getter 之后,加分类账户解析 + HH:MM getter:

```dart
  /// 分类账户:非转账交易的 expense/income 对方账户(account-as-category)。
  /// 转账无分类账户,返回 null(_CategoryChip 隐藏)。
  Account? get _categoryAccount {
    for (final e in txn.entries) {
      final a = accountOf(e.accountId);
      if (a != null &&
          (a.accountType == AccountType.expense ||
              a.accountType == AccountType.income)) {
        return a;
      }
    }
    return null;
  }

  /// HH:MM:优先 transactionTime,回退 transactionDate。
  String get _hhmm {
    final dt = txn.transactionTime ?? txn.transactionDate;
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
```

把 `build` 内副行(原 `if (isTransfer) Row(_AccountTag×2) else Text(日期·账户)`)+ 右侧(原单个 `Text(_formatCents)`)替换为:

```dart
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.description.isEmpty ? '(无描述)' : txn.description,
                    style: const TextStyle(
                        color: AppColors.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  if (isTransfer)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                            child: _AccountTag(
                                label: fromLabel,
                                account: accountOf(txn.entries
                                    .firstWhere(
                                        (e) => e.creditCents > 0,
                                        orElse: () => txn.entries.first)
                                    .accountId))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward,
                              size: 14, color: AppColors.muted),
                        ),
                        Flexible(
                            child: _AccountTag(
                                label: toLabel,
                                account: accountOf(txn.entries
                                    .firstWhere(
                                        (e) => e.debitCents > 0,
                                        orElse: () => txn.entries.last)
                                    .accountId))),
                        if (txn.transactionTime != null) ...[
                          const SizedBox(width: 6),
                          Text('· $_hhmm',
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                        ],
                      ],
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (singleLabel.isNotEmpty)
                          Flexible(
                              child: _AccountTag(
                                  label: singleLabel,
                                  account: accountOf(txn.entries
                                      .firstWhere((e) =>
                                          accountOf(e.accountId)?.accountType ==
                                              AccountType.asset)
                                      .accountId))),
                        if (singleLabel.isNotEmpty &&
                            txn.transactionTime != null)
                          const SizedBox(width: 6),
                        if (txn.transactionTime != null)
                          Text('· $_hhmm',
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                ],
              ),
```

右侧(原 `Text(_formatCents(amount, signed: true), ...)` 单个)替换为 Column(分类 chip + 金额):

```dart
            // 右侧:分类 chip + 金额
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _CategoryChip(account: _categoryAccount),
                const SizedBox(height: 4),
                Text(
                  _formatCents(amount, signed: true),
                  style: TextStyle(
                    color: _amountColor(flavour),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ],
            ),
```

> 注:`singleLabel` 计算逻辑(build 顶部既有,L1114-1127)保留;`fromLabel`/`toLabel` 同理保留。改动只在副行 Row 结构 + 右侧 Column。若 `txn.transactionTime == null`(旧数据无时间),回退 transactionDate(见 `_hhmm`)—— `if (txn.transactionTime != null)` 的 `· HH:MM` 在 null 时不显示,避免重复(transactionDate 已隐含日期)。

- [ ] **Step 4: 运行测试，确认其通过**

Run: `flutter test test/transaction/presentation/pages/transactions_page_test.dart`
Expected: PASS(新 test + 既有)

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/transaction/presentation/pages/transactions_page.dart yucai/client/test/transaction/presentation/pages/transactions_page_test.dart
git commit -m "feat(txn-mobile): _MobileTxnCard 副行首字母方块+HH:MM + 右侧分类 chip"
```

---

### Task 2: `_MobileFilterSheet` + `_MobileAppBar`(filterBtn 触发底部 sheet)

**Files:**
- Modify: `yucai/client/lib/transaction/presentation/pages/transactions_page.dart`(新增 `_MobileFilterSheet` + `_MobileAppBar` widget)
- Test: 同 Task 1

**Interfaces:**
- Consumes: `TxnFilterState`/`TxnTypeFilter`/`FilterOption`(filter_bar.dart)、`accountOptions`/`categoryOptions`/`monthOptions`(`_Content` 算)、`onFilterChanged`
- Produces: `_MobileFilterSheet`(StatefulWidget,showModalBottomSheet 内容)、`_MobileAppBar`(标题+搜索+filterBtn)

- [ ] **Step 1: 写失败 test**

```dart
  testWidgets('mobile: filterBtn tap 弹筛选 sheet + 应用关闭', (t) async {
    t.view.physicalSize = const Size(375, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    // filterBtn(Tooltip「筛选」)
    final filterBtn = find.byTooltip('筛选');
    expect(filterBtn, findsOneWidget, reason: 'mobile appbar 应有筛选 btn');
    await t.tap(filterBtn);
    await t.pumpAndSettle();
    // sheet 弹出
    expect(find.text('筛选交易'), findsOneWidget, reason: '底部 sheet 标题');
    expect(find.text('应用筛选'), findsOneWidget, reason: '应用按钮');
    await t.tap(find.text('应用筛选'));
    await t.pumpAndSettle();
    expect(find.text('筛选交易'), findsNothing, reason: '应用后 sheet 关闭');
  });
```

- [ ] **Step 2: 运行测试，确认其失败**

Run: `flutter test test/transaction/presentation/pages/transactions_page_test.dart -F "filterBtn tap"`
Expected: FAIL(当前无 `_MobileAppBar`/filterBtn,`find.byTooltip('筛选')` 找不到)

- [ ] **Step 3: 实现 `_MobileFilterSheet` + `_MobileAppBar`**

在 `transactions_page.dart`(文件末尾或 `_MobileTxnCard` 之后)新增两个 widget:

```dart
/// mobile 筛选底部 sheet(filterBtn 触发)。
/// 内部持临时 filter state,应用时一次性回传 onApply。
class _MobileFilterSheet extends StatefulWidget {
  const _MobileFilterSheet({
    required this.initial,
    required this.accountOptions,
    required this.categoryOptions,
    required this.monthOptions,
    required this.onApply,
  });

  final TxnFilterState initial;
  final List<FilterOption> accountOptions;
  final List<FilterOption> categoryOptions;
  final List<FilterOption> monthOptions;
  final ValueChanged<TxnFilterState> onApply;

  @override
  State<_MobileFilterSheet> createState() => _MobileFilterSheetState();
}

class _MobileFilterSheetState extends State<_MobileFilterSheet> {
  late TxnFilterState _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  Widget _chipGroup({
    required String label,
    required List<FilterOption> options,
    required String? selectedId, // null = 全部
    required ValueChanged<String?> onSelect, // null = 选「全部」
    String allLabel = '全部',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip(allLabel, selectedId == null,
                  () => onSelect(null)),
              for (final o in options)
                _filterChip(o.label, selectedId == o.id, () => onSelect(o.id)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String text, bool on, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: on ? AppColors.accentSoft : AppColors.surfaceAlt,
          border: Border.all(
              color: on ? const Color(0xFFE0D2B6) : AppColors.border),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(text,
            style: TextStyle(
                color: on ? const Color(0xFF7A5F33) : AppColors.fg,
                fontSize: 13.5,
                fontWeight: on ? FontWeight.w500 : FontWeight.w400)),
      ),
    );
  }

  Widget _typeGroup() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 9),
            child: Text('交易类型',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tf in TxnTypeFilter.values)
                _filterChip(tf.label, _draft.type == tf,
                    () => setState(() => _draft = _draft.copyWith(type: tf))),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Text('筛选交易',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Georgia')),
              _typeGroup(),
              _chipGroup(
                label: '账户',
                options: widget.accountOptions,
                selectedId: _draft.accountId,
                onSelect: (id) =>
                    setState(() => _draft = _draft.copyWith(accountId: id)),
                allLabel: '全部账户',
              ),
              _chipGroup(
                label: '分类',
                options: widget.categoryOptions,
                selectedId: _draft.category,
                onSelect: (id) =>
                    setState(() => _draft = _draft.copyWith(category: id)),
                allLabel: '全部分类',
              ),
              _chipGroup(
                label: '月份',
                options: widget.monthOptions,
                selectedId: _draft.month,
                onSelect: (id) =>
                    setState(() => _draft = _draft.copyWith(month: id)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _draft = const TxnFilterState()),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.smBorder),
                      ),
                      child: const Text('重置'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.onApply(_draft),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.smBorder),
                      ),
                      child: const Text('应用筛选'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// mobile appbar:标题 + 搜索 btn + 筛选 btn。
class _MobileAppBar extends StatelessWidget {
  const _MobileAppBar({required this.onFilter});
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Text('交易管理',
              style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Georgia')),
          const Spacer(),
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search, size: 21),
            onPressed: () {}, // 搜索本期占位(P2 search)
          ),
          IconButton(
            tooltip: '筛选',
            icon: const Icon(Icons.tune, size: 21),
            onPressed: onFilter,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试，确认其通过**

Run: `flutter test test/transaction/presentation/pages/transactions_page_test.dart -F "filterBtn tap"`
Expected: PASS(test 在 Task 4 组装后才完整工作 —— 此 step 若 `pumpPage` 默认 viewport > mobile,需先手动 `find.byTooltip` 在 desktop 不存在 → test 仍 fail。**Task 2 仅实现 widget + 单元 sheet 测试,组装在 Task 4**)。

> 若 Step 4 因 `_MobileAppBar` 未在 `_Content` 组装而 fail,**此 test 标 `skip('组装在 Task 4')` 临时跳过,Task 4 组装后去掉 skip**。或把 test 改为直接 `pump` `_MobileFilterSheet` 单元测试(独立于 `_Content`):

```dart
  testWidgets('_MobileFilterSheet 渲染 + 应用回调', (t) async {
    TxnFilterState? applied;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _MobileFilterSheet(
          initial: const TxnFilterState(),
          accountOptions: const [FilterOption('a1', '招商银行')],
          categoryOptions: const [FilterOption('food', '餐饮')],
          monthOptions: const [FilterOption('2026-06', '2026年6月')],
          onApply: (s) => applied = s,
        ),
      ),
    ));
    expect(find.text('筛选交易'), findsOneWidget);
    expect(find.text('应用筛选'), findsOneWidget);
    await t.tap(find.text('应用筛选'));
    await t.pumpAndSettle();
    expect(applied, isNotNull);
  });
```

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/transaction/presentation/pages/transactions_page.dart yucai/client/test/transaction/presentation/pages/transactions_page_test.dart
git commit -m "feat(txn-mobile): _MobileFilterSheet 底部 sheet + _MobileAppBar filterBtn"
```

---

### Task 3: `_MobileHeader`(month-bar prev/next + 可展开 sum-card)

**Files:**
- Modify: `yucai/client/lib/transaction/presentation/pages/transactions_page.dart`(新增 `_MobileHeader`)
- Test: 同 Task 1

**Interfaces:**
- Consumes: `TxnFilterState`(filter.month)、`MonthlySummary`(income/expense/net/dailyAvg)、`onFilterChanged`(切月)
- Produces: `_MobileHeader`(month-bar + 可展开 sum-card)

- [ ] **Step 1: 写失败 test**

```dart
  testWidgets('_MobileHeader: month-bar 文本 + sum-card 三列 + 展开日均', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _MobileHeader(
          filter: const TxnFilterState(month: '2026-06'),
          count: 12,
          summary: const MonthlySummary(
              year: 2026, month: 6,
              incomeCents: 2480000, expenseCents: 1835000,
              netCents: 645000, dailyAvgCents: 61167),
          onFilterChanged: (_) {},
        ),
      ),
    ));
    // month-bar 文本(2026年6月)
    expect(find.textContaining('2026年6月'), findsOneWidget);
    // sum-card 三列(收入/支出/净额)
    expect(find.text('本月收入'), findsOneWidget);
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.textContaining('本月净'), findsOneWidget);
    // 展开 toggle
    expect(find.text('查看月度明细'), findsOneWidget);
    await t.tap(find.text('查看月度明细'));
    await t.pumpAndSettle();
    // 展开后:日均支出
    expect(find.textContaining('日均'), findsWidgets);
  });

  testWidgets('_MobileHeader: prev/next 切月 onFilterChanged', (t) async {
    TxnFilterState? next;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _MobileHeader(
          filter: const TxnFilterState(month: '2026-06'),
          count: 12,
          summary: null,
          onFilterChanged: (s) => next = s,
        ),
      ),
    ));
    await t.tap(find.byTooltip('上一月'));
    await t.pumpAndSettle();
    expect(next?.month, '2026-05', reason: 'prev → 上一月');
  });
```

- [ ] **Step 2: 运行测试，确认其失败**

Run: `flutter test test/transaction/presentation/pages/transactions_page_test.dart -F "_MobileHeader"`
Expected: FAIL(`_MobileHeader` 不存在)

- [ ] **Step 3: 实现 `_MobileHeader`**

在 `transactions_page.dart` 新增(Task 2 widget 之后):

```dart
/// mobile 顶部:month-bar(prev/text/next) + 可展开 sum-card。
class _MobileHeader extends StatefulWidget {
  const _MobileHeader({
    required this.filter,
    required this.count,
    required this.summary,
    required this.onFilterChanged,
  });

  final TxnFilterState filter;
  final int count;
  final MonthlySummary? summary;
  final ValueChanged<TxnFilterState> onFilterChanged;

  @override
  State<_MobileHeader> createState() => _MobileHeaderState();
}

class _MobileHeaderState extends State<_MobileHeader> {
  bool _expanded = false;

  String get _monthLabel {
    final m = widget.filter.month;
    if (m != null && m.length >= 7) {
      final parts = m.split('-');
      if (parts.length == 2) return '${parts[0]}年${int.parse(parts[1])}月';
    }
    final now = DateTime.now();
    return '${now.year}年${now.month}月';
  }

  void _shift(int delta) {
    final m = widget.filter.month;
    DateTime base;
    if (m != null && m.length >= 7) {
      final parts = m.split('-');
      base = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    } else {
      base = DateTime.now();
    }
    final d = DateTime(base.year, base.month + delta);
    final ym = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    widget.onFilterChanged(widget.filter.copyWith(month: ym));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    return Column(
      children: [
        // month-bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: '上一月',
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () => _shift(-1),
              ),
              Column(
                children: [
                  Text(_monthLabel,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Georgia')),
                  Text('本月 · 共 ${widget.count} 笔',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11)),
                ],
              ),
              IconButton(
                tooltip: '下一月',
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () => _shift(1),
              ),
            ],
          ),
        ),
        // sum-card
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.lgBorder,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _sumCol('本月收入', s?.incomeCents ?? 0, AppColors.positive),
                  _vd(),
                  _sumCol('本月支出', s?.expenseCents ?? 0, AppColors.negative),
                  _vd(),
                  _sumCol('本月净额', s?.netCents ?? 0, null),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: const BoxDecoration(
                      border:
                          Border(top: BorderSide(color: AppColors.border))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                          _expanded ? '收起月度明细' : '查看月度明细',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12.5)),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      _extraRow('日均支出', s?.dailyAvgCents ?? 0),
                      // 储蓄率/已对账/较上月 无数据源,本期省略(spec §3.3)
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sumCol(String label, int cents, Color? color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 11.5)),
            const SizedBox(height: 6),
            Text(
              _formatCents(cents, signed: cents != 0),
              style: TextStyle(
                  color: color ?? AppColors.fg,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabularFigures),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vd() =>
      Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 12), color: AppColors.border);

  Widget _extraRow(String label, int cents) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          Text(_formatCents(cents),
              style: const TextStyle(
                  color: AppColors.fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}
```

> 注:`_formatCents` 是 transactions_page 顶层函数(既有)。`MonthlySummary` 字段 incomeCents/expenseCents/netCents/dailyAvgCents(既有)。

- [ ] **Step 4: 运行测试，确认其通过**

Run: `flutter test test/transaction/presentation/pages/transactions_page_test.dart -F "_MobileHeader"`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/transaction/presentation/pages/transactions_page.dart yucai/client/test/transaction/presentation/pages/transactions_page_test.dart
git commit -m "feat(txn-mobile): _MobileHeader month-bar + 可展开 sum-card"
```

---

### Task 4: `_Content` mobile 分支组装

**Files:**
- Modify: `yucai/client/lib/transaction/presentation/pages/transactions_page.dart`(`_Content.build` L223-306)
- Test: 同 Task 1

**Interfaces:**
- Consumes: Task 1(`_MobileTxnCard`)/Task 2(`_MobileAppBar`/`_MobileFilterSheet`)/Task 3(`_MobileHeader`)
- Produces: mobile `_Content` 用 `_MobileAppBar`+`_MobileHeader`+`_MobileList`(隐藏 desktop `_Header`/`SummaryCard`/`TxnFilterBar`)

- [ ] **Step 1: 写失败 test**

```dart
  testWidgets('mobile: _Content 显示 _MobileAppBar/_MobileHeader,隐藏 desktop _Header/TxnFilterBar', (t) async {
    t.view.physicalSize = const Size(375, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    // mobile appbar(交易管理 标题)
    expect(find.text('交易管理'), findsOneWidget);
    // mobile header(month-bar 文本)
    expect(find.textContaining(RegExp(r'\d{4}年\d+月')), findsWidgets);
    // desktop TxnFilterBar 隐藏(横向筛选栏的类型分段文字「全部/收入/支出/转账」
    //   不在 mobile 出现 —— 用一个 desktop-only 标志,如「重置筛选」按钮)
    // 注:具体 desktop-only 文案需核对 TxnFilterBar;若无唯一标志,断言 mobile 三件套存在即可
    expect(find.text('交易管理'), findsOneWidget);
  });
```

- [ ] **Step 2: 运行测试，确认其失败**

Run: `flutter test test/transaction/presentation/pages/transactions_page_test.dart -F "_Content 显示"`
Expected: FAIL(当前 mobile `_Content` 用 desktop `_Header`/`SummaryCard`/`TxnFilterBar`,无 `_MobileAppBar`/`_MobileHeader`)

- [ ] **Step 3: 改 `_Content.build`**

在 `_Content.build`(L223)开头算 `accountOptions`/`categoryOptions`/`monthOptions`/`groups` 之后,加 isMobile 判定 + 条件布局。把整个 `return RefreshIndicator(...)` 内的 `Column(children: [...])` 改为条件:

```dart
  Widget build(BuildContext context) {
    return FutureBuilder<List<Account>>(
      future: _loadAccounts(context),
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? const <Account>[];
        final accountOptions = [
          for (final a in accounts) FilterOption(a.id, a.name),
        ];
        final categoryOptions = _categoryOptions(accounts);
        final monthOptions = _monthOptions();
        final groups = _groupByDay(_txns);
        final isMobile =
            ResponsiveLayout.breakpointOf(context) == Breakpoint.mobile;
        // 注:若 ResponsiveLayout 无静态 breakpointOf,用 Breakpoints.of(context)
        // (import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart')
        final isMobileB =
            Breakpoints.of(context) == Breakpoint.mobile;

        return RefreshIndicator(
          onRefresh: () async => context
              .read<TransactionBloc>()
              .add(LoadTransactionsRequested(filter: _filter)),
          child: SingleChildScrollView(
            padding: isMobileB
                ? const EdgeInsets.fromLTRB(4, 4, 4, 96)
                : const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: isMobileB ? double.infinity : 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isMobileB) ...[
                      _MobileAppBar(
                        onFilter: () => _showMobileFilterSheet(
                          context,
                          accountOptions: accountOptions,
                          categoryOptions: categoryOptions,
                          monthOptions: monthOptions,
                        ),
                      ),
                      _MobileHeader(
                        filter: _filter,
                        count: _txns.length,
                        summary: _summary,
                        onFilterChanged: onFilterChanged,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ] else ...[
                      _Header(
                        count: _txns.length,
                        monthLabel: _currentMonthLabel(_filter),
                        onCreate: onCreate,
                        onExport: onExport,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SummaryCard(
                        incomeCents: _summary?.incomeCents ?? 0,
                        expenseCents: _summary?.expenseCents ?? 0,
                        netCents: _summary?.netCents ?? 0,
                        dailyAvgCents: _summary?.dailyAvgCents ?? 0,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TxnFilterBar(
                        state: _filter,
                        onChanged: onFilterChanged,
                        accountOptions: accountOptions,
                        categoryOptions: categoryOptions,
                        monthOptions: monthOptions,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    ResponsiveLayout(
                      mobile: _MobileList(
                        groups: groups,
                        accounts: accounts,
                        onOpenDetail: onOpenDetail,
                      ),
                      tablet: _TxCard(
                        groups: groups,
                        accounts: accounts,
                        onOpenDetail: onOpenDetail,
                        hasMore: _hasMore,
                        loadingMore: loadingMore,
                        onLoadMore: onLoadMore,
                        totalCount: _txns.length,
                      ),
                      desktop: _TxCard(
                        groups: groups,
                        accounts: accounts,
                        onOpenDetail: onOpenDetail,
                        hasMore: _hasMore,
                        loadingMore: loadingMore,
                        onLoadMore: onLoadMore,
                        totalCount: _txns.length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// mobile 筛选 sheet 弹出(Task 2 _MobileFilterSheet)。
  void _showMobileFilterSheet(
    BuildContext context, {
    required List<FilterOption> accountOptions,
    required List<FilterOption> categoryOptions,
    required List<FilterOption> monthOptions,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _MobileFilterSheet(
        initial: _filter,
        accountOptions: accountOptions,
        categoryOptions: categoryOptions,
        monthOptions: monthOptions,
        onApply: (next) {
          onFilterChanged(next);
          Navigator.of(context).pop();
        },
      ),
    );
  }
```

> 注:`Breakpoints` enum 来自 `responsive_layout.dart`(与 `ResponsiveLayout` 同文件 import)。若 `Breakpoints.of(context)` 不可用,改用 `MediaQuery.of(context).size.width < 600`(与 accounts_page 同 mobile 断点)—— 两者择一,以 `flutter analyze` 通过为准。`_filter`/`_summary`/`_txns`/`_hasMore`/`loadingMore`/`onLoadMore`/`onCreate`/`onExport`/`onOpenDetail`/`onFilterChanged` 都是 `_Content` 既有字段/参数。

- [ ] **Step 4: 运行测试，确认其通过**

Run: `flutter test test/transaction/presentation/pages/transactions_page_test.dart`
Expected: PASS(全 test,含 Task 1-4 + 既有 desktop/tablet test。若既有 test 默认 800×600 viewport → mobile → 需 pin desktop viewport,参考 account-detail-responsive Task 1 的做法)

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/transaction/presentation/pages/transactions_page.dart yucai/client/test/transaction/presentation/pages/transactions_page_test.dart
git commit -m "feat(txn-mobile): _Content mobile 分支组装(_MobileAppBar+_MobileHeader+_MobileList)"
```

---

## Self-Review

**1. Spec 覆盖**:
- §3.1 mobile 交易卡(chip/HH:MM/首字母方块) → Task 1 ✓
- §3.2 筛选底部 sheet(filterBtn + chip 单选 + 重置/应用) → Task 2 ✓
- §3.3 month-bar + 可展开 sum-card → Task 3 ✓
- §4 mobile 分支组装(替代 desktop _Header/SummaryCard/TxnFilterBar) → Task 4 ✓

**2. 占位扫描**:每 task 含完整 test code + impl code。Task 2 Step 4 的 test-unmounted 风险已用单元 test(`_MobileFilterSheet` 直接 pump)规避。✓

**3. 类型一致**:
- `_MobileFilterSheet`(initial/accountOptions/categoryOptions/monthOptions/onApply)Task 2 定义,Task 4 `_showMobileFilterSheet` 调用签名一致 ✓
- `_MobileAppBar`(onFilter)Task 2 定义,Task 4 `_MobileAppBar(onFilter: ...)` 一致 ✓
- `_MobileHeader`(filter/count/summary/onFilterChanged)Task 3 定义,Task 4 调用一致 ✓
- `_MobileTxnCard` Task 1 改(副行/右侧),Task 4 `_MobileList` 调用不变(既有签名)✓
- `TxnFilterState.copyWith(type/accountId/category/month)` Task 2 `_typeGroup`/`_chipGroup` 用法与 filter_bar.dart 一致 ✓

**4. 既有 test 影响**:Task 4 mobile 分支可能让默认 800×600 viewport test 走 mobile(若有 transactions_page_test 在默认 viewport 断 desktop 文案)。Task 4 Step 4 已注明 pin desktop viewport。

无 gap,类型一致。
