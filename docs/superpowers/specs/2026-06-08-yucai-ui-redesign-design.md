# 御财 (YuCai) UI 功能重构设计

**日期**: 2026-06-08
**状态**: 已确认
**范围**: 桌面端 20 页面重构（移动端后续适配）

## 目标

以 `screens/` 目录中的 36 个 HTML 原型页面为蓝图，对现有 React 前端进行功能重构。核心变化：

1. 覆盖 Tailwind 主题令牌，全局切换为御财视觉语言
2. 侧边栏/顶栏布局重构
3. Sheet/Dialog 交互改为独立路由页面（详情页、表单页）
4. Table 布局改为卡片网格
5. 建立可复用的页面模式组件系统

## 参考原型文件

桌面端 20 页：

| 类型 | 页面 |
|------|------|
| 列表页 | dashboard, accounts, investments, transactions, budget, goals, debts, reports, settings |
| 详情页 | detail-account, detail-transaction, detail-goal, detail-debt, detail-holding |
| 表单页 | form-account, form-transaction, form-goal, form-budget, form-debt, form-trade |

---

## 1. 主题与设计令牌

### 1.1 配色

| 原型变量 | 原型值 | Tailwind/shadcn 映射 |
|----------|--------|---------------------|
| `--bg` | `#f7f6f2` 奶油白 | `--background` |
| `--surface` | `#ffffff` | `--card`, `--popover` |
| `--fg` | `#1a1916` 深色正文 | `--foreground` |
| `--muted` | `#7a7770` 灰色辅助 | `--muted-foreground` |
| `--border` | `#e6e3dc` 暖灰边框 | `--border` |
| `--accent` | `#b08d57` 御财金 | `--primary` |
| `--positive` | `#2d8a6e` 收入绿 | `--income`（保留） |
| `--negative` | `#c4544d` 支出红 | `--expense`（保留） |
| 侧边栏 | `#1c1e21` 深色 | 新增 sidebar 语义色 |

### 1.2 字体

| 用途 | 字体栈 | Tailwind 映射 |
|------|--------|---------------|
| 标题 | Iowan Old Style, Charter, Georgia, Noto Serif SC, serif | `font-display`（新建） |
| 正文 | 系统无衬线体（PingFang SC, Microsoft YaHei, Segoe UI） | `font-sans`（保持） |
| 数字 | JetBrains Mono, tabular-nums | `font-mono`（保持） |

### 1.3 圆角与间距

- 圆角：`--radius: 10px`，`--radius-lg: 14px`
- 间距体系：xs:6px, sm:12px, md:20px, lg:28px, xl:40px

### 1.4 实施方式

修改 `src/index.css` 中的 CSS 变量值 + `tailwind.config.js` 新增 `font-display`、sidebar 颜色组。不改变 shadcn 组件结构，只覆盖视觉令牌。

---

## 2. 布局框架

### 2.1 侧边栏

| 属性 | 值 |
|------|-----|
| 展开宽度 | 240px |
| 折叠宽度 | 64px（仅显示图标） |
| 背景色 | `#1c1e21`（折叠/展开不变） |
| 品牌区 | 展开显示「御财」+ 副标题；折叠时仅金色 logo 图标 |
| 导航分组 | 5 组：概览、投资、财务、借贷、工具 |
| 导航项 | 展开显示图标+文字+badge；折叠时仅图标 + tooltip |
| 用户区 | 展开显示头像+用户名；折叠时仅头像 |
| 折叠触发 | 侧边栏底部折叠按钮（`«` / `»` 箭头） |
| 移动端 | 抽屉覆盖模式（保持现有行为） |

### 2.2 顶栏

- `position: sticky` + `backdrop-filter: blur(12px)` 毛玻璃效果
- 左侧：面包屑导航（可点击返回上级页面）
- 右侧：搜索框 + 通知铃铛 + 设置图标
- 用户头像从 Header 移到侧边栏底部

### 2.3 内容区

- 桌面端 `margin-left` 跟随侧边栏展开/折叠宽度
- 内容 padding：`28px 32px 48px`
- 列表页不限制最大宽度
- 表单页 `max-width: 760px` 居中

