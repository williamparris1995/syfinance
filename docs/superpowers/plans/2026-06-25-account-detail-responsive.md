# 账户详情页响应式 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把账户详情页(`account_detail_page.dart`)对齐 OD `detail-account.html` 的三端响应式(desktop >900 / tablet ≤900 / mobile ≤720),6 个区域在窄屏正确堆叠/收敛。

**Architecture:** 在 `_body` 顶部用 `MediaQuery.size.width` 算 `isTablet(w≤900)`/`isMobile(w≤720)`,各区域按标志分支:`_body` 双栏→堆叠、`_statsRow`/`_heroFields`/`_infoCard` 4/4/3 列→2 列、hero 余额 mobile 32px、topbar 按钮 ≤900 仅 icon。widget TDD 覆盖 desktop 1200 / tablet 800 / mobile 375。

**Tech Stack:** Flutter 3.44 + flutter_bloc + lucide_icons_flutter + 御财 token(AppColors/AppTypography)。御财 client 无 i18n,硬编码中文(与现有 detail page 一致)。

## Global Constraints

- **断点**:`MediaQuery.of(context).size.width <= 900` = tablet(含 mobile);`<= 720` = mobile。对应 OD `@media (max-width:900px)/(720px)` viewport。
- **范围**:只改 `account_detail_page.dart` 内容区(`_body`/`_statsRow`/`heroFields`/`_infoCard`/hero 余额/topbar)。**不含 AppShell sidebar 抽屉**(shell 层,单独 spec)。
- **御财 token**:mono+tabular-nums(`AppTypography.tabularFigures`)、serif 标题、`AppColors.bg/surface/fg/muted/accent/positive/negative`、`AppRadius.lg`、`AppSpacing.*`。不引入新 token。
- **测试**:widget TDD,用 `tester.view.physicalSize = Size(W, H)` + `devicePixelRatio = 1.0` + `addTearDown(tester.view.resetPhysicalSize/resetDevicePixelRatio)` 设三端宽度。harness 复用 `account_detail_page_test.dart` 现有 `pumpPage` + mock repo/bloc。
- **分支**:`account-detail-responsive`,BASE `581ef40`(spec commit)。

---

