# 御财账户管理 · Tablet/Mobile 响应式设计

- **日期**: 2026-06-21
- **状态**: 设计已确认（OD 原型生成 + 用户批准），待转实施计划
- **范围**: 账户管理**列表页**（`AccountsPage`）的 tablet + mobile 响应式布局
- **分支**: main（P0 完善已 merge，HEAD `0baa776`）
- **原型**: Open Design 项目 `yucai-account-mobile-tablet-a279`，本地副本 `design-output/accounts-responsive/`

## 1. 概述

御财账户管理页（`accounts.html`）原只有 desktop 原型 + 基础 `<720px` 单列响应式 CSS，**无独立 tablet/mobile 原型图**。交易（`yucai-transaction-trisize-9d3e`）与分类管理（`yucai-category-management-db5f`）已有完整 desktop/tablet/mobile 三尺寸原型。

本设计用 Open Design 生成 accounts 的 tablet + mobile 原型（`mobile.html` + `tablet.html`，已 copy 到 `design-output/accounts-responsive/`），并定义 Flutter `AccountsPage` 对齐原型的响应式实现方向。

**不包含**（后续独立 spec）：账户**详情页** + **表单页**的 tablet/mobile（当前只 `detail-account.html` desktop）。本 spec 仅列表页。

## 2. 原型设计（OD 生成，权威源）

两文件在 `design-output/accounts-responsive/`，自包含 HTML（`:root` 令牌 + 数据 + JS 渲染），浏览器直接打开预览。

### 2.1 mobile.html（390×844 phone frame）

**外壳**（御财 mobile 既定语言，对齐分类管理 mobile）：
- `body` 灰底 `#e7e4db` 居中；`.phone` 390×844，`bg #f7f6f2`，flex-column
- **status bar**（44px）：左 `9:41`，右信号 + wifi + 电池 SVG
- **topbar**（52px）：左返回 `‹` + serif 19px「账户管理」+ 右 accent `#b08d57` 圆形「+」新建按钮
- **底部 tab bar**（72px）：首页 / 交易 / 中央凸起 FAB「+」(accent 圆 52px，上浮 -18px，3px 白边) / 报表 / 我的（active=accent）—— **Flutter 由 `AppShell._BottomNav` 提供（< 1100px 自动切换），`AccountsPage` 不重复实现**

**内容区**（`.scroll` flex-1 overflow-y）：
- **汇总卡**：白底圆角 lg + 右上 `accent-soft #f3ebdd` 圆形装饰（124px，offset -38/-32）+ 「全部账户余额合计」label + 净资产 `mono 27px` + meta「资产 `<income>` ¥X · 负债 `<expense>` ¥X」
- **类型 chip 横滚行**：`全部 14 / 储蓄 3 / 信用卡 2 / 投资 2 / 定期 1 / 黄金 2 / 房产 1 / 贷款 1 / 其他资产 1 / 其他负债 1`，active = `#1a1916` 深色填充白字，非 active = 白底 border，`overflow-x auto` 隐藏滚动条
- **按类型分组**：每组（`.group-head`：28px emoji 圆图标(类型色底) + 类型名 15px + 数量 11.5px muted + 右小计 `mono 13.5px`，负债红）→ 该组账户卡片

**mobile 卡片形态**（`.acc` 紧凑行，OD 自行决策——平衡密度与信息）：
```
┌─────────────────────────────────────┐
│ (emoji) 账户名           label  ¥余额 │  ← r1: aicon 36px + amain(aname 14.5px / aorg 11.5px 机构·尾号) | av(avlabel 10.5px / aval mono 15px，负债红)
│         机构·尾号                    │
│ ─────────────────────────────────── │  ← asub 虚线分隔（仅当有副信息/进度条）
│ 利率 1.90% / 副信息                  │  ← asub 11.5px muted，关键词 <b> fg
│ ████████░░░░  (进度条，仅信用卡/贷款) │  ← bar 5px 圆角（accent-soft 底），信用卡红/贷款绿
└─────────────────────────────────────┘
```
- 点击 → `detail-account.html`

### 2.2 tablet.html（900px）

