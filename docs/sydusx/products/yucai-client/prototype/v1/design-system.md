# Prototype v1 — F22 设置页「窗口与提醒」区 + 首次关闭对话框

> tier: high-fi(design 阶段) · path: **B-fallback(自生成 HTML)**——OD/Penpot MCP 本环境不可用;无设计师 canvas。
> **契约不发明**:设计系统 = design-v2(已用户确认 2026-08-30),令牌唯一事实源 `design-output-v2/ab/assets/theme.css`(双主题),本目录 `tokens.css` 以 `@import` 直连(单一事实源,不复制值)。F22 新组件 = 既有词汇的新组合。

## 输入来源(step 2 对账)

- **项目文档**:[design-v2.md](../../../../design-v2.md)(视觉 SSOT)· `design-output-v2/ab/assets/theme.css`(令牌+组件类)· [spec.md](../../../products/yucai-client/release-r8-design-v2/sprint-7/2026-09-15-app-menu/spec.md)(FR-1~3)
- **参考产品**:Microsoft Win32 通知区指南(close-to-tray 设置化+首提示);KeePass/Obsidian 关闭确认模式;Windows 11 系统对话框(标题/正文/主次按钮)
- **用户输入**:grill 四决策(即时退出/首关对话框双按钮+Esc 取消/设置页承载/撤立即检查)

## 页面清单(ui/)

| 文件 | 内容 | 复用 |
|---|---|---|
| `ui/settings-window-reminders.html` | 设置页骨架 + 既有区(外观/数据,节选作上下文)+ **新「窗口与提醒」区**(关闭按钮行为 2 段/提醒检查频率 3 段)+ **底部「退出御财」destructive 按钮** | theme.css: .sidebar/.topbar/.page/.btn-*/.icon-btn/seg 令牌 |
| `ui/first-close-dialog.html` | 首次关闭对话框:遮罩 + surface 卡(圆角16)+ 标题/正文 + `[退出程序]`(次)/`[最小化到托盘]`(主)+ 右上 ×(=Esc=取消关闭不消耗标记) | --surface/--neg/--neg-soft/--btn-* |

## 新组件规格(components.md 详)

- **setting-row-seg**:设置行 = 左标签(13/600 fg)+右 SegmentedButton(track=--seg-track,选中=--acc 系)。语义同 Flutter `SegmentedButton`,间距 6/12/16。
- **btn-exit-footer**:设置页最底全宽 destructive 按钮(height 40,圆角 12,bg=--neg-soft/描边=--neg/文字=--neg,hover 加深)。**不用**实底红(与 F21「清空数据」行内警示同强度,避免误触)。
- **dialog-first-close**:modal,scrim 55%,卡 400px 宽/圆角 16/padding 20;标题 15/700;正文 13/--muted;actions 右对齐(次=文字钮 --muted hover --neg,主=--btn-bg 渐变)。Esc/× = 取消关闭、不消耗标记。

## a11y

- 对话框 `role="dialog"` `aria-modal`;Esc 绑定取消;焦点初始落主按钮。
- SegmentedButton 选项为按钮组语义(Flutter 侧 SegmentedButton 原生支持)。
- destructive 文案与图标双通道(文字+⚠ 图标语义由颜色+文字承载,不单靠颜色)。

## token-usage lint

页内样式仅用 `var(--*)`;页级新增令牌仅 `--scrim`(遮罩,定义于页 :root,属 token 定义区)。覆盖率 100%,无散落硬编码色。
