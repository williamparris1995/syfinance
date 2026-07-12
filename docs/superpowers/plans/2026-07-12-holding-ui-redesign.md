# Holding UI 重设计 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 回退 holding-module-nav 的二级侧栏(SubMenuShell),改页内 tab;holding 4 页(列表/Security/收益/goals)对齐 OD 设计语言(御财 token 严格)。

**Architecture:** 删 `core/widgets/sub_menu_shell.dart` + router branch 5 去 `ShellRoute`(回 `/holdings` GoRoute + children,trade/new 静态在 `:id` 前)。新建 `HoldingModuleTabs`(4 格金下划线,路由感知)。4 页顶部加 tab + 视觉对齐 OD 原型(HTML,subagent `get_artifact` 拉源码转 Flutter)。

**Tech Stack:** Flutter(纯 client)· go_router 14.6.1 · flutter_bloc · lucide_icons_flutter · 现有 AppColors token + fl_chart。

**Spec:** `docs/superpowers/specs/2026-07-12-holding-ui-redesign-design.md`

## Global Constraints

- **御财 token**(严格,spec §2 verbatim):bg `#faf9f5` / surface `#fff` / surface-2 `#f6f4ee` / border `#e6e5e0` / fg `#232019` / fg-2 `#54504a` / muted `#8c8578` / **gold `#b08d57`** accent **点缀**(active tab/主按钮/进度条/超额,非泛滥)/ gold-deep `#94703f` / gold-soft `#f3ebdd` / **green `#2e7d32`** 盈 / **red `#c0392b`** 亏 / sidebar `#1c1e21`。
- **衬线 display**(Georgia + Noto Serif SC,h1 26px)/ **mono tabular-nums**(所有数字)/ **盈绿亏红仅盈亏**(年化/bench/目标计数中性)/ **lucide inline SVG**(1.6–1.8px stroke,无 emoji)/ **全站无渐变**。
- **中文 UI 直写**(御财惯例,非 i18n)。
- 桌面 ≥1100;页内 tab 横向(4 格,窄屏横滚,无需降级)。
- 复用 `core/widgets/`(data_card 等)+ holding 现有 DDD 四层(domain/data/presentation+bloc)。
- `flutter analyze` 22 `*.pbserver.dart` 基线(预存);`flutter test` 3 预存 fail(account_detail/debt_detail/transaction_detail_page,非本次引入)。
- OD 原型源(实现时 `mcp__open-design__get_artifact` 拉):
  - `yucai-holding-ui-redesign-f494` / `holdings-desktop.html`(列表)
  - `yucai-holding-pages-v2-abe4` / `security-desktop.html`、`performance-desktop.html`、`goals-desktop.html`

## File Structure

| 文件 | 职责 | 操作 |
|---|---|---|
| `yucai/client/lib/core/widgets/sub_menu_shell.dart` | 旧二级侧栏(Task 1 删) | **Delete** |
| `yucai/client/lib/holding/presentation/widgets/holding_module_tabs.dart` | 页内 tab(4 格金下划线,路由感知) | **Create** |
| `yucai/client/test/holding/presentation/widgets/holding_module_tabs_test.dart` | tab 组件 test | **Create** |
| `yucai/client/lib/app/router.dart` | branch 5 去 ShellRoute,回 GoRoute+children | **Modify** |
| `yucai/client/lib/holding/presentation/pages/holdings_page.dart` | 加 tab + 对齐 OD 列表 | **Modify** |
| `yucai/client/lib/holding/presentation/pages/security_page.dart` | 加 tab + 对齐 OD Security | **Modify** |
| `yucai/client/lib/holding/presentation/pages/performance_page.dart` | 加 tab + 对齐 OD 收益 | **Modify** |
| `yucai/client/lib/holding/presentation/pages/goal_link_page.dart` | 加 tab + 对齐 OD 目标 | **Modify** |
| `yucai/client/lib/core/theme/app_design.dart` | 补御财 token(若缺) | **Modify**(按需) |

