# 侧边栏重新设计 — 功能领域分组方案

**日期:** 2026-06-04
**状态:** 已批准
**作者:** Claude Code (brainstorming skill)

---

## 1. 背景与目标

### 1.1 当前问题

当前侧边栏（`src/components/Sidebar.tsx`）采用**扁平列表**设计，仅有 6 个导航项：

- 仪表板、账户、交易记录、债务、报表、设置

随着功能增加，以下问题日益突出：

1. **功能发现困难**：投资、预算、目标、提醒、循环记账等功能在导航中不突出或缺失
2. **逻辑关系模糊**：账户、债务、投资都属于"资产/负债管理"，但在导航中平级排列，缺乏语义分组
3. **可扩展性差**：新增功能（如定投、储值卡管理）无处安放，会导致导航项无限膨胀

### 1.2 设计目标

1. **按功能领域分组**：将 11 个核心导航项组织为 6 个语义清晰的分组
2. **支持折叠/展开**：用户可收起不常用分组，保持侧边栏简洁
3. **保持可扩展性**：为未来功能（如导入、日历视图）预留清晰的归属位置
4. **不引入独立页面模块**：经代码审查确认，标签管理、储值卡、导出等功能已在现有模块内管理，无需新增侧边栏项

---

## 2. 设计方案

### 2.1 分组结构

采用**功能领域分组（方案 A）**，共 6 个分组、11 个导航项：

```
📊 Finance App
│
├─ 🏠 仪表板                    → /
│
├─ 💼 资产管理
│  ├─ 💰 账户                  → /accounts
│  ├─ 📈 投资组合               → /holdings
│  └─ 💳 债务                  → /debts
│
├─ 🔄 交易操作
│  ├─ 📝 交易记录               → /transactions
│  └─ 🔄 循环记账               → /transaction-templates
│
├─ 🎯 规划
│  ├─ 🎯 财务目标               → /goals
│  ├─ 📋 预算                  → /budget
│  └─ 🔔 提醒                  → /reminders
│
├─ 📊 分析
│  └─ 📉 报表                  → /reports
│
└─ ⚙️ 系统
   ├─ ⚙️ 设置                  → /settings
   └─ 💾 备份                  → /backup
```

### 2.2 被排除的侧边栏项

经代码审查确认，以下功能**不应作为独立侧边栏导航项**：

| 功能 | 当前归属 | 原因 |
|------|----------|------|
| 储值卡 | 账户模块 | Prepaid 是 `AccountType` 的一种，在 AccountsPage 中管理，详情通过 `PrepaidDetailPanel` 展示 |
| 标签管理 | 设置页面 | `TagsSection` 组件嵌入在 `SettingsPage` 中，属于设置范畴 |
| 数据导出 | 设置页面 | `exportCsv` 功能在 `SettingsPage` 中作为「数据导出」卡片 |
| 货币设置 | 设置页面 | 已有独立设置区域 |
| 账户设备链接 | 设置页面 | 已有独立设置区域 |

### 2.3 定投计划的归属

**定投计划（Investment Plan / Dollar-Cost Averaging）** 采用**上下文嵌入**设计：

- **不出现在侧边栏**，作为「投资组合」页面内的 Tab 存在
- 与「持仓列表」「交易记录」并列，作为第三个 Tab：「定投计划」
- 设计理由：
  - 行业最佳实践（Betterment、天天基金、招商银行均将定投作为投资模块的子功能）
  - 保持导航简洁（避免侧边栏膨胀）
  - 上下文自然（投资相关操作在投资模块内完成）
  - 与「循环记账」形成对称（均为自动化交易机制）

---

## 3. 交互设计

### 3.1 折叠/展开行为

| 场景 | 行为 |
|------|------|
| **默认状态** | 所有分组展开 |
| **当前选中项** | 所在分组自动展开（不可折叠） |
| **用户操作** | 点击分组标题栏切换展开/折叠 |
| **状态记忆** | 使用 `localStorage` 保存用户的折叠偏好，刷新后恢复 |
| **动画** | 展开/折叠使用 150ms 的 `height` 过渡动画 |

