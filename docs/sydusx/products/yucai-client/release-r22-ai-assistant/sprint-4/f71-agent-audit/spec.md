---
feature: f71-agent-audit
status: confirmed
---

# F71 durable 审计表 — spec

> R22 sprint-4 末票(2026-10-28)。F70 审计接口预留(先日志)的本体落地;UI=轻量只读对话框(OD 原型 v21 过用户目)。

## ADDED Requirements

### Requirement: FR-1 agent_audit 表(drift v15)
- [ ] 系统 SHALL 迁移 drift schema v14→v15 新增 `agent_audit` 表:时间戳/工具名/动作摘要/结果(ok|failed|原因)/关联实体 id/幂等键;条目天然 actor=agent(人为写入不进此表,与表单写入可区分)。

#### Scenario: 迁移幂等
- GIVEN 任一 v14 存量库
- WHEN 应用启动 v15 迁移
- THEN 表建立零数据丢失,重复启动无副作用

### Requirement: FR-2 审计双投(日志+表)
- [ ] F70 执行器的写事件 SHALL 经 `AgentAuditSink` port 双投:AssistantAuditLog English 日志照旧 + agent_audit 入库;**表写入失败 MUST fail-open**(记账不被阻断,日志仍在,静默计数);读工具调用不入库(留日志)。

#### Scenario: 记账留痕
- GIVEN 一次确认记账成功
- WHEN 查看 agent_audit
- THEN 恰一行(工具/摘要含金额与账户/ok/实体 id/幂等键/时间戳);对应交易可由实体 id 关联

#### Scenario: 失败也留痕
- GIVEN 一次写执行失败(versionConflict)
- THEN 表中一行 failed+原因;幂等键在(重试成功后再加一行 ok)

#### Scenario: 表写失败不阻断
- GIVEN 入库抛异常(注入 fake)
- THEN 记账照常成功,日志行仍在,无用户可见错误

### Requirement: FR-3 查看入口(卡内对话框)
- [ ] 设置页「AI 助手」卡 SHALL 提供「操作记录」入口行→只读对话框:时间倒序列表(时间/工具/摘要/结果徽标)、分页(页大小固定上限)、空态文案;无编辑无删除。

#### Scenario: 倒序与分页
- GIVEN 表中 N>页大小条
- WHEN 打开对话框
- THEN 首页为最新一页,可翻页,总条数可见

#### Scenario: 空态
- GIVEN 无任何 agent 写操作
- THEN 对话框显示空态文案(非报错)

### Requirement: NFR-1 仅写事件
- [ ] 读工具调用 MUST 不入 agent_audit(日志承载);断言钉死(读操作后表零行)。

### Requirement: NFR-2 server 零改动
- [ ] git diff yucai/server MUST 为空。

## Feasibility(裁决)

- **technical 可行**:drift 迁移家常(v6→v14 先例);sink port 一处接线(F70 executor 的 logWrite 位)。
- **economic 可行**:零新依赖;表量级=低频写。
- **operational 可行**:fail-open 保主链路;查看低频。

## Out of scope

- 读操作入库 — owner: none(已否) — excluded because: 质询挑战 1 用户拍 A——高频低追责价值,表膨胀;日志已承载。
- 审计导出/清理策略/保留期 — owner: backlog — excluded because: 与备份保留策略(R10 30 份)对齐需另议,无现实诉求记录。
- 人为写入标记列 — owner: none — excluded because: 表即 agent 专属,区分天然成立。
- 独立页面路由 — owner: none(已否) — excluded because: 质询挑战 2 用户拍 A 卡内对话框。

## Grill record

- 审计入库范围 — challenged: 仅写 vs 全部工具调用 — defended: 用户拍 A——审计目的=追责资金动作;读操作高频低价值,表膨胀;读留日志。
- 查看入口形态 — challenged: 卡内对话框 vs 独立页面 — defended: 用户拍 A——低频查看轻入口;对话框内倒序/分页/空态。
- 整 spec 一致性 — challenged: 与 F70/F67 衔接 — defended: sink 接 F70 executor 的 logWrite 单点(双投)/幂等键列承接 F70 键语义/失败留痕含重试后 ok 两行(键同结果异)/v15 迁移照 drift 家法。