---

### Task 1: 回退 SubMenuShell + router 去 ShellRoute

**Files:**
- Delete: `yucai/client/lib/core/widgets/sub_menu_shell.dart`
- Modify: `yucai/client/lib/app/router.dart`(branch 5,约 520-710 行)

**Interfaces:**
- Consumes: 现有 router(branch 5 ShellRoute 结构)
- Produces: branch 5 回到 `/holdings` GoRoute + children(各页独立,trade/new 静态在 `:id` 前)

- [ ] **Step 1: 删 sub_menu_shell.dart**

```bash
git rm yucai/client/lib/core/widgets/sub_menu_shell.dart
```

同时删其测试(若存在 `test/core/widgets/sub_menu_shell_test.dart`):

```bash
git rm -f yucai/client/test/core/widgets/sub_menu_shell_test.dart 2>/dev/null || true
```

- [ ] **Step 2: 改 router branch 5 — 去 ShellRoute,回 GoRoute+children**

读 `lib/app/router.dart` branch 5(当前 `StatefulShellBranch(routes:[GoRoute(/holdings/trade), GoRoute(/holdings/new), ShellRoute(builder: SubMenuShell, routes:[/holdings, /holdings/security, /holdings/performance, /holdings/goals, /holdings/:id])])`)。

替换整个 branch 5 `StatefulShellBranch(...)` 为(回退到 `/holdings` GoRoute + 相对 children,各 GoRoute 的 builder 体**逐字保留**只挪位置 + path 相对化):

```dart
          // 持仓管理(branch 5):页内 tab 导航(各页自带 HoldingModuleTabs)。
          // 回退二级侧栏(SubMenuShell);子路由:/holdings + children。
          // ⚠️ 静态(trade/new/security/performance/goals)在 :id 前(GoRouter 匹配优先级)。
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/holdings',
                builder: (_, __) => MultiBlocProvider(
                  /* 原 /holdings builder 体逐字保留(HoldingBloc LoadHoldings + CurrencyBloc + HoldingsPage) */
                ),
                routes: [
                  GoRoute(path: 'trade', builder: (_, state) { /* 原 trade builder 体 */ }),
                  GoRoute(path: 'new', builder: (_, __) { /* 原 new builder 体 */ }),
                  GoRoute(path: 'security', builder: (_, __) { /* 原 security builder 体 */ }),
                  GoRoute(path: 'performance', builder: (_, __) { /* 原 performance builder 体 */ }),
                  GoRoute(path: 'goals', builder: (_, state) { /* 原 goals builder 体 */ }),
                  GoRoute(path: ':id', builder: (_, state) { /* 原 :id builder 体 */ }),
                ],
              ),
            ],
          ),
```

**关键**:删 `ShellRoute` wrapper + `_holdingNavItems` 常量 + `import sub_menu_shell.dart`;各 GoRoute builder 体(_bloc provide + 页面)**逐字保留**,只挪到 `/holdings` 的 children(path 改相对:`security` 而非 `/holdings/security`)。trade/new 从 branch 级回 `/holdings` children(静态在 `:id` 前,优先级自然满足)。

- [ ] **Step 3: analyze 验证编译**

Run: `flutter analyze lib/app/router.dart lib/core/`
Expected: 0 error(22 `*.pbserver` 基线忽略)。`sub_menu_shell.dart` 引用应已清(grep `sub_menu_shell` 全仓 0)。

- [ ] **Step 4: router_test 验证**

Run: `flutter test test/app/router_test.dart`
Expected: 现有 router_test 通过(branch 5 仍可达;若 router_test 有 ShellRoute 相关断言需同步改)。

- [ ] **Step 5: commit**

```bash
git add -A yucai/client/lib/app/router.dart yucai/client/lib/core/widgets/sub_menu_shell.dart yucai/client/test/core/widgets/sub_menu_shell_test.dart
git commit -m "refactor(holding-ui): 回退 SubMenuShell 二级侧栏,router 回 GoRoute+children(页内 tab 前置)"
```

