# Spec — F34 支出支付方式放开信用卡(R14 sprint-1)

> 2026-09-18。用户 dev 实测两点驱动:①信用卡详情「记一笔」未带卡进表单;②支出「转出账户」选不了信用卡。L 级 grill:范围/口径由用户两句话 + 既有架构事实锁定,无未决 trade-off。

## Requirements

### Requirement: FR-1 支出支付账户可选信用卡
- [ ] `SHALL` 支出模式「转出账户」下拉 = 资产类 ∪ **信用卡类**(liability+category=creditCard)账户;选择信用卡后提交,分录为 借:支出账户 / 贷:信用卡账户(余额更新器 liability=credit−debit 既有语义,余额向欠款方向累积)。
- [ ] `MUST` 转账/收入的账户列表维持 asset-only 不变(F34 NonGoal:信用卡转账=还款语义另票)。

#### Scenario: 下拉含信用卡且可选
- GIVEN 支出表单,账户源含信用卡账户「招商信用卡」
- WHEN 打开「转出账户」下拉
- THEN 「招商信用卡」在选项中,可选且回显

#### Scenario: 刷卡提交分录正确
- GIVEN 选信用卡为转出账户、分类=餐饮、金额 100
- WHEN 提交
- THEN RecordExpenseParams.assetAccountId == 该卡 id(借贷:支出/信用卡)

### Requirement: FR-2 信用卡详情「记一笔」带卡进表单
- [ ] `SHALL` 从信用卡类账户详情点「记一笔」,表单转出账户预选该卡(existing 行为对 asset 账户已成立,本票使 liability 同样成立)。

#### Scenario: 卡详情记账预选
- GIVEN 信用卡详情页
- WHEN 点「记一笔」
- THEN 表单转出账户显示该卡(非空/非崩溃)

### Requirement: FR-3 类型切换失效守卫
- [ ] `MUST` 转出账户选中信用卡后切换类型 tab(如→转账),若该 id 不在新模式选项集内则清空选中,下拉 value ⊆ items 恒成立(T5 同款守卫;防 Dropdown 断言崩溃)。

#### Scenario: 卡选中切转账
- GIVEN 支出模式选中信用卡
- WHEN 切到转账 tab
- THEN 转出账户清空且不崩溃;转出/转入选项仍无信用卡(asset-only 保持)

## NFRs

### Requirement: NFR-1 语义一致性
- [ ] `MUST` 分录/余额口径复用既有复式引擎(balance_updater liability 方向),零新记账语义;表单 UI 过滤器为唯一改动面(编辑回填推断 :262 既有通用兜底覆盖 dr expense/cr liability)。

## Scope boundary

| 排除项 | 理由 |
|---|---|
| 转账放开信用卡(还款/取现语义) | 转账=资产间移动;信用卡还款走债务模块还款管道(markEntryPaid),语义重叠需单独设计 |
| 收入转入账户放开 | 收款无信用卡场景 |
| 贷款/其他负债类作支付账户 | 仅信用卡有「刷卡消费」真实语义;后续需要再放 |
| 信用卡 StatRow/利用率在支出表单展示 | 表单非卡片详情,信息架构不动 |

## Feasibility

technical 可行(纯 UI 过滤 + 守卫,引擎零改动)/economic 一票内/operational 直接消解用户两点报告。

## Grill record

| 决策 | 挑战 | 裁定 |
|---|---|---|
| 放开范围=仅信用卡类,还是全部负债 | 全部负债=「从贷款户刷支出」无真实语义,误开风险 | 用户原话「信用卡账户」;范围锁 creditCard 类 |
| 转账是否同放 | 信用卡转账=还款/取现,与债务模块还款管道语义重叠 | 排除,NonGoal 记录 |
