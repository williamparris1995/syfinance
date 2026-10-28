# Prototype v22 — F72 审计体验增强

> tier: high-fi(design)· path: OD 管线(项目 yucai-f72-auditux-14f7;2026-10-28 用户拍板四件整体确认)。
> 底版:prototype v21 agent-audit-dialog.html fork。

## 内容

ui/audit-ux-enhanced.html:日期分组段头(今天/昨天/前天/完整日期)/搜索框双态(全量计数↔n 条匹配+清除)/行右键「复制摘要」+已复制 toast/记行 hover+「以此再记一笔 ›」(改删只读)/预填确认卡片段(来自历史+新纪录需再次确认注)。

## Constraints

people 桌面键鼠;data 合成;finance 千分位两位+确认门如实;process 只读不变(再记=新提案过门)。

## Components

audit-group-header/audit-search-bar(双态)/audit-row-context-menu(复制)/audit-row-tap-hint(仅记行)/repropose-confirm-fragment。

## CURRENT

v22(F72 审计增强,2026-10-28 拍板;v21 为 F71 审计存档)。