---

### Task 2: HoldingModuleTabs 组件(页内 tab)

**Files:**
- Create: `yucai/client/lib/holding/presentation/widgets/holding_module_tabs.dart`
- Test: `yucai/client/test/holding/presentation/widgets/holding_module_tabs_test.dart`

**Interfaces:**
- Consumes: `AppColors`(token)、`go_router`(`GoRouterState.of` + `context.go`)、`lucide_icons`
- Produces: `HoldingModuleTabs()`(无参,4 格金下划线,路由感知 active)—— Task 3-6 各页顶部插入

- [ ] **Step 1: 写失败测试**

Create `test/holding/presentation/widgets/holding_module_tabs_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_module_tabs.dart';

Widget _routed(String initial) => MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(path: '/holdings', builder: (_, __) => const Column(children: [HoldingModuleTabs(), Expanded(child: SizedBox())])),
          GoRoute(path: '/holdings/security', builder: (_, __) => const Column(children: [HoldingModuleTabs(), Expanded(child: SizedBox())])),
          GoRoute(path: '/holdings/performance', builder: (_, __) => const Column(children: [HoldingModuleTabs(), Expanded(child: SizedBox())])),
          GoRoute(path: '/holdings/goals', builder: (_, __) => const Column(children: [HoldingModuleTabs(), Expanded(child: SizedBox())])),
        ],
      ),
    );

void main() {
  testWidgets('渲染 4 个 tab', (tester) async {
    await tester.pumpWidget(_routed('/holdings'));
    expect(find.text('持仓列表'), findsOneWidget);
    expect(find.text('Security 管理'), findsOneWidget);
    expect(find.text('收益统计'), findsOneWidget);
    expect(find.text('投资目标'), findsOneWidget);
  });

  testWidgets('当前路由 tab active(金下划线)', (tester) async {
    await tester.pumpWidget(_routed('/holdings/security'));
    // active tab 文字加粗(fontWeight w600);非 active w500。
    final secText = tester.widget<Text>(find.text('Security 管理'));
    expect(secText.style?.fontWeight, FontWeight.w600);
    final listText = tester.widget<Text>(find.text('持仓列表'));
    expect(listText.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('点击 tab 触发 context.go', (tester) async {
    await tester.pumpWidget(_routed('/holdings'));
    await tester.tap(find.text('投资目标'));
    await tester.pumpAndSettle();
    expect(GoRouterState.of(tester.element(find.text('投资目标'))).matchedLocation, '/holdings/goals');
  });
}
```

- [ ] **Step 2: 运行测试,确认失败**

Run: `flutter test test/holding/presentation/widgets/holding_module_tabs_test.dart`
Expected: FAIL — `holding_module_tabs.dart` 不存在。

- [ ] **Step 3: 写组件实现**

Create `lib/holding/presentation/widgets/holding_module_tabs.dart`:

```dart
// holding 模块页内 tab 导航(4 格金下划线,替代二级侧栏)。
// 对齐 OD 原型(open-design yucai-holding-ui-redesign-f494/holdings-desktop.html .tabs):
// 4 格(持仓列表/Security 管理/收益统计/投资目标),当前路由 active 金下划线。
// 放各 holding 页顶部(page-head 下)。横向 4 格,窄屏横滚。
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yucai_client/core/theme/app_design.dart';

const _tabs = <_Tab>[
  _Tab('持仓列表', '/holdings'),
  _Tab('Security 管理', '/holdings/security'),
  _Tab('收益统计', '/holdings/performance'),
  _Tab('投资目标', '/holdings/goals'),
];

class _Tab {
  const _Tab(this.label, this.route);
  final String label;
  final String route;
}

class HoldingModuleTabs extends StatelessWidget {
  const HoldingModuleTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final current = GoRouterState.of(context).matchedLocation;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in _tabs)
              _TabItem(
                label: t.label,
                active: current == t.route,
                onTap: () => context.go(t.route),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.fg : AppColors.muted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: active ? AppColors.accent : Colors.transparent,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
```

