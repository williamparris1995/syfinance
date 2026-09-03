# R8 · 设计系统 v2 落地(design-v2)

> 立项 2026-08-30。设计源与唯一视觉事实源:[../design-v2.md](../design-v2.md);原型 `design-output-v2/ab/`(12 页双主题)。
> 前序:[R7 windows-usable](../release-r7-windows-usable/release.md) 已收官。

## Goal

把 2026-08-30 确认的 A+B 亮暗双主题设计系统(design-v2)落地到 Flutter 客户端:令牌层替换 v1(奶油白+御财金+serif),建立暗色主题与用户可切的主题模式(跟随系统/亮/暗,持久化),并按新 IA 渐进迁移各模块页面。对标 vision 的"商业级客户端 UI"目标(对标 MoneyWiz/Wise)。

## Scope

### IN
- **F1 设计令牌 v2 + 双主题地基**(本轮,worktree `feature/r8-f1-design-tokens-v2`):
  - `core/theme/app_design.dart` v2:双套语义令牌(墨鎏金/晨白)+ ThemeExtension(`YucaiTheme`)承载主题感知色。
  - `core/theme/app_theme.dart`:`AppTheme.light()` 换 v2 亮色(翡翠绿/净白/全无衬线),新增 `AppTheme.dark()`(鎏金/墨黑)。
  - ThemeController(getIt 单例):ThemeMode 内存态 + 持久化;`app.dart` MaterialApp 接线(theme/darkTheme/themeMode)。
  - 设置页新增「外观 → 主题模式」(跟随系统/亮/暗);顶栏主题切换按钮(app_shell)。
  - `app_shell.dart` 迁移到主题感知色(侧栏/顶栏)。
  - 兼容策略:legacy `AppColors` 静态量保留并重指向 v2 亮色值(全量页面瞬间获得 v2 亮色观感;暗色感知迁移列为 F2+)。
  - 测试:令牌/主题单测 + 全量 `flutter analyze` + `flutter test`。
- 文档归档:本 release + [design-v2.md](../design-v2.md);原型 `design-output-v2/`(根目录,同 v1 `design-output/` 惯例,不入 docs)。

### OUT / Defer(F2+ 待 ticket)
- 各模块页面(accounts/transactions/debt/holding/budget/goal/report/backup/binding/auth)的主题感知暗色迁移(仍引用 legacy 静态量,暗色下呈 v1 布局+亮色卡)。
- 表单/详情按原型逐页重构(卡片网格/表格化等布局级改造)。
- i18n(阶段二不变)。

## 状态

- 2026-08-30 **F1 ✅ done**(worktree `feature/r8-f1-design-tokens-v2` → merge `6c48ed8c` → main,worktree 已清理):
  - `app_design.dart` v2([YucaiTheme] ThemeExtension 晨白/墨鎏金双令牌 + legacy AppColors 重指向 v2 亮色 + 全无衬线 + 圆角放大一档)。
  - `app_theme.dart`:`light()` 重写 + 新增 `dark()`;`app.dart` 接 themeMode。
  - `theme_settings.dart`(新):flutter_secure_storage 持久化主题模式(镜像 CurrencySettings 模式);`injection` 注册 + bootstrap load。
  - 设置页「主题模式」(跟随系统/亮/暗)SegmentedButton,实时生效。
  - `app_shell.dart` 全面迁移 context.yucai(侧栏/顶栏/底栏/横幅,0 静态色残留)。
  - 测试:新增 18 个令牌/主题单测;budget/goal v1 hex 断言改语义色;router/settings/archive 测试 harness 补 ThemeSettings fake;全量 flutter test 回到 3 文件 drift 基线,flutter analyze 无新增 error(hook 在 worktree 提交时指向主仓库不生效,gate 人工执行:analyze + 全量 test 均过)。
