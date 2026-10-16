# Design: F63 UX 整改扫票

prototype: v18(ui/yucai-ux-fixes.html 用户拍板页;组件契约见 v18/components.md)

## Context

审计 ANTI 全量整改(file:line 见 ux-audit-r21.md 详单);holding tab 已豁免。全部为表现层改动,零 schema/proto。

## Decisions (ADRs)

- **ADR-1 ErrorRetryView 归 core/widgets**(蓝本 transactions_page `_ErrorView` 抽共享):`ErrorRetryView({message, onRetry, compact})`,compact 供 home 面板内嵌;图标+文案+重试钮,令牌化。
- **ADR-2 行内校验走 Form validator 链**(照 transaction_form/budget_form 既有范式):必填字段补 `validator` + `autovalidateMode: AutovalidateMode.onUserInteraction`;提交钮 `onPressed: (submitting || !canSubmit) ? null : _submit`;toast 校验串全部退役(服务端错误保留)。
- **ADR-3 transaction_form 守卫照六表单族接法**:`_dirty` 首改即脏(controller+onChanged)+FormLeaveGuard 包 body;返回条删除。
- **ADR-4 分段控件照 settings 同页写法**(SegmentedButton,2/4 段)。

## HLD

| 单元 | 层 |
|---|---|
| ErrorRetryView(新) | core/widgets |
| 9 详情/面板页 + 3 列表页 | 各模块 presentation |
| transaction_form/backup_settings | 表单页 |
| debt/receivable/goal/trade_sheet/security 表单校验 | 表单页 |
| 分段×3/确认×2/死按钮/SnackBar | 各处 |

## Risks

- [表单校验重构波及既有测试(toast 断言)] → 同步更新断言为行内错误文本查找。
- [九页错误态改动波及 e2e 错误路径] → e2e 亲跑。

## Migration

纯表现层;回滚=revert。