---

## 3. 页面模式系统

### 3.1 列表页（List Page）

适用于：仪表盘、账户、投资、交易、预算、目标、债务、报表、设置（共 9 页）

结构：
```
顶栏（面包屑 + 操作按钮）
├── 页面标题行（h1 标题 + 总金额 | 筛选 | + 新建按钮）
├── 筛选标签栏（pill 按钮组 + 搜索框）
└── 内容区
    ├── 卡片网格（账户/目标/债务）
    ├── 表格（交易记录）
    └── 图表区域（仪表盘/报表）
```

与现有代码的关键差异：
- 账户页：Table → 卡片网格（`grid-template-columns: repeat(auto-fill, minmax(280px, 1fr))`）
- 所有列表页增加统一的筛选标签栏

### 3.2 详情页（Detail Page）

适用于：账户详情、交易详情、目标详情、债务详情、持仓详情（共 5 页）

**现有**: Sheet 侧滑面板
**目标**: 独立路由页面

结构：
```
顶栏（面包屑：列表页名 / 详情名）
├── Hero 卡片（图标+名称 | 大字余额 | 关键指标+进度条，带径向渐变背景）
├── 快速统计行（4 个 StatCard）
└── 两栏布局
    ├── 左：交易记录/子列表
    └── 右：信息侧边栏
```

新增路由：`/accounts/:id`, `/transactions/:id`, `/goals/:id`, `/debts/:id`, `/holdings/:id`

点击列表页卡片 → `navigate('/accounts/:id')`（替代 `setSheetOpen(true)`）

### 3.3 表单页（Form Page）

适用于：新建/编辑 账户、交易、目标、预算、债务、交易（共 6 页）

**现有**: Dialog/Sheet 弹出表单
**目标**: 独立路由页面

结构：
```
顶栏（面包屑：父页面 / 新建XX）
├── 标题 + 副标题
└── 表单卡片（max-width: 760px 居中）
    ├── 类型选择标签页（TypeTabs）
    ├── 表单分区 × N
    │   ├── 分区标题（大写小字 + 底部边框）
    │   └── 字段行（FormRow，支持 1/2/3 列网格）
    └── 操作栏（[取消]  [确认创建]）
```

新增路由：`/accounts/new`, `/accounts/:id/edit`, `/transactions/new`, `/goals/new` 等约 12 条

金额输入框：左侧币种标签 + 右侧数字输入（`AmountInput` 组件）

---

## 4. 共享组件架构

所有可复用组件放在 `src/components/patterns/` 下，遵循以下原则：

- 每个组件只做一件事，通过 props 控制内容
- 组件内部不包含业务逻辑（不调用 API），只负责布局和样式
- 语义化 props，如 `<HeroCard name="招商银行" balance={-12800} icon={...} />`

### 4.1 布局组件（`patterns/layout/`）

| 组件 | 职责 |
|------|------|
| `PageShell` | 所有页面外层容器（padding + max-width 控制） |
| `PageHeader` | 标题行（h1 + 右侧操作区 slot） |
| `BreadcrumbBar` | 面包屑导航（集成到顶栏） |
| `FilterBar` | 筛选标签栏（pill 按钮组 + 搜索框） |

### 4.2 卡片组件（`patterns/cards/`）

| 组件 | 职责 |
|------|------|
| `HeroCard` | 详情页顶部 Hero 卡片（图标+余额+指标+径向渐变装饰） |
| `StatCard` | 快速统计小卡片（标签+数值+趋势标签） |
| `DataCard` | 通用数据卡片（列表页卡片网格的每个单元） |
| `CreditBar` | 额度/进度条组件 |

### 4.3 表单组件（`patterns/forms/`）

| 组件 | 职责 |
|------|------|
| `FormCard` | 表单外层卡片容器 |
| `FormSection` | 表单分区（标题 + 字段行容器） |
| `FormRow` | 字段行（支持 1/2/3 列网格） |
| `TypeTabs` | 类型选择标签页（如账户类型：储蓄/信用卡/投资/...） |
| `AmountInput` | 带币种前缀的金额输入框 |

