# Design — F50 卡贷额度占用重落

> 2026-10-10 design 定稿。消费 [spec.md](spec.md)(analysis 已确认);architecture/tech-stack 沿产品既有(Go+Flutter/drift/flutter_bloc,零新 infra,不重选)。

## Context

`794bc677` 的占用实现因 e招贷挂接灌水被 `8088dd36` 回退;解挂后动因消失,但直落会再现灌水(¥35k 平安分期银行走专项额度)。真库+银行真值对账已完成(spec 背景节):口径=仅剩余本金(期表),四笔期表各晚一期,载体户余额禁用。

## Goals / NonGoals

**Goals**:占用公式按 spec FR-1 落地;债级开关(FR-2);显示面接线(FR-3);平安四笔期表修复(FR-4);真值校准测试(FR-5);零 proto/server 改动。
**NonGoals**:载体户息费缺口(另开票);开关跨设备同步;专项额度池建模;期表生成器「首期当期 vs 次期」约定改造(见 Open Questions);广发期表修复(无真值不臆造)。

## Decisions(ADRs,含 grill 挑战/辩护)

### ADR-1 占用函数:debt/domain 纯函数,剩余本金口径

**Decision**:`debt/domain/debt_query.dart` 新增 `cardLoanOccupationCents(List<Debt>, String cardId)` → Σ `remainingPrincipalCents`,过滤 `subtype==card_loan ∧ collectionAccountId==cardId ∧ countsTowardCardLimit`。
**Alternatives**:①复用载体户余额(拒:被已付息费污染 −¥3,189.03,spec 明令禁用);②AccountDebtInfo 聚合通道扩展(拒:跨模块 port 语义过重,display 闭包注入先例更轻)。
**Grill**:挑战=实体字段从哪来→`Debt.remainingPrincipalCents` 既有 required 字段(期表口径),794bc677 已用同源,零新计算面。

### ADR-2 开关持久化:drift 本地列(默认 true),sync applier keep-existing

**Decision**:debts 表加 `counts_toward_card_limit`(bool,NOT NULL DEFAULT true),schemaVersion 12→13;Debt 实体 + debt_local_ds 映射透出。
**Alternatives**:①proto 字段全链路(拒:破 R17 零 proto 门;单设备现状,列 backlog);②债 metadata JSON(拒:债无 metadata 通道,同样要 proto)。
**Grill**:挑战=同步会不会冲掉本地列→sync applier 按重建 proto 对象映射行时对新列 **keep-existing**(该列不在 proto 里,applier 不得覆写);加回归测试(guest 主形态风险低,bound 在线编辑债后本地列保持)。挑战=默认值→true(银行默认占额度,35k 这类少数置关)。

### ADR-3 显示注入:复用 occupationFor 闭包缝

**Decision**:accounts_page `_GroupBlock/_AccountCard` 经 `occupationFor` 闭包注入(794bc677 形态);account_detail_page 四卡同法。已用 = `currentBalanceCents.abs() + occupation`;可用 = `creditLimitCents − 已用`;利用率 clamp(0,1) 既有。
**Grill**:挑战=为何不进 AccountDebtInfo→该通道挂负债摘要语义,占用是授信视图,混入会污染债务页消费方;display-only 断言钉死净资产不变。

### ADR-4 期表修复载体:app 内补记四笔(放款日 × 首期月供)

**Decision**:用户在 app 内对四笔各补记一期还款,日期=各放款日、金额=各自月供:35k→2026-06-12 ¥1,630.46;25k→2024-12-24 ¥1,081.18;9.1k→2025-09-25 ¥447.44;5k→2026-08-02 ¥319.63。修复后校验剩余==银行真值(容差见 spec delta)。
**Alternatives**:一次性脚本直改库(拒:F36 教训——raw SQL 绕交易管道不联动余额=漂移根源;补记走正规还款管道,载体户/期表/交易三面一致)。
**Grill**:挑战=补记后期次日期仍晚一个月→数值达标即验收(月供恒定,标记多一期后剩余精确对齐银行);日期残留记 Open Questions 非本票范围。

### ADR-5 prototype: none

**理由**:UI 面=债表单一开关行(既有表单控件模式)+ 既有卡片组件数值变化,零新布局/新页面/新交互范式;F41 先例(ADR-5 用户拍板 prototype:none)。design 不产原型,execute 照既有表单范式实现。

## HLD(单元/接口/依赖)