### 3.2 视觉样式

- **分组标题**：11px，灰色（`text-muted-foreground`），大写或全中文，与导航项有明显区分
- **分组间距**：分组之间增加 `mt-4` 间距，组内项保持紧凑
- **Hover 效果**：分组标题 hover 时显示 subtle 背景色变化（`hover:bg-sidebar-accent/50`）
- **当前项高亮**：保持现有样式（`bg-sidebar-accent text-sidebar-accent-foreground`）
- **图标**：保留现有 Lucide 图标，不引入新图标依赖

### 3.3 移动端适配

- `MobileSidebar` 使用 `Sheet` 组件，行为不变
- 侧边栏内容直接使用重构后的 `Sidebar` 组件
- 折叠状态在移动端同样生效

---

## 4. 数据模型

### 4.1 导航配置

```typescript
// src/components/Sidebar.tsx
interface NavGroup {
  label: string;           // 分组标题（如 "资产管理"）
  items: NavItem[];
  defaultOpen?: boolean;   // 默认是否展开
}

interface NavItem {
  to: string;              // 路由路径
  label: string;           // 显示文本（使用 t() i18n）
  icon: React.ComponentType;
  exact?: boolean;
}
```

### 4.2 分组定义

```typescript
const navGroups: NavGroup[] = [
  {
    label: 'nav.overview',      // "概览"
    items: [{ to: '/', label: 'nav.dashboard', icon: Home, exact: true }],
  },
  {
    label: 'nav.assetManagement', // "资产管理"
    items: [
      { to: '/accounts', label: 'nav.accounts', icon: Wallet },
      { to: '/holdings', label: 'nav.holdings', icon: BarChart3 },
      { to: '/debts', label: 'nav.debts', icon: CreditCard },
    ],
  },
  {
    label: 'nav.transactions',   // "交易操作"
    items: [
      { to: '/transactions', label: 'nav.transactions', icon: Receipt },
      { to: '/transaction-templates', label: 'nav.recurring', icon: Repeat },
    ],
  },
  {
    label: 'nav.planning',       // "规划"
    items: [
      { to: '/goals', label: 'nav.goals', icon: Target },
      { to: '/budget', label: 'nav.budget', icon: ClipboardList },
      { to: '/reminders', label: 'nav.reminders', icon: Bell },
    ],
  },
  {
    label: 'nav.analysis',       // "分析"
    items: [{ to: '/reports', label: 'nav.reports', icon: PieChart }],
  },
  {
    label: 'nav.system',         // "系统"
    items: [
      { to: '/settings', label: 'nav.settings', icon: Settings },
      { to: '/backup', label: 'nav.backup', icon: Database },
    ],
  },
];
```

### 4.3 i18n 键新增

需在 `zh.json` 和 `en.json` 中新增以下 `nav` 键：

```json
{
  "nav": {
    "overview": "概览",
    "assetManagement": "资产管理",
    "transactionsGroup": "交易操作",
    "planning": "规划",
    "analysis": "分析",
    "system": "系统",
    "recurring": "循环记账",
    "backup": "备份"
  }
}
```

> **注意：** 当前 `zh.json` 中已有 `nav.recurring` 和 `nav.holdings` 等键，需检查是否完整。

---

## 5. 技术实现要点

### 5.1 组件拆分

```
Sidebar
├── SidebarGroup          # 可折叠分组容器
│   ├── SidebarGroupHeader  # 分组标题（含折叠按钮）
│   └── SidebarGroupContent # 分组内容（导航项列表）
└── SidebarNavItem        # 单个导航项（保持现有样式）
```

### 5.2 折叠状态管理

```typescript
// 使用 localStorage 保存状态
const STORAGE_KEY = 'sidebar-group-state';

// 状态结构：使用固定 ID（而非 i18n 键）避免语言切换导致状态丢失
interface GroupState {
  [groupId: string]: boolean;  // true = 展开, false = 折叠
}

// 默认：所有分组展开
const defaultState: GroupState = {
  'overview': true,
  'assetManagement': true,
  'transactions': true,
  'planning': true,
  'analysis': true,
  'system': true,
};
```

