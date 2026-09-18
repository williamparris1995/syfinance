# Spec — F33 债务 subtype 全链路可编辑 + 9 类扩展(R14 sprint-1)

> 2026-09-18。grill 三轮收敛(见 Grill record);分类 9 类用户拍板见 [release.md](../../release.md) Decisions。

## Requirements

### Requirement: FR-1 subtype 可编辑
- [ ] `SHALL` 用户在编辑债务时可修改 subtype,保存后详情页、负债页分类 chips 归属、账户页副行显示随之更新,重启后持久。
- [ ] `SHALL` subtype 修改进入既有更新链路(params→repo→remote DS→local DS→sync envelope),离线编辑在恢复在线后经 `UpdateDebtRequest` 上行。

#### Scenario: 存量错位分类就地修正
- GIVEN 存量债务 subtype=`mortgage` 关联贷款账户,编辑模式 chips 只读
- WHEN 用户编辑该债务选 `credit_loan` 并保存
- THEN 负债页「信用贷款」chip 下可见该债,「房贷」chip 下不再出现;重启 app 后保持

#### Scenario: 离线编辑 subtype 后同步
- GIVEN 绑定设备处于离线态
- WHEN 编辑债务 subtype 并保存
- THEN 本地立即生效且债务标记 pending;恢复在线后 server 侧 subtype 更新为同值

### Requirement: FR-2 分类扩展 9 类
- [ ] `SHALL` 债务分类为 9 类:`mortgage` 房贷 / `auto_loan` 车贷 / `credit_loan` 信用贷款 / `cash_installment` 现金分期 / `consumption_loan` 消费贷 / `business_loan` 经营贷 / `credit_card` 信用卡 / `family` 亲友借款 / `other` 其他,`DebtSubtypes` 常量表为单一事实源。
- [ ] `SHALL` 表单选择、负债页 chips、列表/详情图标与色对 9 类行为一致(新增 4 类同既有类的展示待遇)。

#### Scenario: 新分类全链可见
- GIVEN 用户创建债务选 `cash_installment`
- THEN 负债页「现金分期」chip 可筛出该债,列表/详情图标色正确渲染

### Requirement: FR-3 创建时自动归位
- [ ] `SHALL` 创建债务选择关联账户后,subtype 自动默认到兼容值(见 FR-4 白名单);**仅当用户未手动触碰过 subtype** 时联动,用户改过则改账户不再覆盖。

#### Scenario: 未触碰时联动
- GIVEN 新建债务表单,用户未碰 subtype(默认 mortgage)
- WHEN 选择关联账户「个人待还款」
- THEN subtype 自动切为 `family`

#### Scenario: 已触碰不覆盖
- GIVEN 用户已手动选 subtype=`credit_loan`
- WHEN 再改选关联账户
- THEN subtype 保持 `credit_loan` 不变

### Requirement: FR-4 冲突提示(非阻断)
- [ ] `SHALL` 创建或编辑时,若「关联账户类别 ↔ subtype」组合落在兼容白名单外,表单内显示 inline warn 警示条,**不阻断保存**。
- [ ] `MUST` 白名单为常量映射表,与 `DebtSubtypes` 同处单一事实源:

| 关联账户类别 | 兼容 subtype | 其余 |
|---|---|---|
| loan 贷款账户 | mortgage/auto_loan/credit_loan/cash_installment/consumption_loan/business_loan | 提示 |
| creditCard 信用卡账户 | credit_card | 提示 |
| otherLiability 个人待还款 | family | 提示 |
| 任意 | other 永不提示 | — |

#### Scenario: 白名单外组合提示
- GIVEN 编辑债务,关联账户为贷款账户
- WHEN 用户选 subtype=`family`
- THEN 表单显示 warn 警示条,保存仍可成功且数据生效

## NFRs

### Requirement: NFR-1 单一事实源
- [ ] `MUST` 9 类 key/label 与兼容白名单收敛为常量表,全 app 无第二处硬编码分类集(延续 FR-2 约束,评审 grep 门可验)。

### Requirement: NFR-2 proto 向后兼容
- [ ] `MUST` `UpdateDebtRequest` 以追加字段方式携带 subtype(proto string 追加安全);未升级的旧端忽略新字段,双向同步不破。

#### Scenario: 旧 server 收到新字段
- GIVEN 部署旧版 server(无 subtype 解析)
- WHEN 新 client 上行 UpdateDebtRequest 含 subtype
- THEN 其余字段更新成功,无报错(字段被忽略)

## Scope boundary(排除项,逐条带 owner+理由)

| 排除项 | owner | 理由(defended) |
|---|---|---|
| 借入↔借出方向编辑 | F33 不做 | 类型级变更涉及分录/计划语义重构,风险另评;行业无此先例(修正=删重建) |
| 信用卡专属字段区联动校验 | F33 不做 | 切到 credit_card 的卡信息填写维持现状逻辑,表单细节归 design 阶段 |
| 批量重分类 | F33 不做 | 个人量级(当前 25 笔)不需要;行业批量属多商户场景 |
| 存量数据迁移 | F33 不做 | 用户自助 in-app 修改(本 feature 交付的能力);无脚本迁移必要 |
| 负债账户余额不变式/记账治本 | → F36 | 另票,方案 A 已拍板 |
| 「分类↔账户」硬约束保存 | 拒绝(grill) | 行业对照后选 B(归位+提示);硬约束误杀合法边缘组合(房抵消费贷等)且存量需先清洗 |

## Feasibility

- **technical: 可行**——proto string 追加字段向后兼容;server repo 层 `SetSubtype` 已存在(缺入参通路);风险点 = proto regen 高风险路径(sync.pbjson F13 手工补丁须重套),S2 首个动作即验证。
- **economic: 可行**——一票内完成;客户端为主,服务端接线小。
- **operational: 可行**——存量错位(1 笔)用户自助修正;自动归位+提示从源头降低再错率。

## Grill record

| 决策 | 挑战 | 辩护/裁定 |
|---|---|---|
| 纯自由编辑 vs 一致性提示 | 纯自由编辑=两页维度错位机制上永不杜绝,代价认否 | 用户:要提示(建错明细怎么纠正是真实诉求) |
| 提示规则(白名单)是否行业标准 | 行业主流是合并维度或创建时硬约束,提示是少数派补丁 | 用户同意升级 B:创建自动归位+编辑提示;硬约束 C 误杀合法组合(房抵消费贷)被拒 |
| 自动归位覆盖手动选择? | 已手动选过 subtype 再改账户,联动覆盖=抢用户输入 | 用户同意:仅在用户未触碰 subtype 时联动 |
| 行业分层纠正模型(标签/计划/整笔/冲正) | subtype 属标签层,就地改=最佳实践,无需冲正 | 用户接受,支撑纯编辑路线 |
