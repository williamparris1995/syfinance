# Task Brief — F41 应用内反馈入口(T1+T2, TDD)

## 既有设施(全部已存在,复用第一)

- `url_launcher: ^6.3.2` 已依赖;函数注入缝先例:`lib/auth/data/oidc_authenticator.dart` 的 `typedef UrlLauncherFn` + `defaultUrlLauncher`。
- 版本源先例:`PackageInfo.fromPlatform().version`(F24;tray_controller.dart versionProvider)。**本票不走组合根注入,launcher 收纯数据。**
- 宽屏侧栏:`lib/app/widgets/app_shell.dart` `_Sidebar`(品牌区→导航 ListView→底部用户区 Container);导航项视觉 `_NavItemTile`;窄屏 `_BottomNav`(NavigationBar 7 destinations,`_branchSlots` 映射 branch,末位退出单独处理)。
- 设置页行:`lib/settings/presentation/settings_page.dart` `_NavRow`(icon/label/description/onTap/danger)。
- 测试挂点:`test/app/widgets/app_shell_test.dart`(真 router pump + mock blocs 手法);`test/settings/presentation/settings_page_test.dart`。
- 发布:`.github/workflows/release.yml` 第 90 行 `flutter build windows --release`。

## 任务

### T1 — `lib/core/feedback/feedback_launcher.dart`(新文件)

1. `const feedbackEmail = String.fromEnvironment('FEEDBACK_EMAIL');`(全仓唯一定义点,源码零邮箱明文)。
2. `class FeedbackDiagnostics { final String appVersion, platform, accountMode, themeMode; }` + `List<String> bodyLines()` 白名单常量字段序,恰好 4 行:
   `版本:<appVersion>` / `平台:<platform>` / `账户:<guest|绑定>` / `主题:<亮|暗>`。
3. `Uri buildFeedbackMailto(FeedbackDiagnostics d)` —— `mailto:<feedbackEmail>`,query 参数 `subject=御财反馈`、`body=<4 行 \n 连接>`;中文必须 percent-encode(用 `Uri(scheme:'mailto', path:…, queryParameters:…)` 标准构造,测试断言 round-trip 解码正确且无裸 CJK)。
4. `enum FeedbackLaunchResult { launched, emailMissing, launchFailedCopied }`。
5. `Future<FeedbackLaunchResult> launchFeedback(FeedbackDiagnostics d, {LaunchUrlFn? launch, ClipboardWriter? clip})`:
   - `feedbackEmail` 空串 → 直接返回 `emailMissing`(不构造 URI)。
   - launch 缝(`Future<bool> Function(Uri, {LaunchMode mode})`,默认 `launchUrl(..., LaunchMode.externalApplication)`)返回 true → `launched`。
   - 返回 false → clip 缝(默认 `Clipboard.setData`)写入 `收件人:<email>\n主题:御财反馈\n\n<4 行诊断头>` → `launchFailedCopied`。
   - 文件头注释:English(说明 dart-define 注入与三态语义)。

### T2 — 三入口接线 + 发布链

1. `app_shell.dart`:
   - 宽屏 `_Sidebar`:底部用户区 Container **上方**加整行 `_SidebarFeedbackRow`(新私有 widget;视觉复用 `_NavItemTile` 样式语言:leading icon 20px + label 13px,Lucide `messageSquareHeart`;无 selected 态)。常驻渲染,与登录态无关。
   - 窄屏 `_BottomNav`:destinations 增第 8 项(icon `messageSquareHeart`/`messageSquare` 与宽屏一致,label「反馈」);`onDestinationSelected` 反馈位 → 新增 `onFeedback` 回调参数(AppShell 处接同一 launch 逻辑);不进 `_branchSlots`。
   - 共用 launch 逻辑(可提 app_shell 内私有 helper 或顶层函数):组装 `FeedbackDiagnostics`(`appVersion` = `(await PackageInfo.fromPlatform()).version`;`platform` = `Platform.operatingSystem`;`accountMode` = AuthBloc state is Authenticated ? '绑定' : 'guest';`themeMode` = 当前亮/暗——侦察 `core/theme/theme_settings.dart` 取当前模式)→ `launchFeedback(d)`;结果映射 SnackBar(中文文案):`emailMissing` → 「反馈邮箱未配置(需 --dart-define=FEEDBACK_EMAIL)」;`launchFailedCopied` → 「未检测到邮件客户端,反馈内容已复制,可粘贴到网页邮箱发送」;`launched` → 无提示。
2. `settings_page.dart`:既有 `_NavRow` 区新增「意见反馈」行(icon 同上,label「意见反馈」,description 一句话如「通过邮件向我们反馈问题或建议」),onTap 同一 launch 逻辑(可与 app_shell 共用 helper——若放 core/feedback 合理则提公共入口函数,自行判断归属并说明)。
3. `.github/workflows/release.yml` 第 90 行追加 ` --dart-define=FEEDBACK_EMAIL=${{ secrets.FEEDBACK_EMAIL }}`。
4. 入口测试时机注意:seam 允许注入假 launch/clip——为使 widget 测可控,launch helper 应可注入(如 `FeedbackEntry.launch(context, {seams})` 形态,自行设计,保持两入口共用)。

## TDD(先 RED 后 GREEN,每个测试文件 RED→GREEN 后立即跑该文件)

`test/core/feedback/feedback_launcher_test.dart`:
1. buildFeedbackMailto:subject/body round-trip 解码正确(4 行各含字段名与值);URI 字符串无裸 CJK(断言含 % 编码);收件人=feedbackEmail。
2. **白名单**:body 恰好 4 行且仅含 4 字段名——构造含「¥」等财务符号的假环境不存在(纯数据),断言 bodyLines 输出不含任何非白名单字段。
3. launchFeedback:email 缺省 → emailMissing 且 launch 缝未被调。
4. launch 缝 false → clip 缝被调、文本含收件人/主题/4 行;true → launched 且 clip 未被调。

`test/app/widgets/app_shell_test.dart` 扩展(照现有 router pump 手法):
5. 宽屏(默认测试尺寸≥1100):侧栏出现「意见反馈」行;点击(注入假 launch 缝)→ 假缝被调。
6. 窄屏(`tester.view.physicalSize` 压宽 <1100):底栏出现「反馈」destination;点击 → 假缝被调。若窄屏 router pump 手法代价异常高,允许以「_BottomNav 直构 pump」替代(自行判断),但不得静默省略——做不了写进报告。

`test/settings/presentation/settings_page_test.dart` 扩展:
7. 设置页渲染「意见反馈」行;点击 → 假 launch 缝被调。

GREEN 后回归:`flutter test test/core/feedback/ test/app/ test/settings/` → 全量 `flutter test` + `flutter analyze`(≤439)。

## 约束

**禁止 git stash/checkout/restore**;只动:上述新文件 + app_shell.dart + settings_page.dart + release.yml + 三个测试文件;勿提交 git;English 注释与日志(用户可见文案中文);零硬编码色(R8 语义令牌)。
工作目录:`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r15-f41-in-app-feedback/yucai/client`(worktree 内,分支 feature/r15-f41-in-app-feedback)。
完成后报告:改动文件、RED→GREEN 证据(每测试文件)、回归结果(analyze 数字)、_BottomNav 窄屏测试手法选择、BLOCKED 即停。
