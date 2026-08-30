# 御财设计系统 v2 —— A+B 亮暗双主题

> 状态:已确认(2026-08-30,用户从 A/B/C 三方向打样中选定 A+B 合并双主题)。
> 原型源:`design-output-v2/ab/`(12 页,自包含 HTML,dark/light 双令牌)。
> 本文是 client 侧 UI 落地的单一设计事实源;Flutter 实装见 [release-r8-design-v2](release-r8-design-v2/release.md)。

## 1. 方案溯源

2026-08-30 三方向打样对比(同仪表盘页 ×3 套设计系统):A「墨鎏金」暗色私行风 / B「晨白」亮色极简风 / C「琥珀」暖彩消费者风。用户裁定:**A+B 合并为同一设计系统的暗/亮双主题**,C 保留为单主题备选(原型存 `design-output-v2/direction-{a,b,c}/`)。

## 2. 色彩令牌

| 语义 | 暗色(墨鎏金) | 亮色(晨白) |
|---|---|---|
| bg 主背景 | `#0B0E13` | `#F8FAFC` |
| surface 卡片 | `#141922` | `#FFFFFF` |
| surface-2 次级容器 | `#1A2130` | `#F1F5F9` |
| border 描边 | `#232B38` | `#EEF2F7`(卡片多无边框+阴影) |
| fg 正文 | `#F2F4F8` | `#0F172A` |
| muted 次级文字 | `#8B93A3` | `#64748B` |
| accent 主色 | 鎏金 `#E8C07A`(渐变→`#C9964A`) | 翡翠绿 `#059669`(深 `#047857`) |
| accent 上文字 | `#1A1408` | `#FFFFFF` |
| positive 收入 | `#34D399` | `#059669` |
| negative 支出/负债 | `#F87171` | `#E11D48` |
| cyan 图表强调/转账 | `#22D3EE` | `#0EA5E9` |
| warn 预算警示 | `#FBBF24` | `#D97706` |
| 侧栏 | `#0E1219`(一体暗色) | `#FFFFFF`(白+右侧描边) |
| 阴影 | 无(靠描边分层) | `0 1px 2px rgba(15,23,42,.05), 0 4px 16px rgba(15,23,42,.05)` |

图表序列色 seg1-6:暗 `#E8C07A/#22D3EE/#34D399/#8B93A3/#F472B6/#A78BFA`;亮 `#059669/#0EA5E9/#D97706/#94A3B8/#DB2777/#7C3AED`。

## 3. 排版 / 形状

- **全无衬线**(放弃 v1 serif 标题:Windows 中文 serif 渲染发虚):`Segoe UI / Microsoft YaHei / PingFang SC / system-ui`;数字一律 `tabular-nums`。
- 层级:h1 24/700(问候页头)· h2 卡片标题 15/700 · 正文 14 · 辅助 12.5-13 · 微字 11-12。
- hero 大数字 46/800(次级 hero 变体 38/800);迷你卡大数 22/800。
- 圆角:卡片 16 · hero 24(移动 20)· 控件 10-12 · pill 999。间距体系:6/12/16/18/24/32(页面 padding 28 32,移动 18 16)。

## 4. 核心组件

卡片 card(带 head: h2 + 链接)、hero 净资产大卡(暗=渐变描边+渐变金字,亮=白卡阴影+黑字)、汇总条 sum-strip(3 卡)、迷你卡+进度条 bar(默认/pos/warn/neg)、快捷操作 quick(4 宫格彩底图标)、交易行 txn、数据网格行 grid-row(桌面表格化/移动卡片化)、筛选 pills、月度切换 pills、分段控件 seg、分类九宫格、进度环 ring、环形图 donut(seg1-6)、迷你走势 spark(渐变填充)、到期行 due-row、提示卡 callout(pos/warn)、按钮 btn-primary(暗=金渐变/亮=翡翠实底)+btn-ghost、图标钮 icon-btn、开关 switch、tab 页签。

## 5. 布局与信息架构

- **侧栏 4 组导航**(替代 v1 6 组):概览(仪表盘+报表分析升一级)/ 资产(账户·投资·债务·债权)/ 收支(交易·预算·目标)/ 工具(标签·模板·设置);底部用户区。
- 顶栏:面包屑 + 搜索 + 主题切换(☀/☾)+ 通知;移动端隐藏面包屑。
- **移动端**:5-tab 底部导航(仪表盘/交易/中央 FAB 记一笔/账户/我的),断点 900px。
- 仪表盘 = hub:净资产 hero → 收支/预算/目标 3 迷你卡 → 快捷操作 → 近期交易 + 资产配置/即将到期。

## 6. 原型清单(design-output-v2/ab/,12 页)

仪表盘 dashboard · 账户 accounts · 账户详情 account-detail · 交易 transactions · 记一笔 transaction-form · 持仓业绩 performance · 预算 budgets · 报表 report · 债务 debts · 债权 receivables · 目标 goals · 设置 settings(主题模式为可交互演示)。共享 `assets/theme.css`(双令牌)+ `assets/app.js`(切换,localStorage `yc2-theme`)。数据跨页自洽(总资产 ¥1,384,650 / 负债 ¥100,000 / 净资产 ¥1,284,650 等)。
