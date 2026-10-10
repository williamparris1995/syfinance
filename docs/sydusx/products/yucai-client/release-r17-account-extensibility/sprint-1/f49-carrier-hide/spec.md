# F49 spec — isSystem 激活·载体户隐藏

> /sydusx-analysis 2026-10-09。来源:R17 立项三轮设计对谈 + 行业调研(Beancount/GnuCash 分期子账户从属呈现、钱迹/小星记账消费级产品不给用户看载体)+ 账户字段审计(项目记忆 `account-fields-audit`)。
> 前置事实:`isSystem` 在 drift 表与 Account DTO(proto field 45)均存在,server 从不写 true;`mirror_mappers.dart:33` 镜像重建写死 false;CreateAccountRequest 不收 is_system。
> **关键语义边界(落盘修正,2026-10-09 向用户明示)**:只有**并入模式**(挂接卡账单,平安/广发型)的自动建户是纯账务载体 → 隐藏;**独立账单模式**(e招贷型)的账户是真实账户(账单制面板/repayBill 挂其详情页)→ 永不隐藏。判别 = 债的 collectionAccountId 非空 / 账户带 creditBillingDay。

## Goal

卡贷(card_loan 并入模式)自动创建的贷款负债户(「X · 卡贷」)是账务载体而非用户真实账户,现以平级贷款行露出在账户页,打破银行 app 镜像。本票激活 isSystem:并入型载体户退出用户视野(列表/选择器),账务与净资产计算零改动;贷款组以汇总行保留卡贷负债可见性并可跳转债务规划。

## Requirements

### Requirement: FR-1 并入型载体户建户置位
- [ ] FR-1
系统 SHALL 在 guest 本地路径创建**并入模式**卡贷的自动载体户时置 `isSystem=true`(notes 维持既有自动创建标记);**独立账单模式**的账户 SHALL 保持 `isSystem=false`(真实账户);bound 路径不置位(见 NFR-1)。
#### Scenario: 并入模式建户
GIVEN guest 模式
WHEN 创建信用卡分期(并入信用卡账单,选挂接卡)
THEN 自动创建的载体户 `isSystem=true`

#### Scenario: 独立账单模式不置位
GIVEN guest 模式
WHEN 创建信用卡分期(独立账单,填账单日/还款日)
THEN 自动创建的贷款账户 `isSystem=false` 且带 creditBillingDay/creditRepaymentDay

### Requirement: FR-2 存量一次性 repair(标记 + 孤儿清理)
- [ ] FR-2
系统 SHALL 在启动 repair(app_meta 幂等,照卡贷 repair 链先例)中:①名下存在 `collectionAccountId` 非空的 card_loan 借入债的账户 → 置 `isSystem=true`;②`notes='信用卡贷款(卡贷)自动创建'` 且名下无任何 card_loan 借入债且余额为 0 且 `creditBillingDay IS NULL`(排除独立账单真实账户)的账户 → 执行**关闭**(status=closed,保账史);③非 0 余额孤儿不动作。
#### Scenario: 存量并入型载体标记
GIVEN 存量卡贷债挂接平安卡(collectionAccountId 非空)
WHEN repair 运行
THEN 其载体户 `isSystem=true`

#### Scenario: 孤儿载体关闭
GIVEN 「X · 卡贷」账户 notes 匹配、名下无 card_loan 债、余额 0、无账单日
WHEN repair 运行
THEN 该账户被关闭

#### Scenario: 独立账单账户与非零孤儿不受影响
GIVEN e招贷账户(带账单日)或余额非 0 的孤儿
WHEN repair 运行
THEN 均不置位、不关闭

### Requirement: FR-3 可见处过滤、计算处保留
- [ ] FR-3
系统 SHALL 在账户页列表与全部账户选择器(交易/转账账户、债务关联账户、报表与预算的账户筛选等)过滤 `isSystem=true` 账户;SHALL NOT 影响任何金额计算——净资产 hero、负债总额、报表聚合照常计入载体余额。
#### Scenario: 列表与选择器
GIVEN 载体户已置位
WHEN 打开账户页 / 任一账户选择器
THEN 载体户不可见、不可选

#### Scenario: 净资产钉死
GIVEN 含载体户(余额 ¥N)的库
WHEN 对比过滤开关前后的净资产 hero 与负债总额
THEN 数字逐位一致(测试断言)

