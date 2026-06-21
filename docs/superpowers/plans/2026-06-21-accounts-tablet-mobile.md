# 御财账户管理 Tablet/Mobile 响应式 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `AccountsPage` 列表页在 mobile(<600px)/tablet(600-1099px)/desktop(>=1100px) 三断点对齐 OD 原型（紧凑行卡 / 2列完整卡 / auto-fill 网格 + 汇总头响应式）。

**Architecture:** 3 任务串行改 `accounts_page.dart`（同文件）：先 `_AccountsHeader` 改造为响应式 sumcard（独立视觉单元），再 `_AccountCard` 加 mobile 紧凑行布局分支，最后 `_GroupBlock` 列数 + aspect 响应式。外壳/底部 tab 由 `AppShell` 已有的 `<1100` 切换负责，本页只改内容。类型副信息 + 进度条复用现有 `_sublineWidget`/`_usageSpec`。

**Tech Stack:** Flutter (Dart, flutter_bloc, go_router) + TDD (flutter test, widget test 三尺寸断点)。

## Global Constraints

- **原型源（权威）**：`design-output/accounts-responsive/mobile.html` + `tablet.html`（OD 项目 `yucai-account-mobile-tablet-a279`）。
- **御财 token**（`core/theme/app_design.dart`）：bg `#f7f6f2` / surface `#ffffff` / fg `#1a1916` / muted `#7a7770` / accent `#b08d57` / accent-soft `#f3ebdd` / positive `#2d8a6e` / negative `#c4544d` / border `#e6e3dc` / radius sm 10 lg 14 / `AppTypography.displayFamily`(serif) + `tabularFigures`(mono) / `AppSpacing` / `AppRadius`。
- **断点**：mobile `< 600px` / tablet `600–1099px` / desktop `>= 1100px`。
- **i18n**：御财客户端无 i18n，UI 文案硬编码中文（正确，**不要**套用 syfinance Tauri 的 `t()`）。
- **命令**：`cd yucai/client && flutter test test/account/presentation/pages/accounts_page_test.dart`；analyze `flutter analyze`（0 error）。
- **提交**：每任务一 commit，前缀 `feat(client):`，中文。**不要提交 `graphify-out/`**。
- **金额**：int64 cents，`_fmt`/`_fmtSigned` 千分位 + 两位小数（复用现有）。
- **`withValues(alpha:)`** 不用 `withOpacity`。

---

## File Structure

| 文件 | 责任 | 改动任务 |
|------|------|----------|
| `yucai/client/lib/account/presentation/pages/accounts_page.dart` | `_AccountsHeader` 响应式 / `_AccountCard` 紧凑行 / `_GroupBlock` 列数 / `_content` 传 asset/liab | Task 1–3 |
| `yucai/client/test/account/presentation/pages/accounts_page_test.dart` | 三尺寸 widget 测试 | Task 1–3 |
| `yucai/client/lib/core/widgets/filter_bar.dart` | mobile 横滚确认 | Task 3（仅确认，大概率不改） |

**串行约束**：Task 1–3 全改 `accounts_page.dart`，**不可并行**。按 1→2→3 顺序，每任务 review 后再开下一个。

---

## Task 1: `_AccountsHeader` 响应式（sumcard / mobile 紧凑汇总）

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/accounts_page.dart`（`_AccountsHeader` L396-468 + `_content` 调用处 L329-333）
- Test: `yucai/client/test/account/presentation/pages/accounts_page_test.dart`

**Interfaces:**
- Consumes: `AppColors`/`AppSpacing`/`AppRadius`/`AppTypography`、`_NewAccountButton`（已存在 L470，不改）
- Produces: `_AccountsHeader` 新签名 `{netCents, assetCents, liabCents, onAdd}`（替代旧 `{totalCents, count, onAdd}`）；`_content` 算 assetCents/liabCents 传入

**Why:** 现状 `_AccountsHeader` 是扁平 `Row[RichText 合计·¥ + count, button]`，无白卡、无总资产/负债。原型 sumcard（desktop/tablet）= 白卡 + serif 净资产 + 分隔 + 总资产 + 总负债 + 新建按钮；mobile = 紧凑汇总卡（净资产 mono + "资产·负债"meta，去 count）。

- [ ] **Step 1: 写失败测试** — 在 `accounts_page_test.dart` 追加（复用现有 `_harness(List<Account>)` + viewport size 模式）：

```dart
testWidgets('desktop header: sumcard with 净资产 + 总资产 + 总负债', (tester) async {
  await tester.pumpWidget(_harness([
    _account('a1', '储蓄', cat: AccountCategory.savings, bal: 100000),    // 资产 +1000
    _account('a2', '信用卡', cat: AccountCategory.creditCard, bal: -30000), // 负债 -300
  ]));
  await tester.pumpAndSettle();
  expect(find.text('净资产合计'), findsOneWidget);
  expect(find.text('总资产'), findsOneWidget);
  expect(find.text('总负债'), findsOneWidget);
});

