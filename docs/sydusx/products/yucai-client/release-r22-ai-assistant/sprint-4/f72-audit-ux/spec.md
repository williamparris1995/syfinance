---
feature: f72-audit-ux
status: confirmed
---

# F72 审计体验增强 — spec

> R22 sprint-4 补票(2026-10-28 用户四问拍板「四项全做」)。F71 审计对话框的体验增强;v22 原型过目后实施。

## ADDED Requirements

### Requirement: FR-1 按日期分组
- [ ] 审计列表 SHALL 按日历日分组渲染段头(今天/昨天/前天/yyyy年M月d日),组内保持时间倒序;翻页跨日正确续组。

#### Scenario: 跨日分组
- GIVEN 表中含今天与昨天多条
- THEN 两段头各就位,组内倒序;「加载更多」拉入更早日期时新段头正确出现

### Requirement: FR-2 摘要搜索
- [ ] 对话框 SHALL 提供关键词搜索框:输入即过滤(DAO 层 LIKE 匹配 summary,非仅已加载页),清空恢复全量;结果计数随过滤更新;空结果显示「无匹配」态。

#### Scenario: 搜索过滤
- GIVEN 表中含「午饭」「地铁」多条
- WHEN 搜「午饭」
- THEN 仅匹配行显示+「n 条匹配」计数;清空回全量

### Requirement: FR-3 行复制
- [ ] 审计行 SHALL 支持右键/长按弹出菜单「复制摘要」(整行摘要串入剪贴板,toast 反馈);照仓内右键菜单先例。

#### Scenario: 复制反馈
- WHEN 右键某行→复制摘要
- THEN 剪贴板含该行摘要串+toast 确认

### Requirement: FR-4 以此再记一笔
- [ ] **仅 tool=transaction_add 的行** SHALL 可点击:点击后关闭对话框→打开助手浮层并弹出**预填确认卡**(解析该行摘要为新 transaction_add 提案,**新幂等键**,经正常确认门);改/删行 SHALL 保持只读(视觉区分:记行可点态+「以此再记一笔」右缘提示,改/删行无)。

#### Scenario: 再记一笔全流程
- GIVEN 一条历史「已记:支出 ¥35.00 午饭」行
- WHEN 点击该行
- THEN 对话框关→助手浮层开→pending 确认卡预填(支出 ¥35.00 午饭/同分类账户推导)且**新键**;确认→新交易落库(原交易不动)+审计新行;取消→无副作用

#### Scenario: 改/删行只读
- WHEN 点击改/删行
- THEN 无交互(不可点态)

### Requirement: NFR-1 确认门不变
- [ ] 再记一笔 MUST 走完整确认门(零例外原则延续);断言:点击历史行本身零落库。

### Requirement: NFR-2 server 零改动
- [ ] git diff yucai/server MUST 为空。

## Feasibility(裁决)

- **technical 可行**:分组=渲染层;搜索=DAO LIKE(列已建);复制=右键菜单先例;再记=摘要串→transaction_add 工具同参解析(串格式自家定义)+bloc 注入提案(F70 WriteProposed 既有路径,新键)。
- **economic/operational 可行**:零新依赖;低频面。

## Out of scope

- 按工具/金额过滤 — owner: backlog — excluded because: 无诉求记录,搜索已覆盖主场景。
- 改/删行重跑 — owner: none(已否) — excluded because: 质询定语义——目标交易已变,重跑必错;只读。
- 审计导出/清理 — owner: backlog — excluded because: F71 已裁,待备份策略对齐。

## Grill record

- 四问四项 — challenged: 用户问「分组/搜索/复制/点击再运行」——逐项给出可行性分析与风险(再运行同键=AlreadyExecuted 空转;正确形态=以此再记一笔新键过确认门;改/删重跑必错保只读) — defended: 用户拍「四项全做(推荐)」——再记一笔采预填确认卡语义(仅记行)。
- 整 spec 一致性 — challenged: 与 F70/F71 衔接 — defended: 再记提案走 F70 确认门全链(NFR-1 零例外延续)/搜索不动分页语义(过滤态独立计数)/分组不碰 DAO 排序。
