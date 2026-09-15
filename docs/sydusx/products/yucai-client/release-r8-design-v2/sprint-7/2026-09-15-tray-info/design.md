# Design — F25 托盘数据头 + 快捷操作

**prototype: none**(唯一新应用内 UI = 设置页一个标准 Switch 行,零新视觉词汇——setting-row 与 switch 均为 design-v2 §4 既有组件、F22 已在设置页落地同款行;托盘菜单文本项非应用内 UI,tray_manager 纯文本能力所限)

## Context

[spec.md](spec.md)。F22 地基:TrayController 注入化(settings/changeTriggers/closePrompt/contextResolver/exitFn/traySetup 缝)、`buildContextMenu()` 单一事实源、drift watch 防抖路径、TraySettings 三字段范式。事实:`summary(year, month, {scope: day|month, day})` 本地 DS 单一查询点;`/transactions/new` 路由在;`Transactions` 表可 watch;`setContextMenu` 可重复调用刷新。

## Goals / NonGoals

- **Goals**:两行数据头(今日/本月)+ 记一笔快捷 + 隐私开关;全部骑 F22 基建,零新范式。
- **NonGoals**:净资产行;菜单富文本;绑定态远程口径(数据头恒本地口径)。

## Decisions(ADR)

### ADR-1 摘要 = 函数注入 port(`TrayHeadProvider`)
- **决策**:`typedef TrayHeadProvider = Future<TrayHeadData?> Function();`——TrayController 构造可选注入;`TrayHeadData{int todayIncomeCents, todayExpenseCents, monthBalanceCents}` core 侧值对象。bootstrap(组合根豁免)接线:day+month 两次 `summary()` 调用映射。
- **理由**:core→transaction 模块 import 违反仓跨模块约束;函数注入与 F22 既有缝(exitFn/traySetup)同构,最小面。
- **备选**:定义抽象接口类(更重,单函数无需);TrayController 直查 DS(违 port 约束)。

### ADR-2 刷新 = 三触发合一(防抖重设菜单)
- **决策**:`_refreshMenu()`:调 provider → 组 label → `setContextMenu`(失败静默保持旧菜单,NFR-1)。触发面:①changeTriggers 防抖路径尾部(F22 watch 面由 bootstrap 扩入 `Transactions` 表,同一次防抖先扫后刷菜单);②周期 tick 尾部;③窗口 show 事件;④showTrayAmounts listenable 变更。
- **理由**:数据变更/跨日/回窗口/开关切换四种变化全覆盖;重设菜单成本≈一次 setContextMenu,轻量。
- **备选**:仅在右键时重设(tray_manager 无菜单打开回调,不可行);定时轮询(延迟差)。

### ADR-3 隐私开关 = TraySettings 第四字段 + 设置页既有行模式
- `showTrayAmounts`(默认 true,键 `tray_show_amounts`,镜像既有字段);设置页「窗口与提醒」区加 Switch 行(照主题模式行的行布局 + design-v2 switch)。

### ADR-4 记一笔 = 菜单项 → show+focus + GoRouter push
- bootstrap 注入导航闭包(组合根,`contextResolver` 同源 context → `GoRouter.of(context).push('/transactions/new')`);无 context → 仅 show/focus(降级不炸)。

## HLD

```
core/notifications/
  tray_controller.dart   TrayHeadProvider/TrayHeadData 注入;buildContextMenu(head, showAmounts)
                        参数化;_refreshMenu;记一笔 action;show 事件挂 WindowListener.onWindowFocus/Show
  tray_settings.dart     +showTrayAmounts 字段(第四范式字段)
  notifications_bootstrap.dart  组合根:provider 接线(summary×2 映射)/Transactions 入 watch 面/
                        记一笔导航闭包
settings/presentation/settings_page.dart  「窗口与提醒」区 + Switch 行
```

## LLD 关键流程

- `buildContextMenu(TrayHeadData? head, bool showAmounts)`:`[今日行(disabled), 本月行(disabled), 分隔线?, 记一笔, 显示御财, 退出]`——disabled 项 tray_manager 以 `disabled: true`;金额格式 `¥1,234`(负结余 `-¥123`,正 `+¥123`);隐藏 → 「金额已隐藏」单行;head==null(查询失败/未注入)→ 「--」。
- 首启顺序:start() 托盘注册成功后即 `_refreshMenu()`(首次数据头);查询异步不阻塞托盘就绪(先注册后填充)。
- 测试缝:provider/listener 注入后 tray_controller_test 断言:菜单项枚举含头两行 disabled+记一笔;隐藏开关切换 label 变化;provider null → 「--」;watch 触发后菜单重设调用;设置页 Switch 行持久化 verify。

## Risks

| 风险 | 缓解 |
|---|---|
| setContextMenu 频繁重设的平台抖动 | 防抖合流(F22 500ms 同款);tick 最低 15 分钟,量级无忧 |
| summary 慢查询阻塞菜单刷新 | provider async,刷新不 await 扫描路径;失败占位 |
| 绑定态本地/远程口径差 | 数据头恒本地口径,spec NonGoals 已记 |

## Migration

纯新增;默认显示金额=新能力即时可见;开关可关。

## Open Questions

- 「记一笔」落点在移动端窄屏路由行为(/transactions/new 通用)——实现时真机走查确认。