### 4.4 详情组件（`patterns/detail/`）

| 组件 | 职责 |
|------|------|
| `DetailTwoCol` | 详情页两栏布局（左内容 + 右侧边栏） |
| `DetailTransactions` | 详情页内嵌交易列表 |
| `DetailSideInfo` | 详情页右侧信息栏 |

---

## 5. 分阶段交付

### P0 — 基础设施

| 任务 | 产物 | 涉及文件 |
|------|------|----------|
| 主题令牌覆盖 | 全局视觉切换 | `src/index.css`, `tailwind.config.js` |
| 侧边栏重构 | 深色分组导航+折叠 | `src/components/sidebar/Sidebar.tsx` |
| 顶栏重构 | 面包屑+毛玻璃 | `src/components/layout/Header.tsx` |
| AppLayout 适配 | 240/64px 侧边栏 | `src/components/layout/AppLayout.tsx` |
| 共享组件骨架 | patterns/ 全部组件初始版本 | `src/components/patterns/` |
| 路由扩展 | 详情页/表单页路由占位 | 路由配置文件 |

验证标准：启动应用后全局视觉风格切换为御财主题，所有现有页面功能不 broken。

### P1 — 账户模块

| 任务 | 产物 |
|------|------|
| 账户列表页改造 | Table → DataCard 网格 + FilterBar |
| 账户详情页 | Sheet → `/accounts/:id`，HeroCard + DetailTwoCol |
| 账户表单页 | Sheet → `/accounts/new`, `/accounts/:id/edit`，TypeTabs + FormSection |

验证标准：列表浏览 → 点击卡片进详情 → 返回 → 新建/编辑账户完整闭环。

### P2 — 交易模块

| 任务 | 产物 |
|------|------|
| 交易列表页改造 | 增强筛选 + 日期范围 + 优化表格样式 |
| 交易详情页 | `/transactions/:id`，HeroCard + DetailTwoCol |
| 交易表单页 | `/transactions/new`，复用 TypeTabs + FormSection |

验证标准：交易列表 → 详情 → 新建交易完整流程。

### P3 — 投资 + 债务模块

| 任务 | 产物 |
|------|------|
| 投资组合页 | 持仓卡片网格 + 总市值展示 |
| 持仓详情页 | `/holdings/:id`，涨跌色 + 走势图 |
| 交易表单页 | `/holdings/trade`（买卖交易） |
| 债务列表页 | 债务卡片网格（待还/已还分组） |
| 债务详情页 | `/debts/:id`，还款进度 + 还款记录 |

验证标准：投资和债务两个模块各自闭环。

### P4 — 规划模块

| 任务 | 产物 |
|------|------|
| 预算管理页 | 预算分类卡片 + 进度环/条 |
| 预算表单页 | `/budget/new` |
| 目标追踪页 | 目标卡片 + 里程碑时间线 |
| 目标详情页 | `/goals/:id`，进度 + 关联账户 |
| 目标表单页 | `/goals/new` |

验证标准：预算和目标模块各自闭环。

### P5 — 仪表盘 + 报表 + 设置

| 任务 | 产物 |
|------|------|
| 仪表盘重设计 | 总资产概览 + 快捷入口 + 近期交易 + 待办提醒 |
| 报表分析页 | 图表区域重设计（收支趋势、分类占比、资产分布） |
| 设置页 | 设置项卡片布局 |

验证标准：所有桌面端 20 个页面完成重构。

---

## 6. 约束与边界

- **不动 Rust 后端**：本次重构仅涉及前端 UI 层，API 接口不变
- **不动数据模型**：DTO 类型、Tauri IPC 调用保持不变
- **渐进式**：每个阶段独立可交付，可随时暂停
- **i18n 合规**：所有新增 UI 文本使用 `t()` 函数，添加到 `en.json` 和 `zh.json`
- **ESLint 合规**：遵守 `i18next/no-literal-string` 规则
- **移动端后续**：本设计仅覆盖桌面端，移动端适配在桌面端全部完成后单独规划