testWidgets('mobile header: compact 净资产 + 资产·负债 meta, no count', (tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_harness([
    _account('a1', '储蓄', cat: AccountCategory.savings, bal: 100000),
    _account('a2', '信用卡', cat: AccountCategory.creditCard, bal: -30000),
  ]));
  await tester.pumpAndSettle();
  expect(find.text('全部账户余额合计'), findsOneWidget);
  expect(find.text('净资产合计'), findsNothing);  // mobile 用 label 非「净资产合计」
  expect(find.textContaining('资产'), findsWidgets);
  expect(find.textContaining('共'), findsNothing);  // count 行去掉
});
```

> `_account(id, name, {cat, bal, ...})` 测试辅助：若现有 harness 有类似 factory 复用；否则内联最小 `Account(...)`。`AccountCategory.savings`/`.creditCard` 等已 import。

- [ ] **Step 2: 运行验证失败**

Run: `cd yucai/client && flutter test test/account/presentation/pages/accounts_page_test.dart`
Expected: FAIL（当前无「净资产合计」/「总资产」/ mobile 无「全部账户余额合计」紧凑形态）

- [ ] **Step 3: 改 `_content` 算 asset/liab 分计** — 在 `_content(List<Account> accounts)`（约 L294-310，算 `totalCents` 处）加分计，改 `_AccountsHeader` 调用：

现状（约 L297-305）：
```dart
final active = balanceSheet.where((a) => a.status == AccountStatus.active).toList();
final totalCents = active.fold<int>(0, (s, a) => s + a.currentBalanceCents);
```
改为：
```dart
final active = balanceSheet.where((a) => a.status == AccountStatus.active).toList();
final assetCents = active
    .where((a) => a.accountType == AccountType.asset)
    .fold<int>(0, (s, a) => s + a.currentBalanceCents);
final liabCents = active
    .where((a) => a.accountType == AccountType.liability)
    .fold<int>(0, (s, a) => s + a.currentBalanceCents);
final netCents = assetCents + liabCents; // 负债余额为负，相加得净资产
```

调用处（约 L329-333）：
```dart
_AccountsHeader(
  netCents: netCents,
  assetCents: assetCents,
  liabCents: liabCents,
  onAdd: _openCreateForm,
),
```
（删旧 `totalCents`/`count: scoped.length` 入参）

- [ ] **Step 4: 重写 `_AccountsHeader`** — 替换 L396-468 整个类：

```dart
class _AccountsHeader extends StatelessWidget {
  const _AccountsHeader({
    required this.netCents,
    required this.assetCents,
    required this.liabCents,
    required this.onAdd,
  });

