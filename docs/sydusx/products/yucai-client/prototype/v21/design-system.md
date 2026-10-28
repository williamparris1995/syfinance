# Prototype v21 — F71 审计对话框(操作记录)

> tier: high-fi(design)· path: OD 管线(项目 yucai-f71-audit-b665;2026-10-28 用户拍板三态整体确认)。
> 底版:design-output-v2/ab settings.html fork。

## 内容

ui/agent-audit-dialog.html:入口行(条数+chevron)/主态只读对话框(倒序/工具 chip/摘要/结果徽标 ok 绿 failed 红+原因/加载更多/「全部操作均经你确认」副行/失败-重试成功对示例)/空态。

## Constraints

people 桌面键鼠中文;data 合成相对时间;finance 千分位两位+失败不粉饰;process 只读零编辑零删除。

## Components

agent-audit-dialog(只读列表+徽标+加载更多)/audit-entry-row(时间/工具 chip/摘要/徽标)/audit-empty-state。

## CURRENT

v21(F71 审计,2026-10-28 拍板;v20 为 F70 确认卡存档)。
