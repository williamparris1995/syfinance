# Design — F51 loan·invest 双重表示规则化

> 2026-10-10 design 定稿。消费 [spec.md](spec.md);architecture/tech-stack 沿既有(Flutter/flutter_bloc/drift,零新 infra)。

## Context

双表示结构 + `numValue` 读列现状见 spec 背景节。F50 先例(debt/domain 纯函数 + account presentation 闭包注入)本票全程同构复用。

## Goals / NonGoals

**Goals**:FR-1/2 表单降级(只读+派生+提示+不写列);FR-3 读侧统一派生(表单=详情=汇总=净资产逐分一致);FR-4 未挂接逐分不变;零 proto/server、不迁移不删列、不回写。
**NonGoals**:详情页「待 Holding 模块接入」占位面板通电(另票,休眠点);server NetWorthService 派生(backlog);invest ytd 计算;ytd/载体户打磨。

## Decisions(ADRs,含 grill 挑战/辩护)

### ADR-1 派生函数落位:debt/domain + holding/domain 纯函数(F50 同构)

**Decision**:`debt/domain` 加 `derivedLoanFields(...)`(四值:Σ总额/Σ剩余/下期月供/下期日);`holding/domain` 加 invest 两值函数(Σ成本/Σ市值,复用既有市价计算管道)。account 侧不建 port 层。
**Alternatives**:①account/domain 聚合 port(消费方不 import 生产方的教条形态)——拒:重(port+数据管道),F50/既有 debt_entity import 先例已确立 domain 纯函数跨模块消费的库内范式;②列回写物化——spec 排除(双事实源+写钩子风险)。
**Grill**:挑战=期表/市价数据不在这两个 domain 怎么办→期表实体/投影属 debt 域(还款计划面板 F35 先例)、市价属 holding 域(收益引擎 R2),纯函数接收调用方组装的最小投影,不反向依赖。

### ADR-2 读侧统一:derivedValueFor 闭包注入(occupationFor 同构)

**Decision**:`numValue` 与详情页估值增加挂接分支——经 `int? derivedValueFor(Account)` 闭包注入(挂接 loan→Σ债剩余本金;挂接 investment→Σ持仓市值;返回 null→现有列读逻辑不变)。accounts_page 现无持仓数据流,**新增 holdings 拉取**(照 _debts 模式:仓库 stream/一次性取)。
**Alternatives**:①改 Account 实体加计算字段——拒:实体不该带跨域派生;②估值服务类——拒:面大,F50 闭包先例轻且已验证。
**Grill**:挑战=净资产/负债聚合会不会分叉→负债侧口径(accounts_page :141 借入债务改用债剩余)本就债源,FR-3 断言跨页逐分一致钉死;未挂接路径 null 短路保 FR-4。

### ADR-3 表单降级态:只读+提示条+提交 orAbsent

**Decision**:编辑态检测挂接(债:∃ debt.accountId==账户;持仓:∃ holding.accountId==账户;数据经参数/仓库一次性取);挂接→字段组渲染为只读态(禁用输入+派生值文本)+提示条「以债务/持仓数据为准」;提交时组字段传 **null**——`orAbsent` 语义(account_local_ds:159 实证)即保留原列值,天然「不写列」。
**Alternatives**:提交读控制器现值再传——拒:多一步易错;null-保留是库内既有语义。
**Grill**:挑战=新建态会不会误降级→挂接判定只在编辑态(新建无 accountId 关联),FR-4 回归钉。

### ADR-4 prototype: none

UI 面=既有表单控件的只读态+提示条(库内既有模式),零新布局/页面;F50/F41 先例。

## HLD(单元/接口/依赖)

