# F52 design — 建户预设模板层

> /sydusx-design 2026-10-10。消费 spec.md;架构内设计(DDD 四层,零新基建)。
> **prototype: v14**(六项平权入口菜单 + 花呗预填态为实施基准;v13 为三形态对比探索页)。

## Context

花呗等互联网信用产品与 creditCard 类别语义完全同构(消费记支出/月度全额还/账单周期),预设是效率与呈现问题。类别体系原样保留,预设仅预填。

## Goals / NonGoals

- **Goals**:四条产品预设两击接入;六项平权入口(普通信用卡同层);预填可改+角标;建后脱钩。
- **NonGoals**:schema/proto 变动;银行清单;表单 chips/双入口;per-product 属性;期表锚点(F57)。

## Decisions(ADR)

- **ADR-1 预设目录 = account domain 纯常量**(随发版)。备选否决:远程配置(无此基建,YAGNI)、用户自定义预设(v1 无需求信号)。
- **ADR-2 入口 = 新建按钮六项平权菜单**(v14 用户定稿)。备选否决:表单内 chips(决策 2)、双入口(重复维护)。
- **ADR-3 预填 = 表单 initial 注入,全字段可编辑**。备选否决:锁定只读(用户改账单日合法——白条类激活日本就各异)。角标仅标识来源。
- **ADR-4 菜单原语复用 design_kit**(AnchoredMenu/ContextMenuRegion 或既有 PopupMenu 先例,选取次序按 ADR-007:design_kit 优先)。

## HLD

| # | 单元 | 层 | 覆盖 |
|---|---|---|---|
| 1 | `account_presets.dart`:`AccountPreset` 值对象 + `accountPresets` 四条常量 + `creditCardQuickEntry` 语义 | account domain | FR-1/NFR-2 |
| 2 | `account_form_page.dart` 预填通道:构造参数收 preset/普通信用卡预选,initState 回填控制器;预设角标(muted「预设」chip,提交后不持久) | account presentation | FR-3 |
| 3 | `accounts_page.dart` 新建菜单:按钮展开六项(design_kit 菜单原语),路由带参进表单;「全部自定义」走现状无参路径 | account presentation | FR-2 |
| 4 | 测试面:目录完整性/预填三场景/六项结构/自定义回归/既有建户零 diff | test | 全 FR/NFR |

依赖:1 → 2/3;2 与 3 并行(不同文件)。

## LLD(契约)

- `AccountPreset{String name; String institution; int? billingDay; int? repaymentDay; String hint;}`(category 恒 creditCard 不入字段);`const accountPresets = <AccountPreset>[花呗(1,9,null), 京东白条(null,null,'账单日按激活日,建后可改'), 美团月付(同), 微信分付(同)]`。
- 表单参数:`AccountFormPage({AccountPreset? preset, bool preselectCreditCard = false})` → initState:name/institution/(billing/repayment) 回填;`preselectCreditCard` 仅预选类别;角标=输入区旁 muted chip,文案「预设 · 可修改」。
- accounts_page:`_openCreateMenu()` 锚定菜单;项=[信用卡(普通), ...accountPresets, sep, 全部自定义…];点击 → `context.push('/accounts/new?preset=<idx>|cc|custom')` 或构造参数直传(照既有路由先例选型,router.dart 若不便带对象则按索引查目录)。

## Risks

- 路由带参形态(索引 vs 对象)→ design 已给两案,execute 按既有 router 先例定,测试钉死;
- 菜单与既有右键菜单原语的复用错配 → ADR-4 选取次序兜底,必要时轻量 PopupMenu(库内先例多)。

## Migration

无(零 schema;纯新增)。

## Open Questions

无——两决策+修正均经用户拍板(见 spec Grill record)。
