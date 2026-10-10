# F49 design — 载体户隐藏(isSystem 激活)

> /sydusx-design 2026-10-10。消费 [spec.md](spec.md);架构在 [architecture.md](../../../../architecture.md)/[tech-stack.md](../../../../tech-stack.md) 内设计(DDD 四层 + flutter_bloc,零新基建)。
> **prototype: v12**(卡面分期徽标 + 卡详情分期区块为 execute 实现基准;[v12/ui/f49-carrier-compare.html](../../../prototype/v12/ui/f49-carrier-compare.html) 为 Before/After 对比页)。

## Context

卡贷并入模式自动创建的贷款负债户是复式账管道(未出账剩余本金的账务载体),银行 app 无此账户,现以平级贷款行露出破坏镜像。spec 定稿:并入型隐藏、独立型(e招贷)永不隐藏;净资产零改动;镜像抹除为预期边界。

## Goals / NonGoals

- **Goals**:载体户退出用户视野;分期可见性挂卡(卡面徽标+详情区块);存量一次性标记+孤儿清理;债删自动关户;净资产/报表/账务逐位不变。
- **NonGoals**:bound 置位与 proto 透传(未来卡贷 bound 支持票);parentId 激活;额度口径(F50);预设层(F52);任何分录/不变式改动。

## Decisions(ADR;grill 记录见 spec Grill record)

- **ADR-1 过滤层 = 展示层统一 helper + grep 门**(方案 C)。备选否决:B 仓储默认过滤+双 API(计算/镜像全要全量,双 API 复杂度永久化)、A 逐查询点(漏点不可检)。挑战「纪律靠门保」→ 辩:本库 grep 门纪律有 F28 先例,净资产/报表/镜像天然不受扰。
- **ADR-2 并入/独立判别**:债侧 `collectionAccountId` 非空 = 并入型;孤儿修复三重门 = notes 精确匹配 `信用卡贷款(卡贷)自动创建` + 余额 0 + `creditBillingDay IS NULL`(排除独立账单真实账户)。
- **ADR-3 FR-4 形态 = 卡面分期徽标 + 卡详情分期区块**(v12 用户定稿;v11 贷款组汇总行方案否决)。
- **ADR-4 镜像边界钉死**:`mirror_mappers.dart` 不改,绑定后 isSystem 回 false、载体户回可见为**预期行为**(NFR-1 测试钉死)。
- **ADR-5 FR-5 自动关户复用既有关闭语义**(status 流转),永不删除账户。

## HLD(单元 → spec 映射)

| # | 单元 | 层 | 覆盖 |
|---|---|---|---|
| 1 | Account entity 增 `isSystem` + `AccountVisibility` 助手 + mapper/local_ds/remote 透传 | account domain/data | FR-3 地基 |
| 2 | 建户路径并入模式传 `isSystem: true`(`CreateAccountParams` 增可选参,缺省 false) | debt presentation → account | FR-1 |
| 3 | `runF49CarrierHideRepair`(标记+孤儿关闭,marker `f49_carrier_hide_v1`,挂 beforeOpen 链尾、e_dai 系列之后) | core/localdb | FR-2 |
| 4 | 展示过滤:accounts_page 列表 + 账户选择器实查枚举 + grep 门脚本 | 各 presentation | FR-3 |
| 5 | `cardInstallmentSummary(debts, cardId)` 纯函数 + 信用卡卡面 fchip 徽标(**与 F50 占用同源单实现**) | debt domain + account presentation | FR-4a |
| 6 | 卡详情分期区块:既有 collectionAccountId 面板增强(每笔摘要行+查看债务入口) | account presentation | FR-4b |
| 7 | 债删自动关户:delete 后置检查(isSystem && 余额0 && 无其他借入债)→ 注入 `AccountCloser` port 关户 | debt data + port | FR-5 |
| 8 | 备份 envelope accounts 补 isSystem(核验现状,缺则补) | core/localdb codec | NFR-2 |

依赖:1 → 2/3/4/5/7;3 依赖存量 e_dai 解挂已完成;5/6 依赖 v12 原型基准;7 依赖 1(entity 字段)。

## LLD(设计契约)

- **单元1**:`Account.isSystem`(bool,缺省 false);`AccountVisibility.userVisible(Iterable<Account>) → List<Account>`(过滤 `isSystem==true`);domain 纯函数零依赖。mapper:drift↔entity 双向;remote DTO 映射保持现状(server 恒 false)。
- **单元3(repair 语义)**:
  ① `UPDATE accounts SET is_system=1 WHERE EXISTS (SELECT 1 FROM debts d WHERE d.account_id=accounts.id AND d.subtype='card_loan' AND d.debt_type=1 AND d.collection_account_id IS NOT NULL)`
  ② 孤儿关闭:`status=closed` WHERE notes='信用卡贷款(卡贷)自动创建' AND current_balance_cents=0 AND credit_billing_day IS NULL AND 无 card_loan 借入债挂靠;
  ③ 非零孤儿与独立账户零动作。app_meta 幂等,中断重入安全(照 e_dai 链模式)。
- **单元5**:`({int count, int remainingCents}) cardInstallmentSummary(List<Debt> debts, String cardId)` —— Σ 名下 `subtype==card_loan && collectionAccountId==cardId && 未结清` 的剩余(本金口径 = totalPrincipal − Σpaid,与 F36 同式)。fchip 徽标照 v12:`分期 N 笔 · 剩余 ¥X`(accent 令牌,`.num`)。
- **单元6**:每笔行 = 债权方 / muted「N 期 · 第 k 期 · 放款对应日出账」/ 剩余 + 下一期(金额·日期·并入账单)/「查看债务 →」跳 `/debts/:id`。
- **单元7**:delete 事务内,清账分录落定后检查载体户;`AccountCloser` port(`Future<void> closeIfEmptyCarrier(String accountId)`)由 account 侧实现注入 debt DS。
- **grep 门**:新增 lint 检查「账户列表/选择器渲染处禁止绕过 `userVisible` 直用账户流」——静态 grep 脚本进 CI 可后置,review 必查。
- **测试面**:FR-1 两场景 / FR-2 三场景(repair 幂等) / FR-3 净资产逐位钉死 / FR-4a 徽标数据源单测+widget 测 / FR-4b 面板测 / FR-5 关户测 / FR-6 两露出回归 / NFR-1 镜像后可见钉死 / NFR-2 备份往返。

## Risks

| 风险 | 缓解 |
|---|---|
| 选择器散、漏过滤 | 单元4 实查枚举 + grep 门 + e2e;漏点只影响可见性不影响金额 |
| F50 与徽标数据源双实现 | 单元5 定为同源单函数,F50 直接复用 |
| 孤儿误关 | 三重门(notes/余额/账单日)+ 非零不动 + repair 单测 |
| 绑定后回可见被当 bug | NFR-1 钉死为预期 + 详情页/文档注明 |

## Migration

单一幂等 repair(单元3),执行于下次启动 beforeOpen;顺序在 e_dai 系列 repair 之后(依赖解挂先行)。

## Open Questions

无——全部决策经 grill 拍板(见 spec Grill record)。
