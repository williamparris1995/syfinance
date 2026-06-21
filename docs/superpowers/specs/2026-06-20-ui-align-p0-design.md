# 御财 UI 对齐原型 · 轮 1 P0 设计

- **日期**: 2026-06-20
- **状态**: 设计已确认，待转实施计划
- **范围**: 轮 1 P0（3 项核心视觉对齐）
- **组织**: 方案 A 分轮（P0 → P1 → P2），本 spec 仅 P0
- **分支**: transaction-module-redesign（延续交易模块重构）

## 1. 概述

御财 app 当前实现与 OD 原型存在视觉/信息差异。按方案 A 分 3 轮对齐：轮 1 P0（核心视觉，本 spec）→ 轮 2 P1（移动端体验）→ 轮 3 P2（交互补全）。最终 11 项全部完成，分批交付。

轮 1 P0 聚焦"一眼看出不一致"的 3 项核心视觉差异，对齐后 app 立刻接近原型观感。

## 2. P0-1：账户列表 card 按类型分支

### 现状
`accounts_page.dart` `_AccountCard` 统一布局：名称/`机构·币种`/余额/弱 `_subline`（仅信用卡/其他两分支）/进度条按组内占比（语义混乱——信用卡额度使用、贷款还款进度、投资涨跌全退化成"本卡占本组合计"）。

### 对齐原型（accounts.html cardHTML）
按 `accountType`/`category` 分支渲染主数字 + 副信息 + 进度条：

| 类型 | 主数字 | 副信息 | 进度条 |
|------|--------|--------|--------|
| 储蓄/现金（savings） | 可用余额 | 利率 X%（interestRate 有值时） | 无 |
| 信用卡（credit） | 当前欠款（负色红 AppColors.negative） | 额度 ¥X · 账单N日 / 还款M日 | **已用额度** = currentBalanceCents / creditLimitCents（红 bar） |
| 投资（investment） | 当前市值（investMarketValueCents） | +X% 今年收益（investReturnYtd，正绿/负红） | 无 |
| 定期（fixed） | 存单本金（fixedPrincipalCents） | 到期 YYYY-MM-DD · 利率 X% | 无 |
| 黄金（gold） | 当前现值（goldCurrentPriceCents × goldQuantity） | 买入 ¥X · +X% 涨幅 | 无 |
| 房产（estate） | 现估值（estateCurrentValueCents） | 买入 ¥X · +X% 增值 | 无 |
| 贷款（loan） | 剩余本金（loanRemainingCents，负色红） | 原始 ¥X · 月供 ¥X · 下次还款 | **已还比例** = (loanOriginalCents - loanRemainingCents) / loanOriginalCents（绿 bar） |

### 实现要点
- `_AccountCard` 内 `switch(category)` 渲染 `_subline`（类型专属副信息）+ 可选 progress bar（仅信用卡/贷款）
- 去掉当前"组内占比"进度条逻辑（barFraction）
- 进度条颜色：信用卡红（AppColors.negative）、贷款绿（AppColors.positive）
- 涨跌幅/收益率：正绿负红
- 金额格式：mono + tabular-nums，负数带 -/红色

### 字段确认（用户已确认）
- 信用卡 bar = 已用额度 / 信用额度（已用 = currentBalanceCents 欠款）
- 贷款 bar = 已还比例 = (原始 - 剩余) / 原始

## 3. P0-2：账户详情 Hero 升级

### 现状
`account_detail_page.dart` hero = 白卡 DataCard + 类型图标 + 名称 + `机构·币种·类型` + 余额 + `Wrap(Chip)` 所有字段扁平堆叠（字段多时很长无层次）。

### 对齐原型（detail-account.html hero）
- **深色金色渐变大卡**：`linear-gradient #1c1e21→#2a2d33` + 金色径向光晕（radial-glow，accent #b08d57 alpha 0.18），白字 40px 余额（serif display font）
- **hero-badge**：类型 chip（储蓄/信用卡/投资...）+ 资产·负债类 + 活期/定期
- **hero-bal-sub**：本月收支副信息 = TransactionSummary net（**已有数据**，account-scoped），显示「本月收支 +¥X」（正绿/负红）—— 近似月度变动，不需余额历史
- **hero-fields 结构化字段网格**（替代扁平 Chip Wrap）：按类型 4 列网格（desktop）/ 2 列（tablet/mobile）显示专属字段：
  - 储蓄：利率 / 开户日期 / 币种 /（可用余额）
  - 信用卡：额度 / 账单日 / 还款日 / 年费
  - 贷款：原始本金 / 剩余本金 / 月供 / 下次还款
  - 投资：市值 / 成本 / 今年收益率 /（持仓数）
  - 黄金：品种 / 数量 / 买入价 / 现价
  - 房产：买入价 / 现估值 / 买入日期 / 折旧率
  - 定期：本金 / 起息日 / 到期日 / 期限

