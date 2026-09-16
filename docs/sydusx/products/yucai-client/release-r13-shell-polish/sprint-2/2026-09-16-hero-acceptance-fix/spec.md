# Spec — F32 hero 验收缺陷修复

> 2026-09-16;精简走法(F21 先例):spec 即方案,不另立 design.md(UI 缺陷修复,方案唯一无分叉)。

## FR

- FR-1 净资产 hero 负数显示:负号紧贴首位数字,千分位只在数字部分定位(−195616 → 「−195,616」);千分位分组函数对一切带符号整数输入安全,不依赖调用点先行 abs 化。
- FR-2 home 净资产 hero 与账户详情 hero 的径向光晕:允许溢出内容框,由卡面(HeroShell 内层 antiAlias)按卡片圆角裁剪;不得出现被内容框硬裁出的直边残块。

## NFR

- NFR-1 行为变更必有测:FR-1 → home_page 负净资产 widget 回归测;FR-2 → auth/account 两份 hero 主题跟随测试各补 Stack clip 结构断言。
- NFR-2 门:client 全量 flutter test 全绿;flutter analyze 不新增(429 基线)。

## Acceptance

- GIVEN net worth = −¥195,616.00 WHEN 渲染 dashboard hero THEN 大卡整数部分显示 −195,616,且全树无「负号后紧跟逗号」的错位产物。
- GIVEN 亮/暗任一主题 WHEN 渲染两 hero THEN 光晕容器存在(ADR-4 单值 0.18)且其所在 Stack 的 clip 为放行溢出(非默认硬裁)。

## Scope boundary

- 不改光晕设计本身(ADR-4 双主题 0.18 保留项);亮色翡翠绿观感如需调整属设计决定,另开票。
- 不动收支卡/prog-amt 等已先行 abs 化的格式化调用点;不涉 server。

## 关联

- 缺陷载体:F26 hero 终态(R12 sprint-1,merge `0fa0123b`)引入的 HeroShell/光晕 + 更早的 home_page 千分位函数(负净资产数据下暴露)。