- `body` 灰底；`.wrap` 900px 居中
- **pagerow**：左面包屑「御财 YuCai / **账户管理**」+ 右 brand「YUCAI · 御财」serif accent
- **汇总头白卡**（`.sumcard`）：accent-soft 圆装饰 + 净资产（serif 30px，¥前缀 18px muted）+ vline 分隔 + 总资产（mono 19px 绿）+ vline + 总负债（mono 19px 红）+ 右「+ 新建账户」按钮（accent 胶囊 40px，hover accent-press）
- **chip 行**（同 mobile，32px 高）
- **按类型分组**：组头（34px emoji 圆图标 + 名 17px + 数量 + 右小计「小计 ¥X」）+ **2 列卡片网格**（`.grid grid-template-columns:1fr 1fr` gap 14）

**tablet 卡片形态**（`.card` 完整卡，保留 desktop 丰富度）：
```
┌─────────────────────────────────────┐
│ (emoji) 账户名          label  ¥余额  │  ← r1: cicon 44px + cmain(cname 16px / corg 12.5px) | cv(cvlabel / cval mono 21px)
│         机构·尾号                     │
│ ───────────────────────────────────  │  ← csub 实线分隔（border-top）
│ 利率 1.90% / 类型专属副信息            │  ← csub 12.5px
│ ████████████░░░░░  bar               │  ← bar 6px（仅信用卡/贷款）
│ 已用 ¥12,400 / ¥80,000      15.5%    │  ← bar-meta（已用/已还 文本 + 百分比，仅进度条卡）
└─────────────────────────────────────┘
```
- hover：translateY(-2px) + shadow

## 3. 类型显示规则（mobile + tablet 一致，复用现有逻辑）

主数字 label + 值 + 颜色 + 副信息 + 可选进度条，按 `Account.category` 分支（与 desktop `accounts_page._sublineWidget` / `_usageSpec` 一致）：

| 类型 | 主数字 label | 颜色 | 副信息 | 进度条 |
|------|-------------|------|--------|--------|
| 储蓄 | 可用余额 | fg | 利率 X% | 无 |
| 信用卡 | 当前欠款 | expense 红 | 额度 ¥X · 账单N日 / 还款M日 | 已用/额度 红 bar |
| 投资 | 当前市值 | fg | 今年 +X%（正绿负红） | 无 |
| 定期 | 存单本金 | fg | 到期 YYYY-MM-DD · 利率 X% | 无 |
| 黄金 | 当前现值(now×qty) | fg | 买入 ¥X · 涨幅 ±X% | 无 |
| 房产 | 现估值 | fg | 买入 ¥X · 增值 +X% | 无 |
| 贷款 | 剩余本金 | expense 红 | 原始 ¥X · 月供 ¥X · 下次 YYYY-MM-DD | 已还比例 绿 bar |
| 其他资产 | 账户金额 | fg | （无） | 无 |
| 其他负债 | 待还金额 | expense 红 | （无） | 无 |

## 4. Flutter 实现方向（AccountsPage 响应式）

### 4.1 现状（已实现）

`yucai/client/lib/account/presentation/pages/accounts_page.dart`：
- `_content`：`SingleChildScrollView` + `ConstrainedBox(maxWidth: 1120)` + Column[\_AccountsHeader, FilterBar, 分组]
- `_GroupBlock`：`LayoutBuilder` 算列数（`cols = floor((maxWidth+14)/(280+14))`，min 1）+ `GridView.builder`
- `_AccountCard`：**固定形态**（ac-top 图标+名+机构·尾号 / ac-balance / ac-sublineWidget / ac-bar 信用卡红·贷款绿）—— 不随断点变
- `AppShell`（`app/widgets/app_shell.dart`）：`>= 1100px` 侧栏 + topbar；`< 1100px` 底部 `_BottomNav` + 简化 topbar —— **移动端外壳已就绪**

### 4.2 目标（对齐原型）

加 mobile 断点切换**卡片形态**（外壳/底部 nav 由 AppShell 负责，本页只管内容）：

| 断点 | 宽度 | 卡片形态 | 汇总头 | 分组网格 |
|------|------|---------|--------|---------|
| desktop | `>= 1100px` | 现状 `_AccountCard`（完整卡） | `_AccountsHeader` 改造对齐原型 sumcard（serif 净资产 + 总资产 + 总负债 + 新建按钮） | auto-fill 280px（现状） |
| tablet | `600–1099px` | 现状 `_AccountCard`（完整卡） | 同 desktop sumcard（maxWidth 收窄） | **固定 2 列** |
| mobile | `< 600px` | **紧凑行变体** `_AccountCard.compact` | **原型汇总卡**：净资产 mono + "资产 ¥X · 负债 ¥X" meta（去 count 行）+ 保留 `_NewAccountButton` | **1 列**（紧凑行堆叠） |

