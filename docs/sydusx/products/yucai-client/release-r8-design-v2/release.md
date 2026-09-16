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
- **F4-P2 backlog**:穿线+调色板已由 **F15 ✅**(merge `b2a04b73`,2026-09-03)清零——AppColors/裸色口径 light-locked 归零,kHoldingTypeColors/kCategoryColors 双板化,**F3 有意保留项超预算深红 #C0392B 正当退役**(本行上方的保留声明就此作废,退役依据见 sprint-5 feature.md)。余:净资产深色 hero 重设计、占位文案清理(defer);onAccent sweep(Colors.* 口径 ~20+ 处)backlog 票。
- 2026-09-03 **F7 列表查询四件套 ✅ done**(merge `9eee8de5`):交易列表 category 筛选接线(UI 下拉→bloc→DS 全链)+描述模糊搜索(onSubmitted 提交制,修逐键焦点丢失)+日期/金额×升/降四态排序(tie-break 恒日期 id 降序,默认序不变)+页码分页条(token 栈状态机,筛选变化重置第 1 页);54 新单测+e2e 级链⑦/UI 三断言;三门 GREEN。非阻断注记:翻页夹具 2026-12 时效假设(3 个月窗口)/mobile 顶栏搜索图标 P2 占位/LoadMore 事件保守保留。
- 2026-09-03 **F9 列表能力统一 ✅ done**(merge `95c11fa6`):共享分页件泛化(PagerBar/PageCursorStack/SearchField)+账户详情内嵌交易标准套件(替换 Task6 5条/页迷你分页)+持仓分页搜索(listPaged,20/页)+债务债权搜索四态排序(domain 查询收编单一事实源)+账户页搜索;按实体增长矩阵,低增长页(预算/目标/分类/标签/模板)零改动;56 新单测+e2e 6 断言;可选 backlog 3 条见 code-plan ledger。
- 2026-09-03 **sprint-3 立项**(查询功能补全线,源自 F6 测试暴露缺口,用户拍板):[sprint-3](sprint-3/sprint.md) — **F7 列表查询四件套**(category 筛选接线/文本搜索/排序控件/分页 UI,用户点名重点)+ **F8 标签维度 ✅ done**(merge `621b5976`,反查/跳转/报表口径/boundRemote 隐藏)——sprint-3 三 feature 全 done。
- 2026-09-15 **F25 ✅ done**(托盘数据头+快捷操作,merge `e5e1734e`[fast-forward]):托盘菜单顶部两行动态数据头(今日收·支/本月结余,本地 DS summary 单点 day+month 复用)+「记一笔」快捷(show+focus→/transactions/new,无 context 降级)+「托盘显示金额」隐私开关(设置页,默认开);刷新=Transactions watch 骑 F22 防抖+tick+窗口 show 三触发;TrayHeadProvider 函数注入 port(core 零 transaction import);失败容错(--占位/保持旧菜单);TDD 17 新测+1665 全绿+analyze 基线;双轴评审过。——**sprint-7 收官**(F22/F23/F25 全 done;F24 自动更新 defer 候选)。
- 2026-09-15 **F23 ✅ done**(字符标「御」品牌图标全套,merge `f5d7ac2b`):变体 A(墨底圆角+鏏金渐变「御」雅黑 Bold)六档 ICO 16/24/32/48/64/256 替换 runner Flutter 默认图标;托盘 16/24 独立**印章简化形**(暗金外框+亮金三笔抽象;三轮视觉 QC 裁决:字体降采样/滤波剪影 16px 均不可辨,手绘基元达发布标准);tool/gen_app_icon.py 管线可重跑(参数集中/字体缺失报错/幂等);评审修复:托盘 AppData 缓存内容不一致即覆盖(升级用户不滞留旧图标);ICO 结构守护测试+1648 全绿+analyze 基线;真机任务栏/托盘走查待用户(图标缓存 ie4uinit -show 刷新)。
- 2026-09-15 **F22 ✅ done**(退出入口与关闭行为+扫描调度治本,merge `6e6d1698`):设置页底部「退出御财」即时退出(AppExitPort)+「关闭按钮行为」设置(隐藏到托盘[默认]/退出程序,持久化)+ 首次关闭一次性对话框(Esc/×=取消不消耗标记)+ **变更即扫**(drift watch 两表防抖 500ms,流错吞+周期兜底——同日新建到期项秒级提醒,治本替代手动「立即检查」)+ 可配扫描间隔(15/30/60 分钟撤跨日门槛)+ 托盘菜单撤「立即检查」;TrayController 完全注入化(F25 托盘数据头地基就位);TDD 37 新测+1643 全绿+client-e2e 过+整体 review 门 pass(原型对照 0 MISSING/0 WRONG);advisory 3 条(quit() try/finally 统一/negativeSoft 令牌债务/计划措辞)见 code-ledger;真机人工验收清单 5 项待用户。
- 2026-09-15 **sprint-7 立项**(应用菜单+品牌图标,brainstorm 四项拍板;grill 中两轮扩展),[sprint-7](sprint-7/sprint.md) — **F22 顶栏应用菜单**(设置/退出,MenuAnchor 复用 F5 yucaiMenuStyle)+ 关闭行为设置化+首提示 + **扫描调度治本**(变更即扫+用户可配间隔周期扫,撤「立即检查」) / **F23 字符标「御」图标全套**(多尺寸 ICO 替换 runner+托盘图标,不用 flutter_launcher_icons[Windows 单尺寸 #573]) / **F25 托盘数据头+快捷操作**(今日收支/本月结余动态区+记一笔+隐私开关,排 F22 后);**F24 自动更新记 defer 立项候选**(auto_updater+GitHub Releases+发布流水线+签名校验,独立排期)。
- 2026-09-02 **sprint-2 立项**(测试基础线,非设计迁移):[sprint-2](sprint-2/sprint.md) — **F6 E2E 全模块关联链路补全** ✅ done(2026-09-03,merge `160c3f30`)。交付:10 条管道链 + 2 条件项裁决(预算滚动纳入/FX 排除)+ 11 条 UI 链,**两层回归入口**——`make client-e2e`(默认回归,10 文件 47 测试,种子→断言→测后删库,`F=` 单文件精准重跑)与 `make client-e2e-ui`(手动按需,11 文件 17 测试);链路矩阵含买入镜像/报表 oracle/变更级联/备份加密往返;真实库零接触(裸跑守卫)。附带修复仓库金图卫生地雷(.gitignore `*.png` 挡掉 3 金图 → 反向规则入库)。backlog(标签反查/category 接线/生产疑点 6 处等)见 sprint-2 defer。F5 menu-anchor 由另一会话进行中(worktree `r8-f5`),不属本 sprint 追踪。(2026-09-16 回收:代码已全合并入 main,worktree/分支已清,feature 空闲。)

## status: done(2026-09-15 收官)

sprint-1~7 全 done(F1-F9/F14/F15/F21-F25);双主题全应用语义令牌化达成;E2E 双层回归门在案。**R8 defer 清单**(→ R12 design-debt 线 ticket 化):净资产深色 hero 重设计(v1 固定深面→design-v2 §4 随主题形态)、onAccent sweep(~20+ Colors.* 裸色口径)、占位文案清理、F6 疑点 #5/#6、自定义标题栏候选、AI 语音助手待 ticket。真机人工验收清单待用户(F22/F23/F25 相关)。