| # | 单元 | 职责 | 依赖 |
|---|---|---|---|
| U1 | `debt/domain/debt_query.dart` | `cardLoanOccupationCents` 纯函数 | Debt 实体 |
| U2 | `debt/data`(schema v13 + DAO) | 列迁移/映射/查询透出 | drift |
| U3 | `debt/presentation` 表单+详情 | 「计入挂接卡额度占用」开关行(默认开) | U2 |
| U4 | `account/presentation` 两页 | occupationFor 注入:卡片已用/利用率 + 详情四卡已用/可用 | U1 |
| U5 | 数据修复 runbook | 四笔补记操作+校验清单(非代码,S4 执行) | — |
| U6 | 测试 | domain 单测四 fixtures + 校准用例 + display-only 断言 + sync applier 列保持 | U1-U4 |

依赖方向:U4→U1(domain 纯函数,无反向);U3→U2;均不越 DDD 层。

## LLD

### U1 函数契约

```
/// 卡贷未出账占用(银行口径:仅剩余本金,期表口径;开关关的不计)。
int cardLoanOccupationCents(List<Debt> debts, String cardId)
```
过滤:`d.subtype == DebtSubtypes.cardLoan && d.collectionAccountId == cardId && d.countsTowardCardLimit`;求和 `remainingPrincipalCents`(int cents)。未挂接(collectionAccountId 空)天然不匹配任何 cardId → FR-4 零占用由构造保证 + 测试钉死。

### U2 迁移与映射

- schemaVersion 12→13;`ALTER TABLE debts ADD counts_toward_card_limit INTEGER NOT NULL DEFAULT 1`(drift MigrationStrategy 既有范式)。
- Debt 实体加 `final bool countsTowardCardLimit;`(默认 true);debt_local_ds 行↔实体映射双向透出。
- **sync applier 约束**:债行从 proto 重建时,该列取本地现值(keep-existing),不得重置;若本地行不存在(新拉取)取默认 true。

### U3 开关 UI

债编辑表单(卡贷/creditCard 分类目下)增加开关行:「计入挂接卡额度占用」+ helper 说明(银行备用金类独立额度置关);详情页只读展示当前值(可选,execute 顺手)。开关仅挂接卡(collectionAccountId 非空)时显示。

### U4 显示接线

- accounts_page:`occupationFor: (a) => cardLoanOccupationCents(_debts, a.id)` 注入(794bc677 diff 直接参照,改口径);creditCard 卡片「已用 X / 额度」与利用率条计入。
- account_detail_page:四卡「已用/可用额度」:已用=abs(balance)+occupation,可用=limit−已用(替换 7245465c 的 limit−欠款 单减法)。

### U6 测试

- domain:四 fixtures——平安真值(11,271.70/38,728.30)、e招贷零占用(招行 575.10)、开关关(35k 排除)、广发挂接(≥1 组合)。
- widget:display-only 断言(改开关前后,负债总额/净资产逐分不变);开关行表单交互(挂接才显示)。
- sync:applier 重建债行后 countsTowardCardLimit 保持。
- 校准:FR-5 银行真值用例(数字锚进测试)。

## Risks

| 风险 | 缓解 |
|---|---|
| sync applier 覆写本地列 | keep-existing + 回归测试;guest 主形态无此路径 |
| 补记操作把期次日期标错位 | 月供恒定→剩余数值精确对齐;日期残留记 Open Questions |
| 已用>额度(理论极端) | 利用率 clamp 既有;文本如实显示 |
| 修复后与银行仍差分级 | 容差 ±¥2(spec delta);25k 残差 1.25 已知 |

## Migration

- drift v13 加列(默认 true)= 纯增量,老库无损;无 proto/server 迁移。
- 数据修复(U5 runbook):四笔补记→重启→取证核对(spec 背景数字)→平安卡显示可用 == ¥38,728.30。

## Open Questions

1. **期表生成器「首期=放款日当期 vs 次月」约定**:四笔全偏一个月,新建卡贷可能复现——backlog 候选票(改生成约定或建表单加首期选项),F50 不动。
2. 25k 银行舍入残差 ¥1.25:容差覆盖,不追分。
3. 广发真值校准:用户提供广发 App 数字后可顺带修复(数据面,不阻塞本票)。

## Spec delta(design 期修正)

- FR-4 容差 ±¥0.02 → **±¥2.00**:25k 银行侧分期摊销舍入残差 ¥1.25,±0.02 收不住(对账数据实证);其余三笔残差 ≤¥0.01 不变。

## prototype: none

(UI 最小面,复用既有表单控件与卡片组件;F41 先例,ADR-5。)
