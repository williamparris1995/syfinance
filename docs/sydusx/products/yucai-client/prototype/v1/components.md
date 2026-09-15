# Components — prototype v1(F22)

> 复用优先:本 feature 未新造视觉词汇,以下均为 design-v2 既有词汇的组合;沿用组件(卡片/seg 轨道/btn-primary/btn-ghost/icon-btn/侧栏/顶栏)直接复用 `design-output-v2/ab/assets/theme.css` 类,不在此重复注册。

## 新注册(F22)

| 组件 | 用途 | 状态 | 令牌对齐 | 位置 |
|---|---|---|---|---|
| `setting-row-seg` | 设置行:左标签(+hint)+ 右 SegmentedButton | 默认/hover/选中 | --seg-track/--surface/--acc/--muted/--line | ui/settings-window-reminders.html |
| `btn-exit-footer` | 设置页最底全宽「退出御财」soft destructive 按钮 | 默认/hover | --neg-soft/--neg/圆角12 | ui/settings-window-reminders.html |
| `dialog-first-close` | 首次关闭一次性对话框(scrim+卡+双按钮+×/Esc 取消) | 打开/取消/选择 | --scrim(页级令牌)/--surface/--border/--btn-*/--neg | ui/first-close-dialog.html |

## Flutter 侧映射(execute 实现对照)

| 原型组件 | Flutter 实现 |
|---|---|
| `setting-row-seg` | 设置页既有行布局 + `SegmentedButton<T>`(主题模式行同款) |
| `btn-exit-footer` | `FilledButton.tonal` 变体或自定义(negSoft 底 + neg 描边/文字;语义色走 YucaiTheme) |
| `dialog-first-close` | `showDialog` + `AlertDialog` 变体(barrierColor=scrim;actions 右对齐次/主) |