| # | 单元 | 职责 | 依赖 |
|---|---|---|---|
| U1 | `debt/domain` 派生函数 | `DerivedLoanFields{totalPrincipal,remaining,nextPaymentCents?,nextPaymentDate?}` + `derivedLoanFields(List<Debt>, 期表投影)`;下期定义=paid=0 中 payment_date 最小(含逾期),无未付期→null | Debt 实体/期表投影 |
| U2 | `holding/domain` 派生函数 | `derivedInvestCostCents`/`derivedInvestMarketValueCents`(复用既有市价管道;持仓空→null 由调用方判挂接) | holding 实体/市价 |
| U3 | `account_form_page` 降级态 | 编辑态挂接检测+只读渲染+提示条+提交组传 null | U1/U2 |
| U4 | 两页读侧 | `derivedValueFor` 闭包:accounts_page(numValue/汇总)+ detail(hero 估值);accounts_page 新增 holdings 拉取 | U1/U2 |
| U5 | 测试 | 派生 fixtures/跨页逐分一致/未挂接回归/提交不写列/期表边界(全付清/逾期期) | U1-U4 |

依赖方向:U3/U4 → U1/U2(domain 纯函数);无反向。

## LLD

### U1 契约

```
class DerivedLoanFields {
  final int totalPrincipalCents;      // Σ debt.totalPrincipalCents
  final int remainingPrincipalCents;  // Σ debt.remainingPrincipalCents
  final int? nextPaymentCents;        // Σ 各债下一未还期 total(无期表债计 0;全无→null)
  final DateTime? nextPaymentDate;    // min 各债下一未还期日(全无→null)
}
DerivedLoanFields derivedLoanFields(List<Debt> debts, Map<String, DebtNextPeriod> nextByDebtId)
// DebtNextPeriod{totalCents, date} 由调用方从期表构造(paid=0 最早,含逾期)
```

### U2 契约

`int derivedInvestCostCents(List<HoldingLike>)`(Σ 每持仓数量×均价成本,与持仓页口径同源)/ `int derivedInvestMarketValueCents(...)`(Σ 数量×现价;复用 holding 既有市价取数,函数收投影避免 domain 依赖 price 仓库)。

### U3 表单

- 挂接检测:`hasAttachedDebts(accountId)`/`hasAttachedHoldings(accountId)`,编辑态打开时一次性取(经 getIt 仓库,表单测试坑记忆:getIt 须注册)。
- 只读态:字段组区渲染派生值 Text + `callout.info` 提示条(「以债务/持仓数据为准,请在债务/持仓页维护」);提交构造 params 时 loan/invest 组字段全部 null。

### U4 读侧

- accounts_page:`_holdings` 拉取(照 `_debts`);`derivedValueFor = (a) => a.category==loan ? Σ挂债剩余 : a.category==investment && 持仓非空 ? Σ持仓市值 : null`;`numValue` 各 category 分支前置该闭包(null→原逻辑,FR-4)。
- detail 页:investment/loan 账户 hero 与卡片估值同闭包;「持仓列表」占位面板不碰。

### U5 测试锚

- 派生:多债聚合(35,000+9,100 例,数字照 spec FR-1 Scenario)/无期表回退 0/null/全付清 null/逾期期计入下期。
- 跨页一致:挂接 loan 账户(列值 stale 0)在表单/详情/汇总三处 == Σ债剩余,逐分断言;未挂接账户改动前后输出逐分一致(快照对照)。
- 提交不写列:挂接态保存 → DS 收到的 params 组字段为 null(捕获断言)。

## Risks

| 风险 | 缓解 |
|---|---|
| accounts_page 新增 holdings 拉取的重建/时机 | 照 _debts 既有模式;测试钉 |
| 期表「下一未还期」口径含逾期 | 定义写死=paid=0 最早(含逾期),fixtures 钉 |
| numValue 改动波及净资产数字(挂接账户) | FR-3 语义即此(列→派生);现库无此形态(载体户空列),真值影响为零,回归断言未挂接不变 |
| 详情页「待 Holding 接入」占位相邻误碰 | NonGoals 显式排除 |

## Migration

零 schema/proto 迁移;纯读侧行为变化仅挂接账户(现库零形态)。

## Open Questions

1. 期表投影类型复用 debt/domain 既有实体还是新建最小 DTO(实现期定,倾向复用)。
2. holding 市价投影的具体来源(现价快照 vs 计算函数输出)——实现期对齐持仓页口径。

## prototype: none

(UI 面全复用既有表单只读态+提示条模式;F50/F41 先例,ADR-4。)
