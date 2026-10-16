---
feature: f63-ux-fix-sweep
status: confirmed
---

# F63 UX 整改扫票 — spec

> 依据:ux-audit-r21.md ANTI 详单(file:line 级)+ 原型 v18(yucai-ux-fixes 用户拍板页)+ R21 交互规范六维。holding 模块 tab 导航经用户拍板 A 豁免(规范已补条款),不在本票范围。

## ADDED Requirements

### Requirement: FR-1 ErrorRetryView 共享组件 + 9 页落位 + 错误/空态分治
- [ ] core 共享 `ErrorRetryView(message, onRetry)`(蓝本=transactions_page `_ErrorView`/budget_list `_errorState`)SHALL 替换 9 处纯文案错误态:account/budget/goal/debt/receivable/holding detail、performance、holdings、home 面板;accounts/debts/receivables 三列表页错误且无 last 数据时 SHALL 走错误态(重试)而非空态。

### Requirement: FR-2 五表单行内校验 + 提交钮门
- [ ] debt/receivable/goal/trade_sheet 四表单的字段校验 SHALL 由提交时 toast 改为行内 validator(autovalidateMode.onUserInteraction)+ 提交钮随 canSubmit 禁用(照 budget_form 范式);security_page CreateSecuritySheet 同款;toast 仅保留服务端错误。trade_sheet 余额不足 SHALL 灰显提交钮(实时预览红警已在)。

### Requirement: FR-3 transaction_form 返回条退役 + 脏守卫(急件)
- [ ] transaction_form_page `_PageHead` 的「‹ 返回」链接 SHALL 退役;SHALL 接入 FormLeaveGuard + _dirty 追踪(照 debt_form 接法),六表单守卫族闭环。

### Requirement: FR-4 backup_settings 返回条退役
- [ ] backup_settings_page 自制返回钮 SHALL 退役(回退走顶栏面包屑),头注同步订正。

### Requirement: FR-5 三处 2-4 值下拉改分段
- [ ] account_form「归属」(2 值)、settings「汇率同步频率」(4 值)、backup_settings「备份频率」(4 值)SHALL 改 SegmentedButton(照 settings 同页托盘间隔写法)。

### Requirement: FR-6 可逆确认改直做
- [ ] 账户「重新激活」SHALL 直接执行 + AppToast「已重新激活」(两入口:列表+详情);「关闭账户」确认 SHALL 保留但文案列后果(影响统计口径,半可逆);不可逆「删除」确认原样。

### Requirement: FR-7 死按钮/redirect 清理
- [ ] transactions 导出、categories 导入模板占位入口 SHALL 隐藏(未上线不露);debt_detail_widgets「登记一笔还款/收款」SHALL 改为滚动定位到还款计划区(不再训人式 redirect toast);holdings 空态指引 SHALL 改指实际存在的入口(顶栏「记一笔」)。

### Requirement: FR-8 toast 渠道统一
- [ ] settings/login/tag/template/category_management 五处底部 SnackBar SHALL 统一 AppToast;写操作失败(accounts 删除/关闭失败、detail 写失败)SHALL 页面留驻错误反馈(非纯 toast)。

## NFR

### Requirement: NFR-1 回归门
- [ ] flutter test 全绿 + analyze ≤459 基线 + `make client-e2e`;既有六表单守卫/行内校验(transaction_form)范式零回归。

## Out of scope

- holding 模块 4 页 tab 导航 — owner: none(用户拍板 A 豁免,规范已补条款) — excluded because: 刻意设计决策,产品拍板保留。
- debt_detail dispatch 即弹成功 toast(过早成功) — owner: none(minor) — excluded because: 审计 minor 项,随债务域后续票。

## Grill record

- 本票决策全部继承 R21 审计(file:line 证据逐项挑战)+ 用户两拍板(holding tab 豁免 A/视觉伴侣 yucai-ux-fixes 定稿);关闭账户确认保留半可逆口径为审计建议默认,spec 确认时用户可改直做。
