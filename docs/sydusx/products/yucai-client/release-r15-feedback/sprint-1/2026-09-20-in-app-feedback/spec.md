# Spec — F41 应用内反馈入口

> R15 sprint-1 · 2026-09-20 · analysis 产出。brainstorm 两决策(mailto 通道/双入口)+ grill 7 决策(注入机制/缺省/降级/两项排除/写在何处/诊断头)用户拍板。

## 查证事实基线

- `url_launcher: ^6.3.2` 已在 pubspec——OIDC(`oidc_authenticator.dart` launchUrl 先例)+ 债务合同文件打开在用;**零新依赖**。
- 版本源:`PackageInfo.fromPlatform().version`(F24 先例:组合根 versionProvider 注入,pubspec 单源派生;当前 1.0.8+9)。
- 宽屏(≥1100px)`_Sidebar` 左侧栏:品牌区 → 导航组 ListView → 底部用户区(头像+用户名+退出 IconButton);窄屏 `_BottomNav` NavigationBar 7 destinations(含退出)。侧栏整行入口锚点=导航列表尾部(fix-2;原计划用户区上方,720p 实测挤掉导航项后改)。
- 设置页 `settings_page.dart` 图标行卡范式(备份/扫描间隔/标签/周期规则/快照行)。
- 主题当前值:ThemeSettings 持久化(R8 F1);账户模式:AuthBloc 状态(guest|Authenticated)。
- 发布:GitHub Actions tag 推送自动构建(R11),Secrets 机制已用(DSA 签名钥)——dart-define 注入有现成管道。

## Requirements

- **FR-1 反馈跳转核心**:单一 FeedbackLauncher——构造 mailto URI(收件人=`FEEDBACK_EMAIL`,主题模板「御财反馈」,正文=FR-5 诊断头)+ `launchUrl`(externalApplication);三入口(侧栏行/底栏项/设置页行)共用同一 launcher;成功唤起即完成。
- **FR-2 宽屏侧栏入口**:宽屏侧栏导航列表尾部『意见反馈』整行(随列表滚动;1080p+ 常见桌面全列表可见即常驻;`_NavItemTile` 同构样式,与登录态无关),点击=FR-1。
- **FR-3 其余两入口**:窄屏 `_BottomNav` NavigationBar 增「反馈」destination(不参与 branch 切换,点击=FR-1);设置页新增「意见反馈」行(图标行卡同构,点击=FR-1)。
- **FR-4 降级路径**:①`FEEDBACK_EMAIL` 缺省(本地 dev 构建)→ SnackBar「反馈邮箱未配置(需 --dart-define=FEEDBACK_EMAIL)」;②launchUrl 返回失败(无邮件客户端/关联被夺)→ SnackBar 提示 + 将「邮箱+主题+诊断头」整体复制到剪贴板,用户可去网页邮箱粘贴发送。
- **FR-5 诊断头白名单**:正文诊断头**恰好 4 字段**——App 版本(PackageInfo)/ 平台(Windows 等)/ 账户模式(guest|绑定)/ 主题(亮|暗);字段集为白名单常量,**零财务数据**(账户名/余额/交易等一律不得出现);测试断言生成正文只含白名单字段。
- **FR-6 测试与门**:launcher 单测(URI 构造/中文编码/白名单边界/缺省/失败复制)+ 入口 widget 测(三入口渲染与点击回调/缺省态提示);`flutter test` 全绿 + analyze 基线 + `make client-e2e`(纯客户端票,免 go 门)。

## NFR

- **隐私红线(NFR-1)**:mailto 正文与降级剪贴板内容仅含诊断头白名单,无任何财务数据——测试覆盖,review 门核对。
- **常量单点(NFR-2)**:`FEEDBACK_EMAIL` 经 `String.fromEnvironment` 单点定义,源码/仓库零邮箱明文;双入口文案与图标单点收敛;R8 语义令牌零裸色。
- **发布链兼容(NFR-3)**:Actions release 流水线从 Secret 读 `FEEDBACK_EMAIL` 传 `--dart-define`;本地构建零变化照常可跑(dev 走 FR-4①)。

## Scope boundary

| 排除 | 理由(grill 辩护 2026-09-20) |
|---|---|
| 附件/截图反馈 | mailto 纯文本天花板;自动截图可能截入账户余额撞 NFR-1;升级留给 server 反馈线,与本通道不冲突 |
| 反馈历史/发送回执 | mailto 唤起后客户端失联,本地记录必然失真(「唤起」≠「发送」);邮箱即记录 |
| app 内反馈对话框/表单 | 用户裁决:诉求=「有明显入口」而非「在 app 内写」——直跳邮件客户端,免 URL 长度限长守卫 |
| server gRPC 收集 | brainstorm 否决:proto regen 工具链风险 + guest 不可用 + 需另做查看后台,工程量 5-10 倍 |
| GitHub Issues 跳转 | brainstorm 否决:用户群未必有 GitHub 账号,离开 app 体验割裂 |

## Grill record

| 决策 | 挑战 | 定案 |
|---|---|---|
| 反馈通道 | GitHub 跳转/server 收集 对比 | mailto 预填(brainstorm 用户拍板) |
| 入口位置 | 设置页行不够明显 | 设置页行+侧栏底部双入口(brainstorm 用户拍板) |
| 邮箱注入机制 | 「配置文件」真实收益=邮箱不进仓库;asset 换邮箱同样要重打包 | dart-define + Actions Secret(用户) |
| dev 缺省行为 | 隐藏入口 → UI 不可走查/点击无反应算 bug | 入口常驻 + SnackBar 提示未配置(用户) |
| 无邮件客户端 | 只报错=拒掉最强反馈意愿 | SnackBar + 复制邮箱与诊断头(用户) |
| 排除附件/截图 | 一图顶三段文 vs mailto 天花板+截图撞隐私红线 | v1 排除,留给 server 线(用户) |
| 排除反馈历史 | mailto 失联 → 失真记录 | v1 排除,邮箱即记录(用户) |
| 写在何处 | 原话「app 内写」与直跳 mailto 矛盾 | 直跳邮件客户端——诉求=明显入口(用户) |
| 诊断头字段 | 最小 2 项 vs 全量 6 项 | 版本/平台/账户模式/主题 4 项(用户) |
| 侧栏形态 | 整行 vs 仅图标按钮 | 用户区上方整行+窄屏底栏项(用户) |
| 侧栏锚点 | 720p 实测整行挤掉债务/债权导航项 | 反馈行入列表尾(用户,fix-2) |

## Feasibility

- technical ✓ —— url_launcher 已依赖且有 launchUrl 先例;PackageInfo F24 先例;零新依赖、零 server/proto 改动;mailto 中文编码走标准 `Uri` 组件。
- economic ✓ —— 小票:一 launcher + 三入口接线 + 测试,参照 F34/F35 同规模票。
- operational ✓ —— 发布链仅加一个 dart-define(Secret 一次配置);无数据迁移,回滚=还原提交。
