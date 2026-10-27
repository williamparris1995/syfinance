# Prototype v20 — F70 确认门写工具(确认卡六形态)

> tier: high-fi(design)· path: OD 管线(项目 `yucai-f70-write-9a76` run `a1990b4f`,2026-10-27;**用户确认门已过:六形态整体拍板**)。
> 底版:prototype v19 assistant-chat-states.html fork。

## 内容(F70 的 UI 事实源)

- **ui/write-approval-cards.html**:V1 新增预览卡(参数逐行+分类推导注记+确认/取消+确认后✓态)/V2 前后对比卡(删除线旧值+高亮新值)/V3 destructive 强确认(红警示+按钮主位反转)/V4 查无引导卡(新建跳表单/换账户)/V5 替换(superseded 角标)与作废态/V6 执行失败重试(幂等说明)。

自检:token 零硬编码(控制器复核 0)/亮暗切换/桌面布局强制。

## Constraints(people / data / finance / process)

- people:单用户桌面键鼠中文;按钮键盘可聚焦;destructive 视觉级差明确。
- data:示例合成;泛称账户。
- finance:pending 态零「已完成」暗示;金额千分位两位。
- process:全部写操作零例外确认(用户拍板 2026-10-27)。

## Components

write-approval-card(三形态:preview/diff/destructive)+guidance-card(查无引导)+approval-state-badges(confirmed/cancelled/superseded/void/failed)。

## CURRENT

v20(F70 确认卡,2026-10-27 用户拍板;v19 为 F65 AI 助手存档)。