  final int netCents;
  final int assetCents;
  final int liabCents;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) => c.maxWidth < 600 ? _mobileCard(context) : _sumcard(context),
    );
  }

  /// desktop/tablet：白卡 sumcard（对齐 tablet.html .sumcard）。
  Widget _sumcard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        boxShadow: const [
          BoxShadow(color: Color(0x141A1916), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _netBlock(),
                const SizedBox(width: 26),
                _vline(),
                const SizedBox(width: 26),
                _statBlock('总资产', assetCents, AppColors.positive),
                const SizedBox(width: 26),
                _vline(),
                const SizedBox(width: 26),
                _statBlock('总负债', liabCents, AppColors.negative),
              ],
            ),
          ),
          _NewAccountButton(onPressed: onAdd),
        ],
      ),
    );
  }

  /// mobile：紧凑汇总卡（对齐 mobile.html .summary）。
  Widget _mobileCard(BuildContext context) {
    return Stack(
      children: [
        // 右上 accent-soft 圆形装饰（原型 .deco）。
        Positioned(
          top: -38,
          right: -32,
          child: Container(
            width: 124,
            height: 124,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentSoft,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 17),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgBorder,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('全部账户余额合计',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              const SizedBox(height: 5),
              Text(
                _fmt(netCents),
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: netCents < 0 ? AppColors.negative : AppColors.fg,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
              const SizedBox(height: 9),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  children: [
                    const TextSpan(text: '资产 '),
                    TextSpan(
                        text: _fmt(assetCents),
                        style: const TextStyle(color: AppColors.positive)),
                    const TextSpan(text: '   ·   负债 '),
                    TextSpan(
                        text: _fmt(liabCents),
                        style: const TextStyle(color: AppColors.negative)),
                  ],
                ),
                style: const TextStyle(
                    fontFeatures: AppTypography.tabularFigures),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _netBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('净资产合计', style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 6),
        Text(
          _fmt(netCents),
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: netCents < 0 ? AppColors.negative : AppColors.fg,
            fontFamily: AppTypography.displayFamily,
            fontFamilyFallback: AppTypography.displayFallback,
          ),
        ),
      ],
    );
  }

  Widget _statBlock(String label, int cents, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          _fmt(cents),
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: color,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ],
    );
  }

  Widget _vline() =>
      Container(width: 1, height: 48, color: AppColors.border);

  /// 千分位 + 两位小数（¥ 前缀）。净资产/资产为正、负债为负（带 -）。
  static String _fmt(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    final s = yuan.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$sign¥$buf.$fen';
  }
}
```

> 删旧 `_formatInline`（被 `_fmt` 替代）。`_NewAccountButton`（L470-512）不改。

- [ ] **Step 5: 运行测试通过 + analyze**

Run: `cd yucai/client && flutter test test/account/presentation/pages/accounts_page_test.dart && flutter analyze`
Expected: PASS（新测试 + 既有测试可能需同步——若旧测试断言「全部账户余额合计 · 」RichText 或 count 行，按新结构改 mobile 用 label、desktop 用「净资产合计」）+ 0 error

- [ ] **Step 6: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/accounts_page.dart \
        yucai/client/test/account/presentation/pages/accounts_page_test.dart
git commit -m "feat(client): 账户汇总头响应式（desktop/tablet sumcard + mobile 紧凑汇总卡）"
```

---

## Task 2: `_AccountCard` mobile 紧凑行布局

**⚠️ 依赖 Task 1（同文件）。**

**Files:**
- Modify: `accounts_page.dart` `_AccountCard.build`（L645-789）
- Test: `accounts_page_test.dart`

**Interfaces:**
- Consumes: `_subline`/`_sublineWidget`/`_usageSpec`/`_progressBar`（已存在，复用）、`categoryColor`/`categoryIcon`、`DataCard`
- Produces: `_AccountCard.build` LayoutBuilder 分支（< 600 → `_compactCard`，否则 `_fullCard`）

**Why:** 现状 `_AccountCard.build` 固定 full 布局（ac-top + balance + subline + bar）。原型 mobile `.acc` 紧凑行：水平 `Row[aicon + name+org | label+val]` + 下方虚线副信息 + 进度条。

- [ ] **Step 1: 写失败测试** — 追加：

```dart
testWidgets('mobile card: compact row (label+val right, sub+bar below)', (tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_harness([
    _account('c1', '招行信用卡', cat: AccountCategory.creditCard,
        bal: -12400, creditLimit: 80000, billingDay: 12, repayDay: 1),
  ]));
  await tester.pumpAndSettle();
  // 紧凑行：右侧 label「当前欠款」+ 余额
  expect(find.text('当前欠款'), findsOneWidget);
  expect(find.text('招行信用卡'), findsOneWidget);
  // 进度条存在（信用卡）
  expect(find.byType(LinearProgressIndicator), findsOneWidget);
});

testWidgets('desktop card: full layout (balance 22px below name)', (tester) async {
  await tester.pumpWidget(_harness([
    _account('c1', '招行信用卡', cat: AccountCategory.creditCard, bal: -12400),
  ]));
  await tester.pumpAndSettle();
  // full 卡：余额作为独立大数字行（非右侧紧凑）
  expect(find.text('当前欠款'), findsNothing);  // desktop 卡无 label「当前欠款」（直接余额）
});
```

> desktop full 卡现状无「当前欠款」label（直接显示 balance）。compact 行有 label。用此区分断言形态。若现状 desktop 卡有其他 label 文本，调整断言。

