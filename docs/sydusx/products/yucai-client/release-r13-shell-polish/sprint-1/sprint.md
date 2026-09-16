# Sprint 1 — R13 F29/F30/F31 shell 三件

> /sydusx-portfolio(2026-09-15)。

## Sprint Goal

窗口 chrome 品牌化(自定义标题栏接 F22 关闭行为)+ 窗口状态记忆 + 散件清尾。

## Feature roster

- [x] **feature F29** title-bar — 自定义标题栏(方案经 grill;关闭钮→windowManager.close() 触发 F22 决策树;双主题;拖拽/双击最大化/最小化钮) ✅ done(2026-09-15,merge `4a4a676b`[ff];双 A 拍板 hidden+经典双层;侧栏徽标统一;评审修复 S1/P1/P2/S2;1699 全绿)
- [x] **feature F30** window-state — 位置/尺寸/最大化持久化恢复(安全回退:出屏检测回默认) ✅ done(2026-09-15,merge `3bd8cd35`[ff];32 测+评审修复钳制语义;1731 全绿)
- [x] **feature F31** copy-oddments — helperText×2 等散件(F28 后续票) ✅ done(2026-09-15,merge `17a2073e`[ff];纯字符串三处,1731 全绿)

## defer

- 任务栏缩略图工具栏/多窗口

## status: done(F29 `4a4a676b`/F30 `3bd8cd35`/F31 `17a2073e` 全 done,2026-09-15)