### Task 1: `_body` 双栏堆叠 + mobile padding

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_detail_page.dart`(`_body` L228-268)
- Test: `yucai/client/test/account/presentation/pages/account_detail_page_test.dart`

**Interfaces:**
- Consumes: 无(本 task 是后续 task 的基础 —— 后续 task 复用 `isTablet`/`isMobile` 概念,但各自在区域内 `MediaQuery.of`)
- Produces: `_body` 内 `_statsRow`/`_hero`/`_infoCard` 调用点不变(后续 task 改这些被调方法的内部)

- [ ] **Step 1: 写失败 test(tablet 堆叠 + desktop 双栏 + mobile padding)**

在 `account_detail_page_test.dart` 的 `main()` 内(任何既有 `testWidgets` 之后)追加:

```dart
  testWidgets('tablet 800: body 双栏堆叠成单列(交易在上 饼图在下)', (t) async {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    // 近期交易 panel 与 收支统计 panel 在同一 Column(垂直堆叠)
    final statsPanel = find.ancestor(
        of: find.text('收支统计'), matching: find.byType(SingleChildScrollView));
    expect(
        find.ancestor(of: find.text('近期交易'), matching: find.byType(Column)),
        findsWidgets,
        reason: 'tablet 应堆叠:近期交易在 Column 内');
    expect(statsPanel, findsWidgets);
  });

  testWidgets('desktop 1200: body 保持双栏 Row', (t) async {
    t.view.physicalSize = const Size(1200, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    // desktop:近期交易在 Row(flex:3)内 —— 找到它祖先有 Row(非 Column 堆叠)
    expect(
        find.ancestor(
            of: find.text('近期交易'),
            matching: find.byKey(const ValueKey('detailBodyRow'))),
        findsOneWidget,
        reason: 'desktop 应双栏:近期交易在 detailBodyRow 内');
  });
```

- [ ] **Step 2: 运行测试，确认其失败**

运行：`flutter test test/account/presentation/pages/account_detail_page_test.dart -F "tablet 800: body" --plain-name`
预期：失败（当前 `_body` 固定 `Row`,无 `detailBodyRow` key,tablet 也走 Row → desktop test 找不到 key 失败；tablet test 找 Column 也可能失败）

- [ ] **Step 3: 改 `_body` 响应式**

修改 `account_detail_page.dart` `_body`(L228-268)。把开头的 `return ListView(...)` 改为先算断点 + 条件 padding + 条件 Row/Column:

```dart
  Widget _body(Account a) {
    // 读 TransactionBloc state（页面 build 顶部已确保 bloc 存在）。
    final txnState = context.watch<TransactionBloc>().state;
    final txns = txnState is TransactionsLoaded
        ? txnState.transactions
        : (txnState is TransactionsLoadingMore ? txnState.transactions : const <Transaction>[]);
    final summary = txnState is TransactionsLoaded
        ? txnState.summary
        : (txnState is TransactionsLoadingMore ? txnState.summary : null);
    // 三端响应式断点（对齐 OD @media 900/720）。
    final w = MediaQuery.of(context).size.width;
    final isTablet = w <= 900; // ≤900 tablet（含 mobile）
    final isMobile = w <= 720; // ≤720 mobile
    return ListView(
      // OD .content padding 24/36/70（top/bottom 24,左右 36,底部 70）；
      // ≤720 缩到 16/14/60。
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 14, 16, 60)
          : const EdgeInsets.fromLTRB(36, 24, 36, 70),
      children: [
        _hero(a, summary?.netCents ?? 0),
        const SizedBox(height: 18),
        _statsRow(a, txns, summary),
        const SizedBox(height: 18),
        // OD .cols：>900 双栏（交易 1.5fr + 饼图 1fr）/ ≤900 堆叠单列。
        if (isTablet)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _recentTxnPanel(txns, a.currencyCode),
              const SizedBox(height: 16),
              _summaryPanel(summary, a.currencyCode),
            ],
          )
        else
          Row(
            key: const ValueKey('detailBodyRow'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _recentTxnPanel(txns, a.currencyCode)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _summaryPanel(summary, a.currencyCode)),
            ],
          ),
        const SizedBox(height: 18),
        _infoCard(a),
        const SizedBox(height: AppSpacing.lg),
        if (a.category == AccountCategory.investment)
          _panel('持仓列表', '待 Holding 模块接入')
        else if (a.category == AccountCategory.loan)
          _panel('还款计划', '待 payment_schedule 模块接入')
        else
          const SizedBox.shrink(),
      ],
    );
  }
```

- [ ] **Step 4: 运行测试，确认其通过**

运行：`flutter test test/account/presentation/pages/account_detail_page_test.dart`
预期：PASS（新 2 个 test + 既有全过）

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/account_detail_page.dart yucai/client/test/account/presentation/pages/account_detail_page_test.dart
git commit -m "feat(detail): _body 响应式 — tablet 堆叠 + mobile padding 16/14"
```

---

### Task 2: `_statsRow` 4 列 ↔ 2 列

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_detail_page.dart`(`_statsRow` L771-845,把 `Row(for 4 Expanded)` 改成 `GridView.count`)
- Test: 同 Task 1

**Interfaces:**
- Consumes: 无
- Produces: `_statsRow` 用 `GridView.count` 渲染（key `statsRow`）,后续无依赖

- [ ] **Step 1: 写失败 test(tablet 2 列 / desktop 4 列)**

在 `main()` 追加:

```dart
  testWidgets('tablet 800: statsRow 2 列', (t) async {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    final grid = t.widget<GridView>(find.byKey(const ValueKey('statsRow')));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2, reason: 'tablet stat 卡 2 列');
  });

  testWidgets('desktop 1200: statsRow 4 列', (t) async {
    t.view.physicalSize = const Size(1200, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    final grid = t.widget<GridView>(find.byKey(const ValueKey('statsRow')));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 4, reason: 'desktop stat 卡 4 列');
  });
