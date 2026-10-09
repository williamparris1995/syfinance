# Release R17 — 账户扩展性(account-extensibility)

> /sydusx-portfolio 2026-10-09 立项。product checkpoint:重读 [vision.md](../vision.md),Product Goal(可分发的商业级个人专业理财客户端、19 模块行业级)ongoing;账户模块扩展性在 vision「功能对标模块」路径内。
> 起因:用户 2026-10-09 三轮设计对谈——①平安现金分期(并入卡账单)vs e招贷(独立账户)行为区分(已随 `b6205457` 落 main);②行业调研(Beancount/GnuCash/钱迹/小星记账/YNAB/Monarch/Firefly III)验证御财「负债载体户+卡镜像账单」结构为复式账主流;③账户字段审计定案:体系不重构,通电休眠扩展点(parentId/isSystem 有 transaction 分类模块先例),死列(sortOrder/chartCode)留待契约变更顺带清理。

## Release Goal

账户体系在不重构 schema 的前提下具备产品扩展能力:花呗/白条等常见信用产品经预设模板一键接入(creditCard 类别);卡贷载体户退出用户视野(isSystem 激活);挂接卡的已用/可用额度计入未出账分期占用(银行口径);loan/invest 字段组在挂债/持仓时降级只读,消除双重表示漂移。

## Decisions(用户拍板 2026-10-09)

- **编号 = R17**:账户扩展性包用 R17;R16 立项时「待摊引擎 R17 候选」仅为备忘,顺延为 R18 候选。
- **Sprint = 两段,治欠账先行**:sprint-1 = F49/F50/F51 三张独立小票(依赖 `b6205457` 的 e招贷解挂);sprint-2 = F52 预设层(含花呗/白条产品口径调研,体量独立)。小票先落地不被大票阻塞。
- **前置 WIP 处置 = 验证后落 main**:`b6205457`(e招贷独立账单账户 + design_kit 治理复合提交;2496 测全绿 + analyze 20 error 全 pbserver 基线;design_kit 生成产物已出索引+包级 .gitignore)。
- **结构定案(对谈+调研+审计支撑)**:账户体系与分类不重构;花呗/白条走 creditCard 类别+预设,零 schema 改动;per-product 属性(如「不参与支付推荐」)不加 STI 列,metadata JSON 方向仅在 F52 spec 评估(需 proto 变更,默认不做)。依据存项目记忆 `account-fields-audit`。

## Sprint roster

- [ ] [sprint-1](sprint-1/sprint.md) — F49 isSystem 激活·载体户隐藏 / F50 卡贷额度占用重落 / F51 loan·invest 双重表示规则化
- [ ] sprint-2 — F52 花呗/白条等建户预设模板层(sprint-1 收官后立项)

## Done criteria

1. 载体户不再以平级账户行露出:卡贷自动建户置 isSystem=true,账户页列表/建户下拉/相关聚合过滤;卡详情还款计划面板与债务页「信用卡账单分期」分组既有露出保留;净资产计算不受过滤影响。
2. 挂接卡(平安/广发口径,并入模式)的「已用/可用额度」计入卡贷未出账占用;占用口径(银行全额 vs 钱迹本金)F50 spec 拍板;e招贷独立账单户不计入任何卡占用。
3. loan/invest 字段组在账户挂债/持仓时只读降级(以债务/holding 数据为准,UI 提示来源),无挂接时维持手动编辑;不迁移不删列。
4. F52:花呗/白条(及常见银行)预设模板,creditCard 类别,预填额度/账单日/还款日;零 proto 改动(F49-F51 预计同,若镜像链确需 server 透传 isSystem 则在对应 spec 显式拍板)。
5. 全门:flutter test 全绿 + analyze 基线 + `make client-e2e`(零 proto 改动免 go 门)。

## status: pending
