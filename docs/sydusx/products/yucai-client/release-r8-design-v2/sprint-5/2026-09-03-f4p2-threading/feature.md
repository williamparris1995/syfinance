# Feature — F15 F4-P2 穿线收尾(R8 sprint-5)

> 2026-09-03 用户"继续"推进 R8 backlog。

## Description

F4 暗色迁移的 P2 回退点清零:剩余 321 处 `AppColors.*` 静态引用(暗色下 light-locked)迁移到 `context.yucai` 语义令牌;StatelessWidget 辅助方法补 context 形参穿线(debt_detail_widgets/debt_list_widgets 为主);顶层调色板常量(kHoldingTypeColors/kCategoryColors 等静态 Color 列表)context 化(取 theme 令牌或按语义映射)。F4 的"分析器驱动迁移引擎"与 theme-follow 探针测试可复用。

## Stories

- [ ] S1: core/widgets 共享件迁移(debt_detail/debt_list/debt_view_semantics/date_picker/conic/amortization 等)
- [ ] S2: 模块页迁移(account/auth/backup/debt/holding/goal/report/tag/template/currency 等 20+ 文件)
- [ ] S3: 顶层调色板常量 context 化(kHoldingTypeColors/kCategoryColors 等——数据可视化序列色按设计保留的,迁移到 theme 感知或注释豁免)
- [ ] S4: 回归门(theme-follow 探针扩展+全量门;AppColors 残留清零或仅剩注释豁免清单)

## title

F15 F4-P2 穿线收尾(light-locked 清零)

## keywords

f4p2, theme-threading, context-yucai, light-locked, dark-mode, palette-constants, F15
