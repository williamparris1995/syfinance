# Code Plan — F41 应用内反馈入口

> 2026-09-20 execute 产出。spec/design 均用户确认;规模=同 F39 单 brief 级(2 task 串行)。

## Tasks

- [x] T1: FeedbackLauncher 核心 —— 新建 `lib/core/feedback/feedback_launcher.dart`(feedbackEmail 常量/String.fromEnvironment 单点;FeedbackDiagnostics 纯数据 4 字段;buildFeedbackMailto;launchFeedback 三态 launched/emailMissing/launchFailedCopied;launchUrl+Clipboard 函数注入缝)+ `test/core/feedback/feedback_launcher_test.dart`(URI 构造/白名单恰 4 行/缺省/失败复制)。RED→GREEN。
- [x] T2: 三入口接线 + 发布链 —— `app_shell.dart`(宽屏 _Sidebar 用户区上方 _SidebarFeedbackRow 整行;窄屏 _BottomNav 第 8 destination+onFeedback 回调)+ `settings_page.dart`(_NavRow「意见反馈」行)+ `.github/workflows/release.yml:90` 追加 `--dart-define=FEEDBACK_EMAIL=${{ secrets.FEEDBACK_EMAIL }}` + 测试(test/app/widgets/app_shell_test.dart 扩展宽/窄屏入口;test/settings/presentation/settings_page_test.dart 扩展行)。RED→GREEN。

依赖:T1 → T2(接口依赖,串行)。派发:单 brief(task-brief-1)两 task 串行 TDD,后续两轴评审。

## 验收门

flutter test 全绿 + flutter analyze ≤439 基线 + `make client-e2e`(纯客户端票免 go 门)。
