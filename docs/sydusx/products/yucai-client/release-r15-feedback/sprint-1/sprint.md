# Sprint 1 — R15 应用内反馈(F41)

> /sydusx 流程(2026-09-20)。单票 sprint:R14 收官后用户提出补反馈入口,brainstorm 两决策(邮件预填通道/双入口)直接落票。

## Sprint Goal

应用内反馈入口落地:mailto 邮件预填通道(主题+诊断头),设置页行 + 侧栏底部双入口,guest 可用。

## Feature roster

- [x] **feature F41** in-app-feedback — 应用内反馈入口(邮件预填 + 双入口) ✅ done(2026-09-20,ff 合并 `a040c663`:FeedbackLauncher core/feedback 纯核[mailto 直跳+诊断头 4 字段白名单+三态+函数注入缝;FEEDBACK_EMAIL dart-define 单点]+三入口[宽屏侧栏导航列表尾部整行——fix-2 用户裁决:720p 实测整行挤掉债务/债权导航项/窄屏底栏第 8 项/设置页行]+release.yml dart-define 注入;两轴评审 1 Important+3 Minor 修毕[core 去 feature 依赖走 SessionModeTracker 顺修 OfflineAuthenticated 误标/异常守卫/缺省态逐字断言/几何同构];1907 测全绿+analyze 437≤439+client-e2e 5 套件 21 测绿[债务导航回位验收];需求覆盖 9/9)—— worktree 已清,分支已删

## status: done(F41 done;发版待 FEEDBACK_EMAIL Secret 配置+tag 推送,用户侧动作)