- [ ] **Step 2: 运行验证失败**

Run: `cd yucai/client && flutter test test/account/presentation/pages/accounts_page_test.dart`
Expected: FAIL（mobile 无「当前欠款」label 紧凑行 / desktop 断言视现状）

- [ ] **Step 3: 改 `_AccountCard.build` 加断点分支** — 把现状 `Widget build(BuildContext context)`（L645-789）主体提取为 `_fullCard(BuildContext)`，新 `build` 用 LayoutBuilder 分发：

```dart
@override
Widget build(BuildContext context) {
  return LayoutBuilder(
    builder: (ctx, c) {
      if (c.maxWidth < 600) return _compactCard(context);
      return _fullCard(context);
    },
  );
}

/// desktop/tablet 完整卡（现状 build 主体，原样提取，不改逻辑）。
Widget _fullCard(BuildContext context) {
  // === 把现状 build(BuildContext) 的 L647-788 主体（final negative=... 到 return card;）原样搬入此方法 ===
  // （DataCard + Column[ac-top Row, ac-balance, _sublineWidget, _progressBar] + archived Opacity）
}
```

> `_fullCard` = 现状 L647-788 代码原样搬家（`final negative = ...` 起到 `return card;` 止），不改一字。

- [ ] **Step 4: 实现 `_compactCard`** — 新增方法（放在 `_fullCard` 后）：

```dart
/// mobile 紧凑行卡片（对齐 mobile.html .acc）。
/// 水平：aicon + (name + 机构·尾号) | (label + 余额)；下方虚线副信息 + 进度条。
Widget _compactCard(BuildContext context) {
  final a = account;
  final negative = a.currentBalanceCents < 0;
  final typeColor = categoryColor(a.category);
  final archived = a.status == AccountStatus.archived;
  final spec = _usageSpec(a); // (fraction, color)? — 复用，仅信用卡/贷款非 null
  final (label, val) = _compactVal(a); // (label, 格式化值)

  Widget card = DataCard(
    onTap: () => context.go('/accounts/${a.id}'),
    onLongPress: onLongPress,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // r1：aicon + amain + av
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(categoryIcon(a.category), size: 18, color: typeColor),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w600)),
                      ),
                      if (archived) ...[
                        const SizedBox(width: 6),
                        const Text('已归档',
                            style:
                                TextStyle(color: AppColors.muted, fontSize: 10)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subline(a),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 10.5)),
                const SizedBox(height: 2),
                Text(
                  val,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: negative ? AppColors.negative : AppColors.fg,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ],
            ),
          ],
        ),
        // 副信息（分隔）+ 进度条（若有）。
        if (_hasSub(a) || spec != null) ...[
          const SizedBox(height: 9),
          // asub：复用 _sublineWidget（类型副信息），实线 border-top 近似原型虚线
          // （Flutter 原生无 dotted；如需精确虚线后续用 dotted_border 包）。
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Container(
              padding: const EdgeInsets.only(top: 9),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: _sublineWidget(a),
            ),
          ),
        ],
        if (spec != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: spec.$1,
              minHeight: 5,
              backgroundColor: AppColors.accentSoft,
              valueColor: AlwaysStoppedAnimation<Color>(spec.$2),
            ),
          ),
        ],
      ],
    ),
  );
  if (archived) card = Opacity(opacity: 0.55, child: card);
  return card;
}

/// 紧凑行右侧 (label, value)：主数字按 category（对齐原型 describe()）。
(String, String) _compactVal(Account a) {
  switch (a.category) {
    case AccountCategory.creditCard:
      return ('当前欠款', formatCents(a.currentBalanceCents));
    case AccountCategory.loan:
      return ('剩余本金', formatCents(a.loanRemainingCents ?? 0));
    case AccountCategory.investment:
      return ('当前市值', formatCents(a.investMarketValueCents ?? 0));
    case AccountCategory.goldFx:
      final cur = a.goldCurrentPriceCents ?? 0;
      final qty = a.goldQuantity ?? 0;
      return ('当前现值', formatCents((cur * qty).toInt()));
    case AccountCategory.realEstate:
      return ('现估值', formatCents(a.estateCurrentValueCents ?? 0));
    case AccountCategory.fixedDeposit:
      return ('存单本金', formatCents(a.fixedPrincipalCents ?? 0));
    case AccountCategory.otherAsset:
      return ('账户金额', formatCents(a.currentBalanceCents));
    case AccountCategory.otherLiability:
      return ('待还金额', formatCents(a.currentBalanceCents));
    case AccountCategory.savings:
      return ('可用余额', formatCents(a.currentBalanceCents));
  }
}

/// 是否有类型副信息（紧凑行虚线下方）。储蓄无利率时无副信息。
bool _hasSub(Account a) {
  if (a.category == AccountCategory.savings &&
      a.interestRate == null) return false;
  return true;
}
```

