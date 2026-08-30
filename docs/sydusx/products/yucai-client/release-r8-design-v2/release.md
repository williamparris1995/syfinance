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
- Next(F2+,待 ticket 化):各模块页面暗色感知迁移(context.yucai)与按原型逐页布局重构。
