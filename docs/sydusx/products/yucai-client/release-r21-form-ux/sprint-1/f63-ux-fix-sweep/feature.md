# F63 UX 整改扫票

> /sydusx-portfolio 2026-10-15 分解(审计后改scope,原「范式推广」并回 F62)。R21 sprint-1 次票(依赖 F62)。
> keywords: UX 整改,anti-pattern,错误重试,行内校验,返回条,分段控件,死按钮,审计

## Description

ux-audit-r21.md 的 ANTI 清单全量整改(视觉伴侣 ux-fixes 拍板后执行):
1. ErrorRetryView 共享组件落 9 页 + 3 页错误/空态分治
2. 5 表单 toast 校验改行内 validator + 提交钮接 canSubmit
3. transaction_form 返回条退役 + FormLeaveGuard 接线(急件)
4. backup_settings 返回条退役
5. 3 处 2-4 值下拉改 SegmentedButton(归属/两频率)
6. 可逆确认改直做+toast(重新激活)
7. 死按钮清理(导出/导入模板/登记一笔 redirect/holdings 空态指错)
8. SnackBar 统一 AppToast(6 处)

## Stories

- [ ] S1 ErrorRetryView + 9 页落位 + 错误/空态分治
- [ ] S2 表单行内校验族(5 表单+按钮门)
- [ ] S3 导航残留(2 返回条)+ transaction_form 守卫
- [ ] S4 选择器/确认/死按钮/toast 渠道清理
- [ ] S5 回归门
