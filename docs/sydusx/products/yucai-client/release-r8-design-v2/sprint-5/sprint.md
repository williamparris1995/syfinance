# Sprint 5 — R8 F4-P2 穿线收尾

> `/sydusx-portfolio`(2026-09-03)。来源:R8 F4 时明确留下的 P2 backlog(~306 处 light-locked,现实测 321)。

## Sprint Goal

F4-P2 清零:剩余 AppColors 静态引用(321 处/20+ 文件)全量迁移 context.yucai 语义令牌 + 顶层调色板常量(kHoldingTypeColors/kCategoryColors 等)context 化——暗色主题全应用无残留亮色点。

## Feature roster

- [x] **feature F15** f4p2-threading — F4-P2 穿线收尾 ✅ done(2026-09-03,merge `b2a04b73`;AppColors 321 处清零+调色板双板+tagColor 解耦+F3 保留色退役闭环;94 裸色全对账豁免清单;A2 金图合法重生成;门全绿;onAccent sweep backlog 票在案)

## defer

- 净资产深色 hero 重设计(视觉决策,design-v2 源定方向后另做)
- 占位文案清理(copy 决策)
- F6 疑点 #5/#6(既有 defer)

## status: done(F15 ✅ 2026-09-03——F4-P2 light-locked 清零,暗色全应用语义令牌化达成[Colors.* 口径遗留由 backlog 票承接])
