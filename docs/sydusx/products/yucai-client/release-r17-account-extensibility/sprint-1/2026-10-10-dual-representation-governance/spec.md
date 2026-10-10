# Spec — F51 loan·invest 双重表示规则化

> 2026-10-10 analysis 定稿(clarify 一问拍板 + 代码/真库事实核)。票面与 release 拍板见 [sprint.md](../../sprint-1/sprint.md) / [release.md](../../../release-r17-account-extensibility/release.md)(done-criterion 3);审计依据 = 项目记忆 account-fields-audit(双表示:不重构,通电即可)。

## 背景与事实源(代码+真库)

- **双表示结构**:loan 类账户有 `loanOriginal/Remaining/MonthlyCents + loanNextPaymentDate` 列,invest 类账户有 `investCost/MarketValueCents + investReturnYtd` 列;同时债(totalPrincipal/remaining+期表)与持仓(avg_cost/市价)持有同义数据。真库实况:**结构存在、数据未灌水**(挂债账户 6 个全为载体户,loan 组全空;「证券账户」挂 1 持仓,invest 组全空)——F51 关的是「未来平行维护」的门。
- **读侧现状(决定性)**:accounts_page 估值函数 `numValue`(:70-100)investment→`investMarketValueCents`、loan→`loanRemainingCents` 直接读用户维护列(回退 currentBalance)。**只改表单不改读侧 = 详情派生值 vs 汇总列值对不上 = 复刻 R14「页面间对不上」病根**。
- 字段组渲染门:loan 组仅 `AccountCategory.loan` 表单渲染,invest 组仅 `investment`;债挂接 = `debts.account_id`(借入债,含建债选既有账户);持仓挂接 = `holdings.account_id`。
- F49 交互:载体户激活 isSystem 后从列表隐藏,F51 的可见主战场 = 用户自建 loan/invest 账户挂接债/持仓的形态(现库无此形态,为前瞻治理);载体户不可达时降级态自洽即可。

## Requirements

### Requirement: FR-1 loan 字段组降级(只读+债侧派生)

- [ ] `AccountCategory.loan` 账户存在挂接借入债时,账户表单 loan 字段组**SHALL**只读并显示派生值 + 提示「以债务数据为准」:总额 = Σ `debt.totalPrincipalCents`;剩余 = Σ `debt.remainingPrincipalCents`;月供 = Σ 各债期表下一未还期 `total_cents`(无期表计 0);下期还款日 = min(各债下一未还期 `payment_date`,全无则空)。挂接态提交**MUST NOT**写 loan 组列。

#### Scenario: 挂债 loan 账户表单

- GIVEN loan 账户挂 2 笔借入债(总额 35,000+9,100,剩余 29,683.44+4,540.32,下一未还期月供 1,630.46+447.44、日期 2026-10-12/2026-10-25)
- WHEN 打开编辑表单
- THEN loan 四字段只读:总额 ¥44,100.00 / 剩余 ¥34,223.76 / 月供 ¥2,077.90 / 下期 2026-10-12;组头提示「以债务数据为准」;保存不改变 loan 组列值

### Requirement: FR-2 invest 字段组降级(只读+持仓侧派生)

- [ ] `AccountCategory.investment` 账户存在挂接持仓时,表单 invest 字段组**SHALL**只读 + 提示「以持仓数据为准」:成本 = Σ 持仓成本;市值 = Σ 持仓市值;ytd 显示「—」(持仓侧无同义字段,收益以持仓页为准,不造新数字)。提交**MUST NOT**写 invest 组列。

### Requirement: FR-3 读侧统一派生(反新漂移,本票核心不变式)

- [ ] 挂接后,账户估值与聚合(client 侧:账户页 `numValue`、汇总头/净资产、账户详情)**MUST**以派生值为准——loan 挂接→估值 = Σ债剩余本金;invest 挂接→估值 = Σ持仓市值;账户列**仅未挂接时生效**。同一账户在表单/详情/汇总/净资产的数值 MUST 逐分一致。

#### Scenario: 列值陈旧不污染估值

- GIVEN loan 账户挂债(Σ剩余 ¥34,223.76),其 `loanRemainingCents` 列陈旧为 0
- THEN 账户页估值与汇总头显示 ¥34,223.76(派生),不显示 0

### Requirement: FR-4 未挂接行为不变

- [ ] 无挂接的 loan/invest 账户,字段组手动编辑、估值读列(含回退 currentBalance)行为**SHALL**与改动前完全一致(回归断言钉死)。

### Requirement: NFR-1 质量门与边界

- [ ] 全量 flutter test 绿 + analyze 不超基线 + `make client-e2e`;**零 proto/server 改动、不迁移不删列、派生不回写**;server 侧 NetWorthService 的同义派生 = backlog(记 Scope boundary,guest 主形态不阻塞)。

## Scope boundary(排除项,经 grill)

| 排除 | 归属 | 辩护 |
|---|---|---|
| server NetWorthService 派生 | backlog | guest 主形态;bound 模式净资产 server 算,派生统一另票(避免静默扩面) |
| 派生值回写账户列 | 不做 | 双事实源+写路径钩子风险;读侧统一已消歧,列退为回退 |
| 载体户上的降级态打磨 | 顺带自洽即可 | F49 隐藏后不可达,非主战场 |
| invest ytd 持仓侧计算 | 不做 | 无同义字段;显示「—」+提示,不造新数字 |
| 既有空列清理 | 不做 | 不迁移不删列(release 定案) |

## Grill record

| # | 决策 | 挑战 → 辩护 |
|---|---|---|
| 1 | 降级语义 = A 只读+债侧派生 | B 只锁编辑实现简 → 锁一堆空字段价值低;用户拍板 A(2026-10-10) |
| 2 | 读侧统一派生(FR-3) | 只改表单会造详情 vs 汇总新漂移 → `numValue` 现读列的证据(:70-100);A 语义的必然推论,否则票自 defeat |
| 3 | server 派生 backlog | bound 净资产 server 算 → guest 主形态,扩面另票,Spec boundary 显式记 |
| 4 | ytd 显示「—」 | 持仓侧造 ytd? → 无同义字段不造新数字 |
| 5 | 不迁移不删列+不回写 | release 定案;读侧统一已消歧 |

## Feasibility

- **Technical: 可行** — 派生纯函数(债/期表/持仓已有数据面)+ `numValue` 挂接分支 + 表单只读态;无 schema/proto 变更。
- **Economic: 可行** — 单票体量;收益 = 关死双表示漂移门(R14 病根类预防)。
- **Operational: 可行** — 纯 client;guest 主形态直接生效。