(`AppColors.accent` = 金 `#b08d57`;`AppColors.fg`/`muted`/`border` 见 app_design.dart。Task 1 后 `AppColors.accent` 若不可用,用 `const Color(0xFFB08D57)`。)

- [ ] **Step 4: 运行测试,确认通过**

Run: `flutter test test/holding/presentation/widgets/holding_module_tabs_test.dart`
Expected: PASS(3 tests)。

- [ ] **Step 5: analyze + commit**

```bash
git add yucai/client/lib/holding/presentation/widgets/holding_module_tabs.dart yucai/client/test/holding/presentation/widgets/holding_module_tabs_test.dart
git commit -m "feat(holding-ui): HoldingModuleTabs 页内 tab 组件(4 格金下划线,路由感知)"
```

---

### Task 3: holdings_page 加 tab + 对齐 OD 列表

**Files:**
- Modify: `yucai/client/lib/holding/presentation/pages/holdings_page.dart`

**Interfaces:**
- Consumes: Task 2 `HoldingModuleTabs`、OD `holdings-desktop.html`(参照)
- Produces: holdings_page 顶部含 tab + 视觉对齐 OD

- [ ] **Step 1: 拉 OD 源码参照**

```python
mcp__open-design__get_artifact(project="yucai-holding-ui-redesign-f494", entry="holdings-desktop.html", include="shallow")
```

读 OD `holdings-desktop.html` 的 `.page-head`(h1 + sub + search + refresh + 添加持仓 gold btn)、`.tabs`、`.stat-row`(4 StatCard)、`.desk-grid`(donut ‖ 表)、`.ccy-bar` 结构 + token。

- [ ] **Step 2: holdings_page 顶部插入 HoldingModuleTabs**

现有 `build()`:`Scaffold(body: Column(children:[Expanded(BlocBuilder)])])`。改为在 Column 顶部加 `const HoldingModuleTabs()`:

```dart
body: Column(
  children: [
    const HoldingModuleTabs(),   // ← 新增(页内 tab,持仓列表 active)
    Expanded(
      child: BlocBuilder<HoldingBloc, HoldingState>(...),  // 现有体保留
    ),
  ],
),
```

加 import:`import 'package:yucai_client/holding/presentation/widgets/holding_module_tabs.dart';`

- [ ] **Step 3: 视觉对齐 OD(token + 布局)**

对照 OD `holdings-desktop.html` 检查/调整现有 holdings_page(现有 holding-late-align 已部分对齐):
- **page-head**:h1 衬线「持仓列表」+ sub「共 N 只 · 跨 N 账户 · CNY 视图」+ search + refresh icon-btn + 添加持仓 gold btn(若现有缺,补;若有,对齐 token)
- **4 StatCard**:gold-soft icon bg + mono value + sub;盈亏色仅盈亏值(总盈亏/收益率)
- **desk-grid**:资产配置 donut(conic + legend)‖ 持仓表(8 列 sortable)—— 现有 `_AllocCard`/`_HoldingList` 对齐
- **多币种汇总条**:金强调合计
- 金仅点缀(active/主按钮/合计),无渐变

按 OD 源码逐区域对照,差距处修(现有复用优先,不重写已对齐的)。

- [ ] **Step 4: widget test + analyze**

Run: `flutter test test/holding/presentation/pages/holdings_page_test.dart`
Expected: PASS(现有测试 + 新 tab 断言;若现有测试断言 HoldingModuleNav 已在 holding-module-nav Task3 清,这里只验 tab 渲染)。

Run: `flutter analyze lib/holding/presentation/pages/holdings_page.dart`
Expected: 0 error。

- [ ] **Step 5: commit**

