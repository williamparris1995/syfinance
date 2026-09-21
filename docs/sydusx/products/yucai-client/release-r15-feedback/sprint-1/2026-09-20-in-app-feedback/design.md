# Design — F41 应用内反馈入口

> R15 sprint-1 · 2026-09-20 · design 产出。spec 见 [spec.md](spec.md)(10 决策 Grill record)。中票紧凑规格(参照 F34/F35;prototype 决策见 ADR-5)。

prototype: none(三入口均为既有组件实例化,零新视觉组合;ADR-5,用户 grill 拍板)

## Context

客户端无反馈通道;spec 定 mailto 直跳 + 三入口(宽屏侧栏整行/窄屏底栏项/设置页行)+ 两降级 + 诊断头 4 字段白名单。零 server/proto 改动,guest 可用。

## Goals / NonGoals

**Goals**:FR-1~FR-6(spec)。**NonGoals**:附件/反馈历史/app 内对话框/server 收集(scope boundary 5 项,spec 既定)。

## Decisions(ADRs)

- **ADR-1 launcher 归属 `lib/core/feedback/`**:三入口消费方 = app_shell(app 模块)+ settings(feature 模块);放任何 feature 模块都会造成 app→feature 或 feature→feature 跨界 import(违 port 约束)。core 层被多处消费有 tray_controller 先例。*挑战:放 settings/data(设置页是主入口)?否——app_shell 也消费,跨界即违约。*
- **ADR-2 IO 全走函数注入缝**:`launchUrl` 与 `Clipboard.setData` 经 typedef 注入(照 `UrlLauncherFn` 先例 oidc_authenticator.dart:29);launcher 对 UI 是「构造 URI + 调缝 + 报结果」,单测零平台依赖。*挑战:直接静态调库省一层?测试要 mock 平台通道,缝是房内既有范式。*
- **ADR-3 `FEEDBACK_EMAIL` = `String.fromEnvironment` 单点**:定义于 feedback_launcher.dart 一处(NFR-2),源码零邮箱明文;Actions release workflow 从 Secret `FEEDBACK_EMAIL` 传 `--dart-define`(NFR-3,一次性配置)。*挑战:asset 配置文件?grill 已否(换邮箱同样要重打包)。*
- **ADR-4 诊断头组装**:launcher 收纯数据 `FeedbackDiagnostics`(4 字段:appVersion/platform/accountMode/themeMode);采集在入口处(async:PackageInfo.version 照 F24 先例,账户模式=AuthBloc state,主题=当前 ThemeMode),白名单字段序为常量。*挑战:launcher 内部自采?混合 IO+构造难测;纯数据+采集分离最简。*
- **ADR-5 `prototype: none`**:三入口均为既有组件实例化(`_NavItemTile` 同构样式/NavigationBar destination/设置页图标行卡)+ 两条 SnackBar 房风,零新视觉组合;视觉契约 = 既有组件 + design-v2 令牌;视觉分量风险由实现后真机走查承担(用户 grill 拍板 2026-09-20)。*挑战:UI-scoped 默认必跑原型?无新设计可化,先例 F39。*

## HLD(单元 + 依赖方向)

```
core/feedback/feedback_launcher.dart   ← 纯构造 + IO 缝(被 2/3 消费,依赖零模块)
   ↑                    ↑
app/widgets/app_shell.dart(宽屏侧栏导航列表尾整行 + 窄屏底栏第 8 项)
                        ↑
settings/presentation/settings_page.dart(设置页图标行)
.github/workflows/release*(--dart-define 注入,非运行时依赖)
```

依赖方向 app/settings → core,零跨 feature(合规)。

## LLD