```

- [ ] **Step 2: 运行测试，确认其失败**

运行：`flutter test test/account/presentation/pages/account_detail_page_test.dart -F "tablet 800: statsRow"`
预期：失败（`_statsRow` 现状是 `Row`,无 `statsRow` key 的 `GridView`）

- [ ] **Step 3: 改 `_statsRow` 为 `GridView`**

修改 `_statsRow`。保留前面的 `final stats = _statsFor(...)` 与 `const iconSpecs`，把最后的 `return Row(children: [for (var i...) Expanded(... DataCard(...))])` 改成 `GridView.count`：

```dart
    // OD .stat-row：>900 4 列 / ≤900 2 列（gap 14）。
    final w = MediaQuery.of(context).size.width;
    final isTablet = w <= 900;
    return GridView.count(
      key: const ValueKey('statsRow'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isTablet ? 2 : 4,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      // DataCard 高约 96（label+val+sub+tag），宽约 170（desktop）/ 360（tablet 2 列）。
      childAspectRatio: isTablet ? 3.0 : 1.6,
      children: [
        for (var i = 0; i < stats.length; i++)
          DataCard(
            padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatIconSquare(
                      bg: iconSpecs[i].$1,
                      fg: iconSpecs[i].$2,
                      icon: iconSpecs[i].$3,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(stats[i].$1,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(stats[i].$2,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('实时',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      )),
                ),
              ],
            ),
          ),
      ],
    );
  }
```

（注：去掉了原 `Row` 里 `Expanded(child: Padding(left/right i==0/last))` 的手动间距逻辑 —— `GridView` 的 `mainAxisSpacing/crossAxisSpacing` 接管间距。`iconSpecs`/`stats`/`_StatIconSquare` 均保留不变。）

- [ ] **Step 4: 运行测试，确认其通过**

运行：`flutter test test/account/presentation/pages/account_detail_page_test.dart`
预期：PASS（含新 2 个 + 既有）

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/account_detail_page.dart yucai/client/test/account/presentation/pages/account_detail_page_test.dart
git commit -m "feat(detail): _statsRow 响应式 — tablet 2 列 / desktop 4 列"
```

---

### Task 3: `_heroFields` 断点 600 → 900

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_detail_page.dart`(`_heroFields` L724-735 的 `LayoutBuilder`)
- Test: 同 Task 1

**Interfaces:** 无外部依赖

- [ ] **Step 1: 写失败 test(tablet 2 列)**

在 `main()` 追加:

```dart
  testWidgets('tablet 800: heroFields 2 列（断点 900）', (t) async {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    final grid = t.widget<GridView>(find.byKey(const ValueKey('heroFields')));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2,
        reason: 'tablet hero-fields 2 列（断点 900，旧 600 在 800 宽会误判 4 列）');
  });
```

- [ ] **Step 2: 运行测试，确认其失败**

运行：`flutter test test/account/presentation/pages/account_detail_page_test.dart -F "tablet 800: heroFields"`
预期：失败（当前 `c.maxWidth > 600` → content 800-72≈728 > 600 → 4 列，断言 2 列失败）

- [ ] **Step 3: 改断点 600 → 900**

修改 `_heroFields` 的 `LayoutBuilder` builder(L724-735)。把 `crossAxisCount: c.maxWidth > 600 ? 4 : 2` 改成用 `MediaQuery`（content 宽受 sidebar 影响，用 viewport 宽对齐 OD）:

```dart
      child: LayoutBuilder(
        builder: (ctx, c) {
          // 断点用 viewport 宽（MediaQuery）对齐 OD @media 900，而非 content 宽
          //（content = viewport - sidebar 240，会偏移断点）。
          final isDesktop = MediaQuery.of(ctx).size.width > 900;
          return GridView.count(
            key: const ValueKey('heroFields'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isDesktop ? 4 : 2,
            // OD .hero-fields gap 18px。
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            childAspectRatio: 2.6,
            children: [for (final f in fields) _heroField(f.$1, f.$2)],
          );
        },
      ),
```

- [ ] **Step 4: 运行测试，确认其通过**

运行：`flutter test test/account/presentation/pages/account_detail_page_test.dart`
预期：PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/account_detail_page.dart yucai/client/test/account/presentation/pages/account_detail_page_test.dart
git commit -m "fix(detail): _heroFields 断点 600→900 对齐 OD @media"
```

---

### Task 4: `_infoCard` 断点 600 → 900

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_detail_page.dart`(`_infoCard` L343-355 的 `LayoutBuilder`)
- Test: 同 Task 1

**Interfaces:** 无外部依赖

- [ ] **Step 1: 写失败 test(tablet 2 列)**

在 `main()` 追加:

```dart
  testWidgets('tablet 800: infoCard 2 列（断点 900）', (t) async {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    final grid = t.widget<GridView>(find.byKey(const ValueKey('infoCard')));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2, reason: 'tablet info-grid 2 列');
  });
