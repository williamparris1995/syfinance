# Spec — F25 托盘数据头 + 快捷操作

> 2026-09-15 sprint-7 grill 补充决策(数据头=今日+本月结余两行;隐私默认显示)。前置 F22 注入化地基(已合 main)。

## Requirements

- **FR-1 托盘数据头**:托盘菜单顶部两个动态**禁用项**:「今日 收 ¥x · 支 ¥y」「本月结余 +¥z」——口径复用 transaction 本地 DS `summary(year, month, {scope})` **单一查询点**(day+month 两次调用),金额格式与 app 内一致(¥ + 千分位);「托盘显示金额」关闭时两行显示「金额已隐藏」。
- **FR-2 「记一笔」快捷操作**:菜单项(数据头与「显示御财」之间)→ 显示并聚焦窗口 + 跳转 `/transactions/new`。
- **FR-3 隐私开关**:设置页「窗口与提醒」区新增行「托盘显示金额」(Switch,默认**开**;TraySettings 新字段 `showTrayAmounts` 持久化,镜像既有字段范式);切换即时生效(菜单重设)。
- **FR-4 菜单刷新**:数据/开关变化即刷新——`Transactions` 表 drift watch(骑 F22 `changeTriggers` 基建,watch 面扩表)+ 周期 tick + 窗口 show 事件 → 防抖重设托盘菜单(重调 `setContextMenu`);摘要查询失败 → 数据头显示「--」占位,不阻断其余菜单项。
- **FR-5 跨模块 port**:core/notifications 不 import transaction 模块——TrayController 注入摘要提供者 `Future<TrayHeadData> Function()`(组合根 bootstrap 接线到 repository;`TrayHeadData{todayIncome, todayExpense, monthBalance}` cents 值对象)。
- **NFR-1 容错**:摘要查询失败/超时 → 「--」占位;菜单重设失败 → 菜单保持旧内容(附属功能降级不炸)。
- **NFR-2 零回归**:全量 `flutter test` + `flutter analyze` 基线一致;托盘失败 fail-safe 语义不变。

## Scope boundary(排除项 + 辩护)

| 排除 | 理由 |
|---|---|
| 净资产行 | 含持仓估值依赖行情刷新,菜单头变报表;grill 已裁 |
| OS 通知/图表 | 无需——数据头即速览 |
| 菜单项自定义图标/字体 | tray_manager 能力所限,纯文本项 |
| i18n | 项目阶段二统一 |

## Grill record

| 决策 | 挑战 | 定案 |
|---|---|---|
| 数据头内容 | 两行 vs 一行 vs 三行(净资产) | 今日+本月结余两行(用户拍板;净资产行因估值刷新依赖被裁) |
| 隐私默认值 | 显示 vs 隐藏 | 默认显示(右键才展开暴露面小;用户拍板) |
| 摘要口径来源 | 新造查询 vs 复用 | 本地 DS summary 单一查询点 day+month 两次调用(复用第一) |
| 刷新机制 | 轮询 vs 事件 | Transactions watch 骑 F22 changeTriggers + tick + show 事件 |

## Feasibility

技术 ✅(查询点/watch/菜单重设能力全已在位);经济 ✅(纯客户端小体量);运营 ✅(菜单重设轻量;失败降级路径明确)。