```bash
git add yucai/client/lib/holding/presentation/pages/holdings_page.dart
git commit -m "feat(holding-ui): holdings_page 加页内 tab + 对齐 OD 列表(token/布局)"
```

---

### Task 4: security_page 加 tab + 对齐 OD Security

**Files:**
- Modify: `yucai/client/lib/holding/presentation/pages/security_page.dart`

**Interfaces:**
- Consumes: Task 2 `HoldingModuleTabs`、OD `security-desktop.html`

- [ ] **Step 1: 拉 OD 源码**

```python
mcp__open-design__get_artifact(project="yucai-holding-pages-v2-abe4", entry="security-desktop.html", include="shallow")
```

- [ ] **Step 2: 顶部插 HoldingModuleTabs(Security 管理 active)**

同 Task 3 Step 2,Column 顶部加 `const HoldingModuleTabs()`(路由 `/holdings/security` 自动 active Security 管理)。

- [ ] **Step 3: 视觉对齐 OD**

对照 `security-desktop.html`:page-head(h1「Security 管理」+ sub 行情源新浪 + search + refresh + 新建 gold-soft)+ 筛选 chips + 证券主表(8 列)+ 行内改价(点现价→input→保存/取消)+ 行情源 chip(只读)+ 同步时间 + 手动刷新。现有 security_page 对齐 token + 布局(复用优先)。

- [ ] **Step 4: test + analyze + commit**

Run: `flutter test test/holding/presentation/pages/security_page_test.dart && flutter analyze lib/holding/presentation/pages/security_page.dart`
commit:`feat(holding-ui): security_page 加页内 tab + 对齐 OD Security`

---

### Task 5: performance_page 加 tab + 对齐 OD 收益

**Files:**
- Modify: `yucai/client/lib/holding/presentation/pages/performance_page.dart`

**Interfaces:**
- Consumes: Task 2 `HoldingModuleTabs`、OD `performance-desktop.html`

- [ ] **Step 1: 拉 OD 源码**

```python
mcp__open-design__get_artifact(project="yucai-holding-pages-v2-abe4", entry="performance-desktop.html", include="shallow")
```

- [ ] **Step 2: 顶部插 HoldingModuleTabs(收益统计 active)**

- [ ] **Step 3: 视觉对齐 OD**

对照 `performance-desktop.html`:page-head(h1「收益统计」+ sub 总市值/盈亏/基准 + 区间 segmented 日/月/年)+ 4 stat(年化计数中性)+ 总收益曲线(组合金 vs 沪深300 灰 dashed,现有 `perf_curve_chart` 对齐)+ realized/unrealized 分解 + bench-mini(现有 `_BenchmarkMiniBar` 对齐)+ 持仓贡献条。盈绿亏红仅盈亏/贡献条。

- [ ] **Step 4: test + analyze + commit**

Run: `flutter test test/holding/presentation/pages/performance_page_test.dart && flutter analyze lib/holding/presentation/pages/performance_page.dart`
commit:`feat(holding-ui): performance_page 加页内 tab + 对齐 OD 收益`

---

### Task 6: goal_link_page 加 tab + 对齐 OD 目标

**Files:**
- Modify: `yucai/client/lib/holding/presentation/pages/goal_link_page.dart`

**Interfaces:**
- Consumes: Task 2 `HoldingModuleTabs`、OD `goals-desktop.html`

- [ ] **Step 1: 拉 OD 源码**

```python
mcp__open-design__get_artifact(project="yucai-holding-pages-v2-abe4", entry="goals-desktop.html", include="shallow")
```

- [ ] **Step 2: 顶部插 HoldingModuleTabs(投资目标 active)**

- [ ] **Step 3: 视觉对齐 OD**