**关键改动**：
1. `_AccountCard` 加 mobile 紧凑行布局分支（`LayoutBuilder` 或 `MediaQuery` 判 `< 600`）：水平 `Row[aicon 36 + amain(name+org) + av(label+val)]` + 下方虚线 `asub`（副信息）+ `bar`（进度条）—— 对齐原型 `.acc`
2. `_GroupBlock` 列数逻辑：`< 600` → 1 列紧凑行；`600–1099` → 2 列；`>= 1100` → auto-fill 280px（现状）
3. `_AccountsHeader` 改造对齐原型汇总头：desktop/tablet 用原型 sumcard（serif 净资产 + 分隔线 + 总资产 + 总负债 + `_NewAccountButton`）；mobile 用原型汇总卡（净资产 mono 大字 + "资产 ¥X · 负债 ¥X" meta，**去 count 行**）。**保留 `_NewAccountButton` 在汇总头**，不改 `AppShell._TopBar`。
4. 类型 chip 横滚：`FilterBar` 现状已横向；mobile 确认 `overflow-x scroll` + 隐藏滚动条（对齐原型）
5. tablet 汇总头 = desktop sumcard（同改动 3），现状 `_AccountsHeader`（RichText 合计 + count）需整体改造为原型 sumcard 风格（desktop/tablet 共用，mobile 紧凑变体）

### 4.3 不改的

- `_AccountCard` 的类型副信息逻辑（`_sublineWidget`）+ 进度条逻辑（`_usageSpec`）—— 已对齐原型规则，复用
- `AppShell` 外壳（侧栏/底部 nav/topbar 切换）—— 已就绪
- 数据层（AccountBloc / accounts 数据）—— 不变
- 详情页 / 表单页 —— 不在本 spec

## 5. 御财 token（严格遵循，已在 `core/theme/app_design.dart`）

奶油白 bg `#f7f6f2` / 卡片白 surface `#ffffff` / 御财金 accent `#b08d57` / accent-soft `#f3ebdd` / 收入绿 `#2d8a6e` / 支出红 `#c4544d` / 边框 `#e6e3dc` / 圆角 sm 10 lg 14 / 标题 serif `displayFamily`(Georgia,'Noto Serif SC') / 数字 mono + `tabularFigures`。

**i18n**：御财客户端无 i18n，UI 文案硬编码中文（正确，不要套用 syfinance Tauri 的 `t()`）。

## 6. 测试策略（TDD）

- **widget test 三尺寸断点**（参考现有 accounts_page_test.dart 的 `size` harness）：
  - mobile（390 宽）：渲染紧凑行卡片（断言紧凑行结构，如 `Row` 含 aicon+amain+av，无 csub 完整卡结构）
  - tablet（900 宽）：2 列网格（断言 GridView crossAxisCount=2，完整卡形态）
  - desktop（1200 宽）：auto-fill 网格（现状，断言 >= 3 列）
- **汇总头 mobile 简化**：mobile 断言净资产 + 资产/负债，不含 desktop 的 count 行（若简化）
- **类型副信息 + 进度条**：每类型卡片渲染正确副信息 + 信用卡/贷款进度条（mobile 紧凑行 + tablet 完整卡两形态都测）
- 命令：`cd yucai/client && flutter test test/account/presentation/pages/accounts_page_test.dart` + `flutter analyze`（0 error）

## 7. 原型参考

- **OD v2（权威）**：`yucai-account-mobile-tablet-a279` 项目的 `mobile.html` + `tablet.html`
- **本地副本**：`design-output/accounts-responsive/mobile.html` + `tablet.html`
- **御财 mobile 语言参考**：`yucai-category-management-db5f/mobile.html`（phone frame + topbar + 汇总卡 + chip + 列表 + 底部 tab + FAB）
- **desktop accounts**：`yucai-account-prototype-65e6/accounts.html`（完整卡形态 + 类型规则的数据源）
- **Flutter 现状**：`yucai/client/lib/account/presentation/pages/accounts_page.dart`

## 8. 范围边界

### 做（本 spec）
- `AccountsPage` 列表页 mobile 紧凑行卡片 + tablet 2 列 + 汇总头响应式 + 断点逻辑

### 不做（后续）
- 账户**详情页** tablet/mobile（现只 desktop `detail-account.html`）
- 账户**表单页** tablet/mobile
- AppShell 外壳改动（已就绪）
- 新的外部依赖
