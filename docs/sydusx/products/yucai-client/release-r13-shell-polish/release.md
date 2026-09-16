# R13 · shell 打磨

> 立项 2026-09-15(product checkpoint 后用户拍板)。前序:R12 收官(design-v2 零裸色零杂式)。

## Goal

窗口 chrome 品牌化与桌面体验最后一公里:自定义标题栏(与 F23 图标/F26 hero 同语言)+ 窗口状态记忆 + 文案散件清尾——「可分发的商业级客户端」观感闭环。

## Scope

### IN
- **F29 自定义标题栏**(sprint-1):去 Flutter/系统默认标题栏,品牌化标题栏(logo+窗口控制钮),关闭钮复用 F22 关闭行为决策树;双主题。
- **F30 窗口状态记忆**(sprint-1):位置/尺寸/最大化态持久化与恢复。
- **F31 文案散件**(sprint-1):helperText×2 等后续票清尾。
- **F32 hero 验收缺陷修复**(sprint-2):dashboard 真机验收两缺陷——负净资产千分位错位(−195,616 误显 −,195,616)+ home/账户详情两 hero 光晕被 Stack 硬裁成直边残块(放行溢出,卡面圆角接管)。

### OUT / Defer
- 系统托盘/任务栏缩略图工具栏(Explorer 深水区)
- 多窗口/标签页
- 阶段二 i18n

## 状态

- 2026-09-15 **sprint-1 ✅ 收官 = R13 release 收官**:F29 标题栏(`4a4a676b`)/F30 窗口状态(`3bd8cd35`)/F31 散件(`17a2073e`)全 done——窗口 chrome 品牌化+状态记忆+文案清尾,「商业级观感最后一公里」达成;真机验收(Snap/双击/三钮/窗口恢复)待用户。
- 2026-09-15 **sprint-1 立项**:F29/F30/F31。[sprint-1](sprint-1/sprint.md)
- 2026-09-16 **sprint-2 立项+✅ 收官**:F32 hero 验收缺陷修复(merge `0f220db6`[ff];用户拍板挂 R13;精简走法 feature/spec 在 feature 目录;worktree 门 1735 全绿+analyze 429 基线;真机 dashboard 复核待用户)。[sprint-2](sprint-2/sprint.md)

## status: done(2026-09-15 sprint-1 / 2026-09-16 sprint-2 补票;任务栏缩略图/多窗口 defer)
