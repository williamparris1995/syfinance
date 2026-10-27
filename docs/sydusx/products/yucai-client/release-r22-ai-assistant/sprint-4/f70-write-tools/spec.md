---
feature: f70-write-tools
status: confirmed
---

# F70 确认门写工具 — spec

> R22 sprint-4 首票(2026-10-27 立项,换序 B 用户拍板)。写操作=2026-10-23 F64 质询用户诉求升格(「添加编辑删除」);**确认卡 UI 照 F65 先例走 OD 原型+用户确认门**。F71 审计表为姊妹票(依赖本票)。

## ADDED Requirements

### Requirement: FR-1 记一笔(支出/收入)
- [ ] 助手 SHALL 提供 `transaction_add` 写工具:{direction(支出/收入),amount,description?,account?(名称匹配账户),category?(名称匹配分类,缺省按描述推导),date?(缺省今天)};解析结果 SHALL 经确认门(参数预览卡+确认/取消)后才执行;执行走 `TransactionRepository.create` **与表单同一条写管道**(余额联动/离线缓冲/同步上行同源获得);确认 SHALL 携幂等键(同一确认重复触发不重复落库)。转账类型 backlog。

#### Scenario: 口述记账全流程
- GIVEN 助手就绪
- WHEN 用户说「记一笔午饭 35 块,招行卡」
- THEN 助手解析出参数并展示预览卡(方向/金额/账户/分类/日期),**未确认前零落库**;点确认→经表单同管道创建交易;审计(F71)记录 actor=agent

#### Scenario: 幂等
- GIVEN 一次确认已执行落库
- WHEN 同一确认的幂等键再次触发(重试/竞态)
- THEN 不产生第二笔交易

### Requirement: FR-2 改一笔
- [ ] 助手 SHALL 提供 `transaction_update`:定位(最近一笔/描述+时间范围匹配,必要时先查给候选)+增量字段(金额/描述/分类/日期/账户);确认卡 SHALL 展示**修改前后对比**;执行走 `TransactionRepository.update` 同管道。

#### Scenario: 改最近一笔
- WHEN 用户说「刚才那笔改成 40 块」
- THEN 助手定位最近一笔交易,预览卡展示 前(¥35)→后(¥40) 对比;确认后更新

### Requirement: FR-3 删一笔
- [ ] 助手 SHALL 提供 `transaction_delete`:定位同 FR-2;确认卡为 **destructive 强提示**(删除不可撤销表述);执行走表单同款删除管道(关联清理同源)。

#### Scenario: 删除确认
- WHEN 用户说「把那笔地铁删了」
- THEN 助手定位并展示待删交易摘要+destructive 确认;确认后删除;取消则保留

### Requirement: FR-4 查无实体新建引导
- [ ] 账户/分类不存在时,助手 SHALL 澄清并**引导跳转对应表单**(deep link:「要新建吗?」→ 打开记账/账户表单并预填可推导字段);v1 助手不直接创建账户/分类。

#### Scenario: 未知账户引导
- GIVEN 用户口述的账户不存在
- THEN 助手澄清「没有找到这个账户,要新建吗?」;同意→跳转表单(预填已知字段);助手不直接建户

### Requirement: FR-5 确认门机制
- [ ] 确认门 SHALL 为确定性代码门(不可被提示词绕过):任何写工具的执行 MUST 经过用户 UI 确认回调;**全部写操作零例外确认**(用户拍板 2026-10-27);待确认状态 SHALL 随「新对话」作废;确认卡取消即弃;同一时刻仅一张待确认卡(新写请求替换旧的并提示)。

#### Scenario: 提示词不可绕过
- GIVEN 任何用户输入或工具参数构造
- WHEN 未经确认回调
- THEN 写工具零执行(代码层守卫,测试钉死)

#### Scenario: 新对话作废
- GIVEN 存在待确认卡
- WHEN 用户点「新对话」
- THEN 待确认作废,确认后也不再执行

### Requirement: NFR-1 写路径同源
- [ ] 全部写工具 SHALL 走与 UI 表单完全相同的 repository 写管道(禁绕过直写 drift);口径/余额/同步行为与表单一致(断言钉死)。

### Requirement: NFR-2 参数面约束
- [ ] 三工具参数面 SHALL 保持小模型友好(各 ≤8 项;分类/账户用名称匹配+候选消歧,不暴露内部 id)。

### Requirement: NFR-3 审计衔接
- [ ] 每次写执行 SHALL 记审计事件(actor=agent/tool/参数摘要/结果/关联实体 id),落 F71 表(F71 未合入前先记结构化日志,接口按 F71 契约预留)。

### Requirement: NFR-4 server 零改动
- [ ] git diff yucai/server MUST 为空。

## Feasibility(裁决)

- **technical 可行**:写管道既有(TransactionRepository create/update/delete 全链测试齐);确认门=浮层内交互卡(扩展 F65 bloc 的 PanelMessage);幂等键=uuid 既有依赖。
- **economic 可行**:零新依赖零迁移(F71 才有迁移)。
- **operational 可行**:全部确认零例外=可预期心智;审计先日志后表平滑过渡。

## Out of scope

- 转账记账 — owner: backlog — excluded because: 质询挑战 1 用户拍 A(支出+收入 v1;转账多源账户参数面+语义分支,需求出现再补)。
- 助手直接创建账户/分类 — owner: backlog — excluded because: 参数面过大 4B 风险;v1 走表单引导(FR-4)。
- 免确认分级 — owner: none(已否) — excluded because: 质询挑战 2 用户拍「全部确认零例外」。
- 批量操作(「这月外卖全改餐饮」) — owner: backlog — excluded because: 多实体确认 UX 复杂,v1 单笔。
- 非交易写(删账户/改预算等) — owner: backlog — excluded because: 记账主场景先行;预算/目标写后续票。
- 审计表与查看 UI — owner: F71 — excluded because: 姊妹票独立验收。

## Grill record

- v1 记账覆盖面 — challenged: 支出+收入 vs 含转账 — defended: 用户拍 A——支出+收入覆盖 95% 口述场景,参数面 6 项内;转账 backlog(多源账户+语义分支)。
- 确认门粒度 — challenged: 全部确认 vs 低风险免确认分级 — defended: 用户拍「全部确认零例外」——可预期心智优先,4B 判分级不可靠;代价=每次多一次点击,明知接受。
- 整 spec 一致性 — challenged: 与 F65/F64 衔接 — defended: 确认卡=PanelMessage 新型态扩 F65 bloc;写走 repository 同管道(NFR-1 与表单口径互证);审计接口按 F71 预留先日志;查无引导与 F64 FR-5 澄清线闭环。
