# Task Brief T3 — 三只读工具 + 口径逐分断言

## 工作区与铁律

- **只在 worktree 工作**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r22-f64`(分支 feature/r22-f64;T1 的 domain 契约已在)。shell 先 cd worktree 根。
- **TDD**;不碰 `yucai/server/`、F46 `core/llm/`、其他模块的业务代码(例外见下「F50 占用」与「debts mapper」两处锁定豁免)。
- 完成 `git commit`(`feat(assistant): F64-T3 首批只读工具三件+口径断言`)。

## 必读

1. 同目录 `spec.md`(FR-2/NFR-1/NFR-2 场景)+`design.md`(LLD 三工具 schema/口径段,ADR-6/ADR-8)
2. `yucai/client/lib/account/domain/`:repositories/account_repository.dart、account_visibility.dart、entities/account_entity.dart
3. `yucai/client/lib/debt/domain/`:repositories/debt_repository.dart、entities/debt_entity.dart
4. `yucai/client/lib/holding/domain/entities/net_worth_entity.dart` + `lib/holding/data/holding_local_ds.dart` 的 NetWorthLocalDataSource(仅读注释理解口径,**不 import 它**——工具走 assistant/domain 的 NetWorthSnapshotSource port)
5. 测试基建:在 `yucai/client/test/` 里 grep `AppDatabase(` 找 drift 测试库构造方式(内存库/临时文件),照既有 repository_impl 或 dao 测试范式建种子数据

## 任务:三个 AssistantTool 实现(`yucai/client/lib/assistant/data/tools/`)

通用:实现 T1 的 `AssistantTool`;输入校验宽松分页(`page`≥1 缺省 1,`page_size` 1..50 缺省 20);返回 `ToolData` JSON,**每个金额字段双口径**:`xxxCents`(int)+`xxxYuan`(String,两位小数,复用既有千分位格式化助手——grep `formatCents` 或等价;若助手在 presentation 层则引 core 里已有的等价纯函数,找不到就把 cents→元字符串的小函数放 assistant/data 内部并加注释);金额断言逐分(NFR-1)。

1. **networth_snapshot_tool**(name=networth_snapshot,无参):注入 `NetWorthSnapshotSource` + CurrencySettings 的 baseCurrency 获取(grep `getBaseCurrency` 找 API;与 home 大卡同源)。输出:{totalAssetsCents,totalLiabilitiesCents,netWorthCents,currency,formatted{三值元字符串},asOf(ISO8601)}。
2. **accounts_list_tool**(name=accounts_list,参数{kind?,page?,page_size?}):注入 `AccountRepository`。流程:list()→**AccountVisibility 过滤(载体户出局,total_count 不计)**→kind 过滤(枚举对齐 AccountType 值域,非法 kind→ToolError 自纠消息列合法值)→分组汇总(按类型:每组 {count, subtotalCents})→页片({name, type, balanceCents, balanceYuan})+信用卡类每卡 {usedCents(=卡欠款+Σ「计入开关开」挂接卡贷剩余本金), availableCents}。**F50 占用派生定位**:先 `git show 90a2a6bf --stat` 找 F50 落点再 grep 派生函数;若派生在 presentation/bloc 层→把纯计算提为 `account/domain` 纯函数(锁定豁免:仅移动+导出,不改语义,原调用点改引),并在汇报中写明落点(回填 design Open Question)。
3. **debts_list_tool**(name=debts_list,参数{page?,page_size?}):注入 `DebtRepository`。list(borrowedIn)→未结清过滤(entity 状态字段,看 Debt entity)→每笔 {counterparty, remainingPrincipalCents(+元), nextPaymentAmountCents, nextPaymentDueDate(ISO 或 null), overdue(=dueDate<今天,端到端无时区抖动:纯日期比较)}+汇总{count, totalRemainingCents(+元)}。**ADR-8 策略 A 先行**:写一个「种子库→debt local DS→mapper→entity」断言测试验证 nextPaymentDate/nextPaymentAmountCents/nextPaymentDueDate 三字段实填;若 mapper 确有缺列→**锁死 debt data 层 mapper 单点补齐**(豁免范围=mapper 一处+其单测),汇报写明补了哪列。

### 口径断言测试(`yucai/client/test/assistant/data/tools/`)

参数化全工具:同一测试库种子→工具输出 vs 同库直查(repository 或 drift dao/NetWorthLocalDataSource 同算法)逐分相等;载体户不在结果且 total_count 不计;欠款正数;分页边界(超页/零结果)。

## 验证门

`flutter test test/assistant/` 全绿;`flutter analyze` 零新增;`git diff yucai/server` 空。汇报:文件清单+测试数+F50 占用落点(回填用)+mapper 补列情况(若有)。