对照 `goals-desktop.html`:page-head(h1「投资目标」+ sub 跨账户总览 + 新建 gold-soft)+ 4 stat(总数/超目标/进行中/落后,**计数中性** + 角标 icon 状态色)+ 目标卡(monogram + 名 + status badge + 关联持仓 chips + 当前/目标 mono + **金进度条%**,落后红/超目标绿)。保留空 holding 跨账户逻辑(2026-07-11 final fix)。

- [ ] **Step 4: test + analyze + commit**

Run: `flutter test test/holding/presentation/pages/goal_link_page_test.dart && flutter analyze lib/holding/presentation/pages/goal_link_page.dart`
commit:`feat(holding-ui): goal_link_page 加页内 tab + 对齐 OD 目标`

---

### Task 7: 全量验证 + desktop GUI 确认

**Files:** 无改动(验证)

- [ ] **Step 1: 全量 analyze**

Run: `flutter analyze`
Expected: 0 非 pbserver error(22 `*.pbserver` 基线)。

- [ ] **Step 2: 全量 flutter test**

Run: `flutter test`
Expected: 仅 account_detail/debt_detail/transaction_detail_page 3 预存 fail;holding 套件 + holding_module_tabs_test 全 PASS。

- [ ] **Step 3: build windows**

Run: `flutter build windows --debug`
Expected: 绿(kill 残留 yucai_client 进程若 MSB3073)。

- [ ] **Step 4: desktop GUI 视觉确认(用户手动)**

Run: `flutter run -d windows`,登录后核对:
1. 全局侧栏「投资组合」→ holdings_page 顶部 4 格 tab(持仓列表 active 金下划线)+ StatCard + desk-grid + 多币种条
2. 点 tab 切 Security/收益/目标(各页 tab active,无二级侧栏)
3. trade/new(详情 FAB/顶栏创建)→ trade sheet(push,无 tab/侧栏)
4. 缩窗 <1100:tab 横滚,布局堆叠

对照 OD preview(holdings f494 / security·performance·goals v2-abe4)。

- [ ] **Step 5: 更新 progress ledger + commit(若有 fix)**

更新 `.superpowers/sdd/progress.md`(holding-ui-redesign section)。

---

## Self-Review

**1. Spec coverage**:
- §1 导航(页内 tab 替代二级侧栏)→ Task 1(回退)+ Task 2(tab)+ Task 3-6(各页加 tab)✓
- §2 御财 token → Global Constraints + Task 3-6 视觉对齐 ✓
- §3 4 页布局 → Task 3-6(各页 OD 参照)✓
- 实现(删 SubMenuShell + HoldingModuleTabs + router + 4 页)→ Task 1-6 ✓
- 测试 → Task 2 tab test + Task 3-6 页 test + Task 7 全量 ✓
- 范围(UI,XIRR out-of-scope)→ Global Constraints ✓

**2. Placeholder scan**:Task 1 router builder 体用注释「原 builder 体逐字保留」(因具体代码在现有 router,subagent 读现状保留)—— 这是指引(保留现有 builder),非占位;Task 3-6 视觉对齐 OD(get_artifact 拉源码)—— OD 是真实参照。Task 1 Step 2 给了完整结构骨架 + 关键约束(逐字保留 builder + path 相对化)。

**3. Type consistency**:`HoldingModuleTabs()` 无参(Task 2 定义,Task 3-6 消费一致);`AppColors.accent`/fg/muted/border(Task 2 用,Task 3-6 同)。

**风险**:
- Task 1 router 回退:删 ShellRoute 后 trade/new 回 `/holdings` children,路由优先级(静态前)自然满足(同 list 顺序)。subagent 看现有 router(ShellRoute 结构)改回。
- Task 3-6 OD→Flutter 转译:OD 是 HTML,Flutter 转译用现有 widget(fl_chart/Painting/DataTable 等);现有页(holding-late-align)已部分对齐,Task 3-6 主要是加 tab + 视觉微调(token/布局),非全重写。
- `AppColors.accent`:确认 app_design.dart 有(`#b08d57`,app_shell 用过);若无,用 `Color(0xFFB08D57)`。
