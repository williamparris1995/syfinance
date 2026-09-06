# Task Brief F15-T1 — core/widgets 共享件迁移 + 顶层调色板常量 context 化

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f15`,客户端 `yucai/client/`。**F4 同款机械迁移;探针测试守门。**

## 先读(必读)
1. `lib/core/theme/app_design.dart`(YucaiTheme 语义令牌全集 + AppColors legacy 定义——迁移目标映射源)
2. F4 探针测试:`grep -rn "暗色\|dark\|follow" test/core/theme/ test/app/ --include="*.dart" -l` 找到 theme-follow 探针(×3),读懂断言模式
3. 改动对象:`lib/core/widgets/` 下含 AppColors 的文件(date_picker_input/conic_progress_ring/debt_view_semantics/debt_detail_widgets/debt_list_widgets/amortization_preview 等,grep 确认全集)+ `lib/app/router.dart`
4. **顶层调色板常量**:`grep -rn "kHoldingTypeColors\|kCategoryColors\|k[A-Z]\w*Colors" lib/ -l`(holding/report 页内静态色列表)——**本任务只迁 core/widgets 触及的或做成共享 context 化 helper**(若常量在被模块页使用,helper 放 core/theme 或 core/widgets,模块页 T2 换调);**数据可视化序列色**(饼图系列色按 F3 设计有意保留)→ 迁 theme 感知(暗色下用适配序列或提高亮度)或注释豁免——**裁决标准:暗色下可辨识且不刺眼**;有 design-v2 源就照源,没有就保守迁语义令牌并注释。

## 迁移规则(照 F4 惯例)
- `AppColors.x` → `context.yucai.<语义令牌>`(映射按 app_design.dart 中 AppColors 的重指向注释/注释组找语义名;无直接对应时选最近语义并注释);**裸 Color(0x...) 一并清理**。
- StatelessWidget 辅助方法/顶层函数无 context → **补 context 形参穿线**(调用点全部更新;签名变化不外溢出 core/widgets——若被模块页调用,保兼容:旧签名 deprecated 转发或一次性改调用点,选后者并在 T2 简报列出)。
- const 构造因 context 失效 → 去 const(照 F4 处理);analyzer 全绿。

## 验证
1. `flutter test` 全量不回归(≥1462;widget 测试中静态色断言如有需同步——只许改成令牌断言,不许删测)
2. `flutter analyze` 0 新增
3. `grep -rn "AppColors\." lib/core/widgets/ lib/app/router.dart | wc -l` = 0(或仅剩注释豁免+豁免清单注释)
4. theme-follow 探针:扩展 1 条覆盖 debt 共享件的暗色断言(core/widgets 迁移的最小守卫)

## 约束
不动模块页(除调色板 helper 换调的最小调用点改动);R8 令牌;中文注释;不 commit。完成后报告(含:豁免清单/调色板裁决/外溢调用点清单)。