> `_compactVal`/`_hasSub` 是 compact 专属；`_subline`/`_sublineWidget`/`_usageSpec` 共享（full + compact）。虚线用实线 border-top 近似（Flutter 原生无 dotted，原型虚线视觉差可接受；若要精确虚线后续用 `dotted_border` 包，但本任务用实线）。

- [ ] **Step 5: 运行测试通过 + analyze**

Run: `cd yucai/client && flutter test test/account/presentation/pages/accounts_page_test.dart && flutter analyze`
Expected: PASS + 0 error

- [ ] **Step 6: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/accounts_page.dart \
        yucai/client/test/account/presentation/pages/accounts_page_test.dart
git commit -m "feat(client): 账户卡 mobile 紧凑行布局（< 600 断点）"
```

---

## Task 3: `_GroupBlock` 列数 + aspect 响应式 + FilterBar 确认

**⚠️ 依赖 Task 2（同文件，mobile 紧凑行已存在）。**

**Files:**
- Modify: `accounts_page.dart` `_GroupBlock.build`（L566-595 LayoutBuilder）
- Check: `yucai/client/lib/core/widgets/filter_bar.dart`（mobile 横滚，大概率已 OK）
- Test: `accounts_page_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `_compactCard`（mobile < 600 自动渲染，`_GroupBlock` 只管列数 + aspect）
- Produces: `_GroupBlock` 三断点列数（1/2/auto-fill）+ aspect（compact ~3 / full 1.72）

**Why:** 现状 `_GroupBlock` auto-fill 280px + aspect 1.72（固定）。mobile 要 1 列 + compact aspect（紧凑行更矮）；tablet 2 列 + full aspect；desktop auto-fill + full。

- [ ] **Step 1: 写失败测试** — 追加三尺寸列数断言：

```dart
testWidgets('mobile: single column grid', (tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_harness([
    _account('a1', '储蓄1', cat: AccountCategory.savings, bal: 10000),
    _account('a2', '储蓄2', cat: AccountCategory.savings, bal: 20000),
  ]));
  await tester.pumpAndSettle();
  final grid = tester.widget<GridView>(find.byType(GridView).first);
  final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  expect(delegate.crossAxisCount, 1);
});

testWidgets('tablet: 2 columns', (tester) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_harness([
    _account('a1', '储蓄1', cat: AccountCategory.savings, bal: 10000),
    _account('a2', '储蓄2', cat: AccountCategory.savings, bal: 20000),
  ]));
  await tester.pumpAndSettle();
  final grid = tester.widget<GridView>(find.byType(GridView).first);
  final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  expect(delegate.crossAxisCount, 2);
});

testWidgets('desktop: auto-fill (>=3 cols at 1200)', (tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_harness([
    _account('a1', '储蓄1', cat: AccountCategory.savings, bal: 10000),
    _account('a2', '储蓄2', cat: AccountCategory.savings, bal: 20000),
    _account('a3', '储蓄3', cat: AccountCategory.savings, bal: 30000),
  ]));
  await tester.pumpAndSettle();
  final grid = tester.widget<GridView>(find.byType(GridView).first);
  final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  expect(delegate.crossAxisCount, greaterThanOrEqualTo(3));
});
```

- [ ] **Step 2: 运行验证失败**

Run: `cd yucai/client && flutter test test/account/presentation/pages/accounts_page_test.dart`
Expected: FAIL（现状 mobile/tablet 都 auto-fill，非 1/2 列）

