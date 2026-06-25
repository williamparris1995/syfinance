# 御财账户详情页响应式 · 设计

- **日期**: 2026-06-25
- **状态**: 设计已确认,待转实施计划
- **范围**: 账户详情页(`account_detail_page.dart`)内容区三端响应式(desktop/tablet/mobile)
- **分支**: main(新分支 `account-detail-responsive`)
- **不含**: AppShell sidebar 抽屉响应式(单独 spec)

## 1. 概述

御财账户详情页当前是 desktop 固定布局,窄屏(tablet/mobile)不响应——`_body` 双栏固定不堆叠、`_statsRow` 固定 4 列、hero 余额固定 40px、topbar 按钮固定 icon+文字。

OD 原型 `detail-account.html` 用 `@media (max-width:900px)` 和 `@media (max-width:720px)` 双断点适配三端。本 spec 把 Flutter 对齐 OD,加用户调整(tablet topbar 仅 icon)。

## 2. 决策(已确认)

- **三端全覆盖**(desktop >900 / tablet ≤900 / mobile ≤720),对齐 OD
- **断点**:900px(tablet)/ 720px(mobile)
- **topbar 按钮 ≤900 仅 icon**(去文字)——用户调整;OD 原型是 ≤720 才隐文字,因 tablet 800px 下"编辑/记一笔/转账"文字挤占、显示不全,提前到 ≤900 收敛
- **其他区域全按 OD @media**(stat 2 列 / hero 余额 mobile 32px / cols 堆叠 / info 2 列)
- **不含 AppShell sidebar 抽屉**(≤720 sidebar 隐藏抽屉是 shell 层,本 spec 只做详情页内容区)

## 3. 区域响应式

### 3.1 `_body` 双栏(近期交易 + 收支饼图)
- 现状:`Row(Expanded flex:3 交易 + Expanded flex:2 饼图)` 固定双栏
- >900:双栏 flex 3:2(交易左 + 饼图右)
- ≤900:**堆叠单列**(Column,交易上 + 饼图下)

### 3.2 `_statsRow`(4 stat 卡)
- 现状:`Row(4 × Expanded)` 固定 4 列
- >900:4 列
- ≤900:**2 列**

### 3.3 `_heroFields`(hero 字段网格)
- 现状:`LayoutBuilder` GridView,crossAxisCount `> 600 ? 4 : 2`(断点 600)
- 改:断点 600 → **900**(对齐 OD)
- >900:4 列
- ≤900:2 列

### 3.4 `_infoCard`(账户信息字段)
- 现状:`LayoutBuilder` GridView 动态 cols
- 改:对齐 OD —— >900 3 列 / ≤900 2 列

### 3.5 hero 余额字号
- 现状:固定 40px
- >900:40px
- ≤720:**32px**(tablet ≤900 仍 40px,仅 mobile 缩)

### 3.6 topbar 按钮(用户调整)
- 现状:AppBar actions(icon + Text 文字)
- >900:icon + 文字
- ≤900:**仅 icon**(去 Text label)

### 3.7 content padding
- 现状:`fromLTRB(36, 24, 36, 70)`
- >900:36/24/36/70
- ≤720:**16/14/16/60**(tablet ≤900 仍 36/24/36/70)

## 4. 实现要点

- `_body` 顶部用 `LayoutBuilder` 算断点:
  ```dart
  final w = constraints.maxWidth;
  final isTablet = w <= 900;   // ≤900 tablet(含 mobile,因 mobile ≤720 < 900)
  final isMobile = w <= 720;   // ≤720 mobile
  ```
- 各区域按 isTablet/isMobile 分支:
  - `_body`:`isTablet ? Column(...) : Row(flex 3:2)`
  - `_statsRow`:GridView crossAxisCount `isTablet ? 2 : 4`
  - `_heroFields`:crossAxisCount `isTablet ? 2 : 4`(原 600 改 900)
  - `_infoCard`:crossAxisCount `isTablet ? 2 : 3`
  - hero 余额 fontSize:`isMobile ? 32 : 40`
  - topbar 按钮:`isTablet ? 仅 Icon : Icon + Text`(条件去 Text)
  - content padding:`isMobile ? 16/14/16/60 : 36/24/36/70`
- 注意:`_body` 用 `ListView`,内层 LayoutBuilder 在 ListView children 里(constraints 来自父)

## 5. 御财 token(遵循)

mono+tabular-nums 数字、serif 标题、奶油白 #f7f6f2 / 御财金 #b08d57 / 深色 #1c1e21 / 收入绿 #2d8a6e / 支出红 #c4544d / 边框 #e6e3dc / 圆角 sm 10 lg 14。

## 6. 测试(widget TDD)

- **desktop(1200px)**:双栏 + stat 4 列 + hero 4 列 + info 3 列 + topbar icon+文字 + hero 余额 40px + padding 36
- **tablet(800px)**:堆叠 + stat 2 列 + hero 2 列 + info 2 列 + topbar **仅 icon** + hero 余额 40px + padding 36
- **mobile(375px)**:堆叠 + stat 2 列 + hero 2 列 + info 2 列 + topbar 仅 icon + hero 余额 **32px** + padding 16

## 7. 范围边界

### 本期做
- `account_detail_page` 内容区三端响应式:`_body`/`_statsRow`/`_heroFields`/`_infoCard`/hero 余额字号/topbar 按钮/content padding

### 本期不做
- AppShell sidebar 抽屉(≤720,shell 层,单独 spec)
- 移动端触屏特化(stat 卡横滑 / 底部 FAB / hero 折叠 等,用户确认按 OD 不改)
- 交易页 / 账户列表页响应式(其他 spec)

## 8. 原型参考

OD `yucai-account-prototype-65e6` / `detail-account.html`(@media 900/720)。视觉伴侣三端截图见 `.superpowers/brainstorm/368577-1782386550/content/`(mobile.png / tablet.png / desktop.png)。