### 实现要点
- hero 卡片用 `Container(decoration: BoxDecoration(gradient: LinearGradient(...)))` + Stack（径向光晕 Positioned）
- hero-badge 用 pill chip（accent-soft 背景）
- hero-fields 用 `GridView.count`（desktop 4 列 / mobile 2 列，LayoutBuilder 断点）
- 复用 account_detail 现有 TransactionBloc（account-scoped summary，Task 6.1 路由 provide）拿 net
- 删除现有 `_specificChips`（Wrap Chip），改为 `_heroFields`（结构化网格）

## 4. P0-3：交易转账行双账户箭头

### 现状
`transactions_page.dart` TxnRow 账户列只显示 primary 账户名（`_secondaryLine`）；转账（type=transfer）也只显示一个账户。

### 对齐原型（transactions.html）
- **desktop 表格账户列**：
  - 转账（type==transfer）：「转出首字母方块 + 转出账户名 → 转入首字母方块 + 转入账户名」
  - 非转账（收入/支出）：单个资产账户名（首字母方块 + 名）+ 分类 chip（餐饮，颜色按 accountType）
- **mobile 卡片副行**：
  - 转账：「转出名 → 转入名 · HH:MM」
  - 非转账：「分类 · 账户 · HH:MM」

### 实现要点
- TxnRow（desktop `_TxCard` + mobile `_MobileTxnCard`）转账分支：从 entries 解析两个 asset account（from = creditCents>0 的 entry / to = debitCents>0 的 entry，或按 SimpleTransfer 语义），account.name 从 accounts 缓存解析
- 账户首字母方块：account.name 首字符 + account 类型色
- accounts 缓存复用（transactions_page 已为 FilterBar 加载 accounts）
- 箭头：Icons.arrow_forward（小，muted 色）

## 5. 御财 token（严格遵循）

奶油白 #f7f6f2 / 卡片白 #ffffff / 御财金 #b08d57 / 深色侧栏 #1c1e21 / 收入绿 #2d8a6e / 支出红 #c4544d / 边框 #e6e3dc / 圆角 sm 10px lg 14px / 标题 serif(Georgia,'Noto Serif SC') / 数字 mono+tabular-nums。

## 6. 测试策略（TDD）

- 账户 card：widget 测试，每类型（储蓄/信用卡/投资/定期/黄金/房产/贷款）渲染正确字段 + 进度条（信用卡红/贷款绿）
- 详情 Hero：widget 测试，渐变 hero + badge + 本月收支 + 字段网格（每类型字段）；mock TransactionBloc summary net
- 转账双账户：widget 测试，transfer 行显示双账户箭头；非转账单账户 + chip
- 硬编码中文（yucai 无 i18n）

## 7. 范围边界

### 本轮 P0 做（3 项）
账户 card 类型分支 + 详情 Hero + 交易转账双账户。

### 本轮不做（P1/P2 后续轮）
- P1 移动端：移动交易卡分类 chip/时间、移动筛选底部 sheet、移动月份切换/可展开汇总、详情响应式断点
- P2 交互：卡片内联快速操作、搜索、收支饼图、移动左滑删除

## 8. 原型参考（优先级：OD v2 > screens v1）

**规则：如有新版本（OD），参考新版本实施。**

### OD（v2，最新，优先参考）
- 账户：`yucai-account-prototype-65e6`（accounts.html / detail-account.html / form-account.html）
- 交易：`yucai-transaction-trisize-9d3e`（desktop transactions/form/detail + mobile/ + tablet 旧 `yucai-transaction-tablet-prototype-abb9`）
- 分类管理：`yucai-category-management-db5f`（desktop/tablet/mobile）

### screens/（v1，旧版，备份）
- `screens/desktop-*.html` + `mobile-*.html`（早期第一版原型）
- **仅在 OD 无对应页面时**参考 screens
- OD 有对应页面时，**以 OD 为准**（screens 可能与 OD 不一致，如账户 card 副标题：screens=机构·卡号，OD=机构·币种）
2、