- [ ] **Step 3: 改 `_GroupBlock` LayoutBuilder** — 替换 L566-595 的 LayoutBuilder：

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final gap = 14.0;
    int cols;
    double aspect;
    if (constraints.maxWidth < 600) {
      // mobile：1 列，紧凑行（更矮）。
      cols = 1;
      aspect = 3.0; // 紧凑行：宽 ~360 / 高 ~120
    } else if (constraints.maxWidth < 1100) {
      // tablet：2 列，完整卡。
      cols = 2;
      aspect = 1.72;
    } else {
      // desktop：auto-fill 280px，完整卡。
      final colWidth = 280.0;
      cols = ((constraints.maxWidth + gap) / (colWidth + gap)).floor();
      if (cols < 1) cols = 1;
      aspect = 1.72;
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        childAspectRatio: aspect,
      ),
      itemCount: accounts.length,
      itemBuilder: (_, i) => _AccountCard(
        account: accounts[i],
        formatCents: formatCents,
        onLongPress: () => onDelete(accounts[i]),
        onEdit: () => onEdit(accounts[i]),
        onDuplicate: () => onDuplicate(accounts[i]),
        onClose: () => onClose(accounts[i]),
        onReactivate: () => onReactivate(accounts[i]),
        onDelete: () => onDelete(accounts[i]),
      ),
    );
  },
),
```

> compact aspect 3.0 是估值（紧凑行实际高度视副信息/进度条有无）。若测试/视觉偏差，微调 2.5–3.5。`_AccountCard.build` 内部 LayoutBuilder 会基于同一 `< 600` 判定渲染 compact，与列数一致。

- [ ] **Step 4: 确认 FilterBar mobile 横滚** — 读 `yucai/client/lib/core/widgets/filter_bar.dart`。若 mobile（窄屏）已横向滚动（`SingleChildScrollView(scrollDirection: Axis.horizontal)` 或 chips 用 Row + Expanded 自适应），无需改。若否（chips 换行或溢出），在 FilterBar 外层包横向滚动：

```dart
// 仅当 FilterBar mobile 不横滚时改（否则跳过此 step）：
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(children: tabs.map((t) => ...).toList()),
)
```

在 report 记录 FilterBar 是否需改 + 改了什么。若已横滚，report「FilterBar 已支持横滚，未改」。

- [ ] **Step 5: 运行测试通过 + 全页 analyze**

Run: `cd yucai/client && flutter test test/account/presentation/pages/accounts_page_test.dart && flutter analyze`
Expected: PASS（三尺寸列数断言）+ 0 error

- [ ] **Step 6: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/accounts_page.dart \
        yucai/client/test/account/presentation/pages/accounts_page_test.dart
git commit -m "feat(client): 账户分组网格响应式（mobile 1列紧凑 / tablet 2列 / desktop auto-fill）"
```

---

## Self-Review

**1. Spec coverage:**
- ✅ mobile `<600` 紧凑行卡 → Task 2 `_compactCard` + Task 3 列数 1
- ✅ tablet `600-1099` 2 列完整卡 → Task 3 列数 2（卡片用现状 `_fullCard`）
- ✅ desktop `>=1100` auto-fill → Task 3 保留
- ✅ `_AccountsHeader` 改造 sumcard → Task 1
- ✅ mobile 汇总卡（去 count） → Task 1 `_mobileCard`
- ✅ 类型副信息 + 进度条复用 → Task 2 复用 `_sublineWidget`/`_usageSpec`
- ✅ FilterBar mobile 横滚确认 → Task 3 Step 4
- ✅ 外壳/底部 tab 由 AppShell → 不改（spec 4.3）
- ✅ 三尺寸 widget 测试 → Task 1/2/3 各自 + Task 3 列数断言

**2. Placeholder scan:** 无 TBD/TODO。Task 2 Step 5 已修正 asub 容器语法（Border → BoxDecoration）。Task 3 Step 4 FilterBar 是条件确认（读现状决定改否）+ 给 fallback 代码——可接受（非 placeholder，是 conditional + fallback）。Task 2 `_fullCard` 指明"现状 L647-788 原样搬家"——implementer 读现状提取（非重写，是搬家）。

**3. Type consistency:**
- `_AccountsHeader` 新签名 `{netCents, assetCents, liabCents, onAdd}`（Task 1）→ `_content` 调用一致（Task 1 Step 3）
- `_AccountCard.build` → `_fullCard`/`_compactCard`（Task 2）→ `_GroupBlock` 调 `_AccountCard` 不变（Task 3）
- `_compactVal`/`_hasSub`（Task 2 新增）→ `_compactCard` 内用，签名 `(String,String)` / `bool`
- 断点 `< 600` / `600-1099` / `>= 1100` 三任务一致

**4. 串行约束** Task 1→2→3 同文件，已标注。