### Requirement: FR-4 分期可见性挂到卡上(2026-10-10 用户修订,原贷款组汇总行方案否决)
- [ ] FR-4
系统 SHALL 在挂接信用卡的**卡面**(账户页信用卡卡片)显示关联并入型分期的摘要(N 笔 + 剩余总额);SHALL 在卡详情页显示具体分期记录(债权方/剩余本金/期次进度/下一期)与关联债务入口(既有卡详情挂接面板语义,按需补每笔摘要行);贷款分组小计 SHALL 仅计可见行之和(无汇总行)。
#### Scenario: 卡面摘要
GIVEN 平安信用卡挂接 1 笔并入型分期(剩余 ¥8,400)
WHEN 账户页负债组渲染
THEN 平安信用卡卡面显示「分期 1 笔 · ¥8,400」摘要;贷款组无载体行、无汇总行,小计=可见行之和
#### Scenario: 详情明细
WHEN 打开平安信用卡详情页
THEN 现金分期区列出该笔分期(债权方/剩余本金/期次进度/下一期金额与日期)与关联债务记录入口

### Requirement: FR-5 债删归零自动关户
- [ ] FR-5
系统 SHALL 在 card_loan 债务删除清账后,若其载体户余额为 0 且 `isSystem=true` 且名下无其他借入债,自动关闭该载体户;独立账单模式的账户不受此逻辑影响(真实账户留用户处置)。
#### Scenario: 并入型债清删
GIVEN 并入型卡贷债已全额清偿载体户余额 0
WHEN 删除该债
THEN 载体户自动关闭

### Requirement: FR-6 既有露出回归
- [ ] FR-6
卡详情「还款计划」面板与债务页「信用卡账单分期」分组 SHALL 不因本票过滤消失。
#### Scenario: 两处露出回归
GIVEN 载体户已隐藏
THEN 挂接卡详情的还款计划面板、债务页信用卡账单分期分组仍正常展示

### Requirement: NFR-1 镜像边界(钉死为预期行为)
- [ ] NFR-1
绑定后镜像重建 MUST 维持现状(回写 false、载体户重新可见)——决策 1 拍板的已知边界;proto 透传归未来卡贷 bound 支持票,本票零 proto 改动。
#### Scenario: 绑定后回可见
GIVEN guest 期间载体户已隐藏
WHEN 绑定并触发镜像刷新
THEN 载体户重新出现(测试钉死为预期)

### Requirement: NFR-2 guest 备份往返保留
- [ ] NFR-2
guest 本地备份/恢复往返 MUST 保留 isSystem 置位;若现行 envelope 未含该列,在 execute 阶段补齐。
#### Scenario: 备份恢复仍隐藏
GIVEN 载体户已隐藏
WHEN guest 备份后恢复
THEN 载体户仍隐藏

### Requirement: NFR-3 零账务改动
- [ ] NFR-3
本票 MUST NOT 改动账务分录、F36 不变式与余额语义;全部改动限于标记/展示/跳转层(测试:账务测试零 diff 全绿)。

## Scope boundary(exclusions + owner + 辩护)

| 排除项 | owner | 辩护(经 grill) |
|---|---|---|
| bound 置位 + proto 透传 | 未来卡贷 bound 支持票 | 决策 1(2026-10-09):绑定场景未到,与卡贷 bound 半成品现状自洽;server 线 pivot 暂停 |
| 镜像保留 isSystem(选项 A) | 否决 | 决策 1:单设备持续隐藏/多设备分裂的最差中间态 |
| parentId 激活 | R17 立项 | YAGNI:载体挂接靠 collectionAccountId 已闭环 |
| 额度口径 / 预设层 | F50 / F52 | R17 独立票 |
| 独立账单账户任何隐藏逻辑 | 本 spec 语义边界 | e招贷账户=真实账户(账单面板/repayBill 载体),隐藏即坏 |

## Grill record

- **决策 1 镜像抹除**:挑战「保留隐藏 vs 绑定后可见 vs proto 透传」三向;辩:B 与卡贷 bound 半成品现状自洽、C 归未来票、A 多设备分裂;用户裁决 **B**(2026-10-09)。
- **决策 2 存量识别+孤儿**:挑战「语义识别+孤儿可见 vs 名称匹配 vs 系统代清理」;用户裁决**一次性清理**(语义标记 + notes/零余额/无账单日判别的孤儿关闭)。
- **决策 3 贷款组小计**:挑战 (a)含载体 (b)纯剔除 (c)剔除+汇总行;用户裁决 **c + 跳转债务详情/规划**。**修订(2026-10-10,看 v11 原型后)**:汇总行否决——分期可见性挂到卡本身:卡面摘要(N 笔+总额)+ 卡详情分期明细与债务关联(FR-4 改写);贷款组回归纯可见行小计。
- **延伸 FR-5**:由决策 2 清理偏好延伸(债删归零自动关载体户),spec 确认时用户知情保留。

## Feasibility(2026-10-09)

- **技术:可行**——改动面全踩点(建户布尔/repair 六先例/过滤查询+汇总行+跳转),零 schema/proto;暗礁两处已处置(镜像抹除=NFR-1 边界;envelope 备份往返=execute 核验)。
- **经济:可行**——六故事小票,即刻兑现银行镜像一致性。
- **运营:可行**——迁移仅幂等 repair,e2e 回归面现成,零 server 依赖。