### 5.3 当前路由检测

使用 `@tanstack/react-router` 的 `useRouterState` 或 `Link` 组件的 `activeProps` 来检测当前活动路由，确保：

1. 当前项所在分组**始终展开**
2. 即使 localStorage 中该分组为折叠状态，也要强制展开

### 5.4 依赖

- **无新增依赖**：仅使用现有技术栈（React, Tailwind CSS, shadcn/ui, i18next, Lucide React）
- **图标替换**：可能需要新增以下 Lucide 图标：
  - `Repeat`（循环记账，替代现有图标或保持）
  - `Target`（财务目标，替代现有图标或保持）
  - `ClipboardList`（预算，替代现有图标或保持）
  - `PieChart`（报表，替代现有图标或保持）
  - `Database`（备份，替代现有图标或保持）
  - `Bell`（提醒，替代现有图标或保持）

  > 实际上，当前代码中这些页面已经存在，应该已有对应图标。需检查现有图标是否足够表达。

---

## 6. 边界情况与错误处理

| 场景 | 处理方案 |
|------|----------|
| localStorage 被清除 | 回退到默认展开状态 |
| localStorage 数据损坏 | 使用 `try/catch` 包裹读取逻辑，损坏时重置为默认值 |
| 新增分组/导航项 | 未在 localStorage 中的分组默认展开 |
| 路由不存在（404） | 所有分组保持用户设置的折叠状态，无分组被强制展开 |
| 移动端窄屏 | 折叠状态同样生效，Sheet 内显示与桌面端一致 |

---

## 7. 测试要点

### 7.1 功能测试

- [ ] 所有 11 个导航项点击后正确跳转
- [ ] 当前活动项正确高亮
- [ ] 分组折叠/展开动画正常
- [ ] 折叠状态刷新后保持
- [ ] 当前项所在分组不可折叠（或折叠后自动展开）
- [ ] 移动端 Sheet 中显示正常

### 7.2 无障碍测试

- [ ] 分组标题可键盘聚焦（`tabindex`）
- [ ] 按 Enter/Space 键可切换折叠状态
- [ ] 使用 `aria-expanded` 标注折叠状态
- [ ] 使用 `aria-label` 标注分组标题

---

## 8. 未来扩展

以下功能已有清晰的归属位置，无需重新设计侧边栏：

| 未来功能 | 归属分组 | 实现方式 |
|----------|----------|----------|
| 日历视图 | 交易操作 | 作为「交易记录」页面内的 Tab |
| 导入数据 | 系统 | 作为「设置」页面内的卡片/Tab |
| 分类管理 | 系统 | 作为「设置」页面内的卡片/Tab |
| 多账本切换 | 概览 | 在「仪表板」或 AppHeader 中增加切换器 |
| 定投计划 | 资产管理 | 作为「投资组合」页面内的 Tab（已规划） |

---

## 9. 附录：图标映射

| 导航项 | 当前图标 | 建议图标 | 备注 |
|--------|----------|----------|------|
| 仪表板 | `Home` | `Home` | 保持 |
| 账户 | `Wallet` | `Wallet` | 保持 |
| 投资组合 | `BarChart3` | `TrendingUp` | 可改为更直观的图标 |
| 债务 | `CreditCard` | `CreditCard` | 保持 |
| 交易记录 | `Receipt` | `Receipt` | 保持 |
| 循环记账 | — | `Repeat` | 需确认当前图标 |
| 财务目标 | — | `Target` | 需确认当前图标 |
| 预算 | — | `ClipboardList` | 需确认当前图标 |
| 提醒 | — | `Bell` | 需确认当前图标 |
| 报表 | `BarChart3` | `PieChart` | 与投资组**分**区分 |
| 设置 | `Settings` | `Settings` | 保持 |
| 备份 | — | `Database` | 需确认当前图标 |

> 最终图标选择以实际代码审查为准，原则是每个分组内的图标风格一致、语义清晰。
