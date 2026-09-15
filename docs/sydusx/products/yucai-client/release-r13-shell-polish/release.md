# R13 · shell 打磨

> 立项 2026-09-15(product checkpoint 后用户拍板)。前序:R12 收官(design-v2 零裸色零杂式)。

## Goal

窗口 chrome 品牌化与桌面体验最后一公里:自定义标题栏(与 F23 图标/F26 hero 同语言)+ 窗口状态记忆 + 文案散件清尾——「可分发的商业级客户端」观感闭环。

## Scope

### IN
- **F29 自定义标题栏**(sprint-1):去 Flutter/系统默认标题栏,品牌化标题栏(logo+窗口控制钮),关闭钮复用 F22 关闭行为决策树;双主题。
- **F30 窗口状态记忆**(sprint-1):位置/尺寸/最大化态持久化与恢复。
- **F31 文案散件**(sprint-1):helperText×2 等后续票清尾。

### OUT / Defer
- 系统托盘/任务栏缩略图工具栏(Explorer 深水区)
- 多窗口/标签页
- 阶段二 i18n

## 状态

- 2026-09-15 **sprint-1 立项**:F29/F30/F31。[sprint-1](sprint-1/sprint.md)