- 2026-08-30 **F2 ✅ done**(页面缺陷修复,merge `cd887194`):
  - **Bad state 修复**:/debts 与 /debts/new 的 BlocProvider `create:` 拥有共享 DebtBloc 单例,路由 dispose 时 close → 切页返回 `Bad state: Cannot add new events after calling close`;改 `.value`(页面自加载,对齐 /receivables)。全库排查确认仅此两处单例误用,其余 bloc 均 factory 作用域无此问题。
  - **v1 残留色清理**:debt/receivable detail 奶油白底、report 顶栏、交易红绿、stat 图标底 → 语义令牌;分类饼图色板为数据可视化序列色按设计保留。
  - **drift 基线清零(历史首次全量绿,1178 tests)**:3 个长期容忍的 drift 文件根因均为测试腐烂而非页面缺陷 —— receivables L4(断言未圈列表区,overview callout 按设计不随筛选变化)、固定日期时间炸弹(2026-08-15/2026-07-15 写作"未来"已真实逾期 → 夹具改相对日期)、account_detail 统计(Issue-② scope 过滤后夹具旧日期计 0 → 当月日期)。
- 2026-08-30 **F3 ✅ done**(全页面设计一致性 pass,merge `5b6a8f11`):审计发现 20+ 文件散落 **49 处 v1 一-off 色值**(奶油底变体 FBFAF6/F1EDE5/EFECE5…、v1 金系 E0BD84/98773F、旧红绿 6FCF9A/E57373、暖灰 7A776E/A8A298)—— 即"页面之间色调不一致"的根源;全部映射到语义令牌(surfaceAlt/accentSoft/accent·accentHover/positive·negative/muted),16 个模块页在 v2 净白下色调统一。有意保留:超预算深红 #C0392B(文档化区分色)、净资产深色 hero 渐变(v1 设计特征,F4 重设计)、图表系列色/类型徽章色对(数据可视化编码)。
- 2026-08-30 **F4 ✅ done**(全应用暗色感知迁移,merge `cf5f92ce`):**1532 处 AppColors 静态 → context.yucai**(46 个模块页/共享组件),v2 双主题自此全应用生效 —— 设置页切「暗色」即全应用墨鎏金。配套:debt 共享组件剩余 34 处 v1 hex 归一;分析器驱动迁移引擎(fix_dark:invalid_constant/const 声明/顶层 context 三类错误自动修复,4 轮收敛);initState inherited 访问审计 0 违规;新增 theme-follow 探针测试 ×3;全量 1181 tests 绿。
- **F4-P2 backlog**(本轮回退点,~306 处仍 light-locked):StatelessWidget 辅助方法的 context 形参穿线(debt_detail_widgets/debt_list_widgets 为主)、顶层调色板常量(kHoldingTypeColors/kCategoryColors 等)、净资产深色 hero 重设计、占位文案清理。
- 2026-09-03 **sprint-3 立项**(查询功能补全线,源自 F6 测试暴露缺口,用户拍板):[sprint-3](sprint-3/sprint.md) — **F7 列表查询四件套**(category 筛选接线/文本搜索/排序控件/分页 UI,用户点名重点)+ **F8 标签维度**(反查交易+报表标签口径)。
- 2026-09-02 **sprint-2 立项**(测试基础线,非设计迁移):[sprint-2](sprint-2/sprint.md) — **F6 E2E 全模块关联链路补全** ✅ done(2026-09-03,merge `160c3f30`)。交付:10 条管道链 + 2 条件项裁决(预算滚动纳入/FX 排除)+ 11 条 UI 链,**两层回归入口**——`make client-e2e`(默认回归,10 文件 47 测试,种子→断言→测后删库,`F=` 单文件精准重跑)与 `make client-e2e-ui`(手动按需,11 文件 17 测试);链路矩阵含买入镜像/报表 oracle/变更级联/备份加密往返;真实库零接触(裸跑守卫)。附带修复仓库金图卫生地雷(.gitignore `*.png` 挡掉 3 金图 → 反向规则入库)。backlog(标签反查/category 接线/生产疑点 6 处等)见 sprint-2 defer。F5 menu-anchor 由另一会话进行中(worktree `r8-f5`),不属本 sprint 追踪。
