# Design: F62 债务表单重做

prototype: v18

> UI-scoped(Path B — debt-form-ux.html 用户逐组拍板);usage grounding:Andy,单用户桌面;key-paths:①美团网贷=点「借钱到银行卡」→自动推导信用贷款→到账卡只亮储蓄卡 ②信用卡分期=点卡→挂卡字段组展开 ③编辑存量债按 subtype 反选。交互规范=[ux-interaction.md](../../../ux-interaction.md)(R21 事实源,表单容器裁定=整页)。

## Context

现状 10 术语下拉+全量账户+事后警示(违反 About Face,审计 D/C/E 命中)。spec confirmed;F52 预设层/六表单守卫族/R19 面包屑为既有地基;域层零改动(白名单 DebtSubtypeAffinity 降为过滤器数据源)。

## Decisions (ADRs)

- **ADR-1 场景卡=表单内组件而非新页**:ProductScenarioPicker(debt_form 内 Stateful widget)——4 卡+「更多类型」折叠入口(完整枚举);映射表 `subtypeOfScenario` 常驻;编辑态 initState 反选。*Alternatives*:独立类型选择页(多一跳,违反渐进披露)/保留下拉加说明(不解决心理模型)。*Grill*:OD debt-form-ux 拍板。
- **ADR-2 灰显过滤=选择器内过滤**:FilteredAccountPicker 包装既有 DropdownButtonFormField——items 由 `DebtSubtypeAffinity.compatible` 反查资产/信用卡账户集合;不可选项 disabled+helperText 原因句;`isConflict` UI 调用点(警示条)删除。*Alternatives*:仅过滤可选项不灰显(丢上下文,NN/g 明反对)。
- **ADR-3 载体户隐形**:普通贷款表单删「关联账户」字段,保存时若 accountId 空→复用现有自动建载体逻辑(isSystem);「钱到账哪张卡」=sourceAccount 字段(资产类过滤)。信用卡分期保留挂卡选择(信用卡账户灰显过滤)。
- **ADR-4 三段渐进**:现字段重排为 基本/到账与还款/高级(折叠);mobile 维持既有 wizard(三步映射三段);期供预览复用 AmortizationPreview。
- **ADR-5 F52 预设兼容**:预设入口(`preset` 参数)仍直达信用卡分期路径(场景卡自动选中+预设角标),零行为变化。

## HLD

| 单元 | 层 | 职责 |
|---|---|---|
| ProductScenarioPicker | debt/presentation/widgets(新) | 4 卡+更多类型;映射+反选 |
| FilteredAccountPicker | debt/presentation/widgets(新) | 灰显过滤包装 |
| debt_form_page 重构 | presentation | 三段/预览/守卫保留/警示条退役 |
| 测试 | test/debt | 场景卡推导/反选/过滤/折叠/提交链路零弱化 |

## LLD

- `scenario→subtype`:借钱到银行卡→creditLoan;信用卡里的分期→cardLoan;房贷·车贷→二级选择(mortgage/autoLoan);亲友→family;更多类型→余类。反向 `scenarioOf(subtype)` 编辑反选,非映射类→「更多类型」展开选中。
- 到账卡过滤:资产类∧status=active;挂卡过滤:category=creditCard;灰显项 disabled item+副文案原因。
- 期供预览:本金÷期数粗口径+附注(既有 AmortizationPreview 顶部行复用)。
- 守卫/DetailTitleSync/提交流/bloc 零改动(仅字段布局与选择器)。

## Risks

- [mobile wizard 三步与三段映射错位] → mobile 维持现状布局,场景卡嵌入第一步。
- [警示条退役后存量编辑含冲突数据] → 编辑态冲突仍显警示(数据修复入口),新建态不可能冲突。
- [「更多类型」入口可达性] → 折叠头显分类计数,防漏。

## Migration Plan

零迁移;纯 presentation 重构,回滚=revert。

## Open Questions

无。
