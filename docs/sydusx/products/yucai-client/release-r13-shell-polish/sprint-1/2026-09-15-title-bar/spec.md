# Spec — F29 自定义标题栏

> 2026-09-15 grill 双 A 拍板:实现=TitleBarStyle.hidden(保原生边框/Snap);形态=经典双层。R13 sprint-1。

## Requirements

- **FR-1 隐藏系统标题栏**:窗口初始化 `windowManager.waitUntilReadyToShow` 配置 `titleBarStyle: TitleBarStyle.hidden`——保留原生窗口边框/阴影/Snap 贴靠/拖边缩放(chrome 只换标题栏内容,不动窗口行为)。
- **FR-2 标题栏组件(经典双层第一层)**:高 ~38;左=「御」金渐变圆角徽标(34px,同 prototype `.brand-mark` 形制)+「御财」字样;右=三钮「─ / □(最大化态切换 ❐) / ✕」;整行(钮除外)=拖拽区(`windowManager.startDragging()`),双击=toggle 最大化。
- **FR-3 窗口钮语义**:最小化→`minimize()`;最大化→`isMaximized()?unmaximize():maximize()`(图标随 `onWindowEvent(maximize/unmaximize)` 切换);**关闭→`windowManager.close()`**——setPreventClose 既有 true → 触发 F22 onWindowClose 决策树(设置化关闭行为+首关对话框+托盘失败 fail-safe),**零新关闭逻辑**。
- **FR-4 双主题与交互态**:标题栏底/描边走语义令牌(侧栏/顶栏同口径);钮 hover=muted 派生底;**关闭钮 hover=negative soft**(行业惯例红警示);active 态按下反馈。
- **FR-5 接入 app_shell**:桌面宽屏与窄屏均置于 `_TopBar` 之上(全断点,chrome 不缺席);guest/登录前窗口同样生效(app 根级)。
- **NFR-1 原生行为零损**:Snap/贴靠/边缘缩放/Win 快捷键(Win+↑↓ 等)不走 app 代码,hidden 模式天然保留——真机验收项。
- **NFR-2 零回归**:全量 `flutter test` + `flutter analyze` 基线一致;F22 关闭路径既有测试全绿。

## Scope boundary

| 排除 | 理由 |
|---|---|
| 全自绘 frameless(边框/阴影) | grill D1 裁:丢原生 Snap,深水区风险不成比例 |
| 融合单层标题栏 | D2 裁 |
- 右键系统菜单(还原/移动/大小/最小化…) | hidden 模式无原生菜单;自实现属锦上添花,记 backlog

## Grill record

| 决策 | 挑战 | 定案 |
|---|---|---|
| 无边框路线 | hidden(留原生边框)vs frameless 全自绘(品牌最大但丢 Snap) | hidden(用户拍板) |
| 内容形态 | 经典双层 vs 融合单层 vs 极简 | 经典双层(用户拍板) |
| 关闭钮 | 新逻辑 vs 复用 | 复用 F22 决策树(close() 即触发,零新逻辑) |

## Feasibility

技术 ✅(window_manager 在位能力齐:hidden/startDragging/isMaximized/maximize 系;channel mock 测试范式已建);经济 ✅;运营 ✅(真机验收 Snap/双击/三钮)。