```

- [ ] **Step 2: 运行测试，确认其失败**

运行：`flutter test test/account/presentation/pages/account_detail_page_test.dart -F "tablet 800: infoCard"`
预期：失败（`_infoCard` 当前无 `infoCard` key 的 `GridView`）

- [ ] **Step 3: 改 `_infoCard` 断点 + 加 key**

修改 `_infoCard` 的 `LayoutBuilder`(L343-355):

```dart
          LayoutBuilder(
            builder: (ctx, c) {
              final isDesktop = MediaQuery.of(ctx).size.width > 900;
              return GridView.count(
                key: const ValueKey('infoCard'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isDesktop ? 3 : 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 2.8,
                children: [for (final cell in cells) _infoCell(cell.$1, cell.$2)],
              );
            },
          ),
```

- [ ] **Step 4: 运行测试，确认其通过**

运行：`flutter test test/account/presentation/pages/account_detail_page_test.dart`
预期：PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/account_detail_page.dart yucai/client/test/account/presentation/pages/account_detail_page_test.dart
git commit -m "fix(detail): _infoCard 断点 600→900 对齐 OD @media"
```

---

### Task 5: hero 余额 mobile 32px

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_detail_page.dart`(`_hero` L506-517 余额 `Text`)
- Test: 同 Task 1

**Interfaces:** 无外部依赖

- [ ] **Step 1: 写失败 test(mobile 32 / desktop 40)**

在 `main()` 追加:

```dart
  testWidgets('mobile 375: hero 余额字号 32', (t) async {
    t.view.physicalSize = const Size(375, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    final bal = t.widget<Text>(find.byKey(const ValueKey('heroBalance')));
    expect(bal.style?.fontSize, 32, reason: 'mobile hero 余额 32px');
  });

  testWidgets('desktop 1200: hero 余额字号 40', (t) async {
    t.view.physicalSize = const Size(1200, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    final bal = t.widget<Text>(find.byKey(const ValueKey('heroBalance')));
    expect(bal.style?.fontSize, 40, reason: 'desktop hero 余额 40px');
  });
```

- [ ] **Step 2: 运行测试，确认其失败**

运行：`flutter test test/account/presentation/pages/account_detail_page_test.dart -F "mobile 375: hero 余额"`
预期：失败（当前余额 `Text` 无 `heroBalance` key）

- [ ] **Step 3: 改余额 Text 加 key + 字号分支**

修改 `_hero` 的余额 `Text`(L506-517)。先在 `_hero` 开头算 `isMobile`，再给 `Text` 加 key + 字号分支:

在 `_hero` 方法体最开头(`final isLiability = ...` 之前或之后)加:
```dart
    final isMobile = MediaQuery.of(context).size.width <= 720;
```

把余额 `Text`(原 L506-517) 改成:
```dart
                Text(
                  key: const ValueKey('heroBalance'),
                  _fmt(a.currentBalanceCents, a.currencyCode),
                  style: TextStyle(
                    fontSize: isMobile ? 32 : 40,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    color: Colors.white,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
```

（注：原 `const TextStyle(...)` 因 `fontSize` 不再常量需去 `const`；其余字段保留。）

- [ ] **Step 4: 运行测试，确认其通过**

运行：`flutter test test/account/presentation/pages/account_detail_page_test.dart`
预期：PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/account_detail_page.dart yucai/client/test/account/presentation/pages/account_detail_page_test.dart
git commit -m "feat(detail): hero 余额 mobile 32px / desktop 40px"
```

---

### Task 6: topbar ≤900 仅 icon

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_detail_page.dart`(`_scaffold` AppBar actions L128-187)
- Test: 同 Task 1

**Interfaces:** 无外部依赖

- [ ] **Step 1: 写失败 test(tablet 无"编辑"文字 / desktop 有)**

在 `main()` 追加:

```dart
  testWidgets('tablet 800: topbar 编辑/记一笔/转账 仅 icon(无文字)', (t) async {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    expect(find.text('编辑'), findsNothing, reason: 'tablet topbar 仅 icon');
    expect(find.text('记一笔'), findsNothing);
    expect(find.text('转账'), findsNothing);
  });

  testWidgets('desktop 1200: topbar 编辑 有文字', (t) async {
    t.view.physicalSize = const Size(1200, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    expect(find.text('编辑'), findsOneWidget, reason: 'desktop topbar icon+文字');
  });
```

- [ ] **Step 2: 运行测试，确认其失败**

运行：`flutter test test/account/presentation/pages/account_detail_page_test.dart -F "tablet 800: topbar"`
预期：失败（当前 `TextButton(child: Text('编辑'))` 始终显示文字，tablet 800 `find.text('编辑')` 非空）

- [ ] **Step 3: 改 AppBar actions 条件 icon-only**

修改 `_scaffold` 的 `actions` 内 `BlocBuilder` builder(L132-185)。在 builder 开头算 `isTablet`，把 3 个 `TextButton(child: Text(...))` 改成条件 `IconButton`（≤900）/ `TextButton`（>900）。

在 builder 内 `final archived = ...` 之后加:
```dart
              final isTablet =
                  MediaQuery.of(context).size.width <= 900;
```

把 `if (!archived) ...[ TextButton(编辑), TextButton(记一笔), TextButton(转账) ]` 替换为:
```dart
                  if (!archived) ...[
                    if (isTablet) ...[
                      IconButton(
                        tooltip: '编辑',
                        icon: const Icon(LucideIcons.edit, size: 18),
                        onPressed: a == null ? null : () => _edit(a),
                      ),
                      IconButton(
                        tooltip: '记一笔',
                        icon: const Icon(LucideIcons.penLine, size: 18),
                        onPressed: a == null ? null : _recordTxn,
                      ),
                      IconButton(
                        tooltip: '转账',
                        icon: const Icon(LucideIcons.arrowLeftRight, size: 18),
                        onPressed: a == null ? null : _transfer,
                      ),
                    ] else ...[
                      TextButton(
                        onPressed: a == null ? null : () => _edit(a),
                        child: const Text('编辑'),
                      ),
                      TextButton(
                        onPressed: a == null ? null : _recordTxn,
                        child: const Text('记一笔'),
                      ),
                      TextButton(
                        onPressed: a == null ? null : _transfer,
                        child: const Text('转账'),
                      ),
                    ],
                  ],
```

（注：icon 用 lucide —— `LucideIcons.edit` / `penLine`（记一笔）/ `arrowLeftRight`（转账）。`lucide_icons_flutter` 已 import。若 `penLine`/`arrowLeftRight` 名称在该版本不存在，用 `LucideIcons.pencil` / `LucideIcons.swap` 替代，以 `flutter analyze` 通过为准。）

- [ ] **Step 4: 运行测试，确认其通过**

运行：`flutter test test/account/presentation/pages/account_detail_page_test.dart`
预期：PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/account_detail_page.dart yucai/client/test/account/presentation/pages/account_detail_page_test.dart
git commit -m "feat(detail): topbar ≤900 仅 icon(去文字,tablet 800 防挤)"
```

---

## Self-Review

**1. Spec 覆盖**:
- §3.1 `_body` 堆叠 → Task 1 ✓
- §3.2 `_statsRow` 2 列 → Task 2 ✓
- §3.3 `_heroFields` 断点 900 → Task 3 ✓
- §3.4 `_infoCard` 2 列 → Task 4 ✓
- §3.5 hero 余额 32px → Task 5 ✓
- §3.6 topbar 仅 icon → Task 6 ✓
- §3.7 content padding → Task 1(`isMobile ? 16/14/16/60`)✓

**2. 占位扫描**: 无 TBD/TODO;每 task 含完整 test 代码 + 实现代码。✓

**3. 类型一致**:
- `ValueKey('statsRow')`(Task 2)/ `('heroFields')`(Task 3,既有)/ `('infoCard')`(Task 4)/ `('heroBalance')`(Task 5)/ `('detailBodyRow')`(Task 1)各 task 唯一,无冲突。
- 断点:`MediaQuery.of(context).size.width` 各 task 一致;`isTablet = w <= 900`、`isMobile = w <= 720` 全局一致。
- GridView delegate cast `SliverGridDelegateWithFixedCrossAxisCount` —— `GridView.count` 创建此类型,一致。

**4. lucide icon 名**:`penLine`/`arrowLeftRight` 在 lucide_icons_flutter ^3.1.14+2 存在;若 analyze 报错用 `pencil`/`swap` 兜底(Task 6 step 3 注释已说明)。

无 gap,类型一致。
