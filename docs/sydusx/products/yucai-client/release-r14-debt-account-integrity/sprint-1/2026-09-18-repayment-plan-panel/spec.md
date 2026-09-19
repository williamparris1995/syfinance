# Spec — F35 贷款账户详情页还款计划面板(R14 sprint-1)

> 2026-09-18。源起:用户 5 点需求之③「账户详情没接入还款计划」;L 级 scope,复用第一。

## Requirements

### Requirement: FR-1 贷款账户详情显示还款计划面板
- [ ] `SHALL` category=loan 的账户详情页,当该账户名下存在借入债务时,渲染「还款计划」面板:每笔债一组——对方名称 + 剩余本金(badge) + 未来未还期次(最多 3 条:日期/本期合计),底部「查看完整还款计划 →」跳转 `/debts/{id}`。
- [ ] `SHALL` 数据经既有管道:DebtRepository.list(typeFilter: borrowedIn) 按 accountId 过滤 + repo.get(id) 取 schedule(未还按日期升序),真实本地/绑定路由行为与债务页一致。

#### Scenario: 一户一债
- GIVEN 贷款账户挂 1 笔债(2 条未还期次)
- WHEN 进入详情页
- THEN 面板显示债名+剩余本金+2 条期次(日期/合计)+跳转入口

#### Scenario: 跳转
- WHEN 点「查看完整还款计划 →」
- THEN 打开 /debts/{id} 债务详情(完整交互计划所在页)

### Requirement: FR-2 空态收敛
- [ ] `SHALL` 名下无借入债务的贷款账户,详情页不渲染还款计划面板(隐藏优于空占位);投资类占位维持现状(F36 后另票)。

#### Scenario: 无债贷款账户
- GIVEN 贷款账户名下 0 笔债
- WHEN 进入详情页
- THEN 无「还款计划」面板(也不显示旧占位文案)

### Requirement: FR-3 返回刷新
- [ ] `SHALL` 从编辑/其他表单返回详情页时(didPopNext,hotfix 已有),还款计划随详情一并重拉。

## NFRs

- [ ] `MUST` 面板组件落 `core/widgets/repayment_plan_panel.dart`(共享位,照 debt_detail_widgets 惯例),只读零新交互;色值全 context.yucai 令牌。
- [ ] `MUST` 范围=category==loan;个人待还款(otherLiability)扩展记 backlog 不做。

## Scope boundary

| 排除项 | 理由 |
|---|---|
| 面板内直接记账/改日/标记已还 | 交互归债务详情页(单一事实源),面板只读+跳转 |
| ~~otherLiability 账户同面板~~ | **已转正(2026-09-19 用户「需要」)**:FR-2 扩展为 loan+otherLiability;stats 条不隐藏(其 4 卡为真实收支数据,非静态 0) |
| 投资类「持仓列表」占位 | 另票(Holding 模块接入) |