**core/feedback/feedback_launcher.dart**
- `const feedbackEmail = String.fromEnvironment('FEEDBACK_EMAIL');`(ADR-3 单点)
- `class FeedbackDiagnostics { appVersion, platform, accountMode, themeMode }` + `bodyLines()` 白名单常量字段序:`版本:%s / 平台:%s / 账户:%s(guest|绑定)/ 主题:%s(亮|暗)`。
- `Uri buildFeedbackMailto(FeedbackDiagnostics d)` —— `mailto:<email>?subject=御财反馈&body=<4 行诊断头>`;中文经 `Uri(queryParameters:)` 自动 percent-encode;**email 空串 → 返回值含标记或调用方走降级**(设计:先查 email 再构造,单一路径)。
- `enum FeedbackLaunchResult { launched, emailMissing, launchFailedCopied }`
- `Future<FeedbackLaunchResult> launchFeedback(FeedbackDiagnostics d, {LaunchUrlFn? launch, ClipboardWriter? clip})` —— 缝默认接 `launchUrl(externalApplication)`/`Clipboard.setData`;emailMissing→SnackBar 文案由 UI 层展示;launchFailed→缝写入剪贴板「邮箱+主题+诊断头」文本再返回 `launchFailedCopied`。

**app_shell.dart(两入口)**
- 宽屏 `_Sidebar`:导航组 ListView 尾部追加整行反馈条(fix-2:原设计用户区上方常驻行,720p 实测把债务/债权导航项挤出视口,移入列表尾随列表滚动、固定区零增高,1080p+ 全列表可见即常驻;新私有 widget `_SidebarFeedbackRow`,视觉复用 `_NavItemTile` 样式:leading icon 18px + label 13px(P-F1b:与 tile 图标同尺寸,「20px」系对 tile 的错误转述),Lucide `messageSquareHeart` 或 `messageSquare`,水平内缩零(列表 padding 已含 12px,胶囊与 tile 左缘对齐));onTap → 组装 diagnostics(async 采集)→ `launchFeedback`,结果按 enum 出 SnackBar。
- 窄屏 `_BottomNav`:destinations 增第 8 项(icon Lucide `messageSquare`,label「反馈」);`onDestinationSelected` i==反馈位 → 新增 `onFeedback` 回调参数(AppShell 传入同一 launch 逻辑);不参与 branch 切换与 `_branchSlots`。

**settings_page.dart(一入口)**
- 既有图标行卡区新增「意见反馈」行(icon 同上,同构 `_SettingsRow` 范式),onTap 同一 launch 逻辑;位置放常规设置区末尾(备份/扫描间隔邻近,execute 按页面实际分组微调)。

**.github/workflows(release)**
- 构建命令追加 `--dart-define=FEEDBACK_EMAIL=${{ secrets.FEEDBACK_EMAIL }}`(execute 定位具体 workflow 行)。

**测试**
- `test/core/feedback/feedback_launcher_test.dart`:URI 构造(收件人/subject/body 4 行/percent-encode 断言);**白名单断言**(body 恰好 4 行、仅白名单字段,无 ¥/账户名等财务痕迹);emailMissing;launchFailed→clip 缝被调且文本含邮箱+诊断头。
- `test/app/widgets/app_shell_test.dart` 扩展:宽屏侧栏反馈行渲染+点击回调;窄屏底栏第 8 项(照现有 shell 测试的宽度切换手法,execute 侦察)。
- `test/settings/settings_page_test.dart`:行渲染+点击。

## Risks

| 风险 | 缓解 |
|---|---|
| mailto URL 超长截断 | 诊断头固定 4 行短文本、无用户正文(直跳决策消解输入面);低风险 |
| Windows 无邮件客户端概率不低 | FR-4 降级:剪贴板复制完整反馈文本,网页邮箱可达 |
| NavigationBar 8 项拥挤(已有 7 项,超 Material 建议) | 照抄同款 destination;真机走查确认;不可接受时窄屏退化方案=仅设置页入口(backlog) |
| dart-define 编译期冻结,忘配 Secret → 发布版入口全走降级 | 发布前走查清单加一项「点反馈入口验证唤起」;Secret 一次性配置即闭环 |

## Migration

无数据迁移。发布链一次性:Actions Secret `FEEDBACK_EMAIL` 配置 + workflow dart-define 一行;本地构建零变化(dev 走 emailMissing 降级,入口可走查)。

## Open Questions

无(spec+design 决策全拍板)。
