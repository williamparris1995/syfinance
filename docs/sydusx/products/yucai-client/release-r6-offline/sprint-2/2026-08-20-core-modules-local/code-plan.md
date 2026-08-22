# Code Plan — feature D 核心记账模块本地化

> 消费 spec+design(均 confirmed)。inline 模式(C 范式复制 + transaction 重头)。

## Tasks
- [x] T1 tag:local ds(在 repo 文件内,7 方法含 junction)+ repo 路由 + guard 透传
- [x] T2 transaction:local ds 9 方法(Simple* 方向表/嵌套事务/整包替换/offset 分页/summary CASE 口径+dailyAvg 规则)+ DAO 补 getAll*/deleteEntriesByTransaction + repo 路由
- [x] T3 template:local ds(record 联动=drift 事务内建交易+AdvanceNextDate 照抄+version/lastTxnId;direction/cycle 枚举含 unspecified=index 直映射[非 +1])+ repo 路由
- [x] T4 currency:local ds(静态种子 ~10 币种幂等播种)+ repo 路由+guard 升级 + CurrencyBloc guest 分支(preferred=本位币/interval=24/零 RPC)
- [x] T5 测试:transaction(方向 oracle/事务前校验/整包替换/乐观锁/分页/summary 口径 7 例)+ template(record 各 cycle/暂停/乐观锁/transfer 校验 6 例)+ currency(种子幂等/guest 分支 2 例)+ 既有 4 模块测试 harness 更新;全套 +1044 -4(=基线,零新增);analyze 377 < main 398(dart fix 范围内清理,范围外文件已回滚)

## 执行记录(2026-08-22)
- 编译修复轮:TagsCompanion Value 包装/TransactionEntry 双侧必填/RecordResult.nextDate 为 DateTime?/行类名冲突(app_database `as db`/测试 hide)/inferFlavour 启发式断言修正(balanced 2 条恒 transfer)。
- 枚举映射修正:template direction/cycle 含 unspecified(proto 0)→ index 直映射;account 四枚举无 unspecified → index+1(C 既有规则)。两类并存,review 时重点核对。
- FR-4 边界同 C:被改类(repo/bloc)自身测试 harness 随构造器更新;bloc/page 断言零改动。

## Review 修复轮(2026-08-22,首轮 reject:1 BLOCKER)

- **H1(DI)**:四 local ds 漏 @LazySingleton → 注解 + 重新生成(injection.config 现有 4 个 provider)——与 C 的 Uuid 同类:测试手工构造掩盖。
- **template create 语义修正**:startDate 生效 + nextDate=CalculateNextDate 照抄(weekly+7d/monthly addMonthsClamped·billingDay 优先/yearly+1y/**custom=+1d server default daily**/unspecified+1m)+ create 四项校验镜像(空名/金额≤0/方向·周期未指定)。
- **transaction**:Σdebit==Σcredit 平衡校验(DoubleEntryValidator 镜像)+测试;update description 对齐远端 full-replace(死代码清理);year bucket 键 'YYYY-MM-01'(可 parse)。
- **currency**:种子播种包单事务(防残缺)。
- **路由测试 ×4**(FR-6 缺口):tag/template/transaction(含切换)/currency guest 走本地零远端调用。
- **spec 勘误 ×2**:currency guard 分类细化=有意变更(原裸 catch 是欠账);list 本地自定义 date-desc 排序(远端 id-ASC keyset,有意选择)。
- **deferred(记档)**:J2 guard×5 提取 core 共享(→ refactor on-demand);J3 guest 记账不联动账户余额(**feature F 明文 scope**:「transaction+账户余额为原子性 oracle」);J4 tag junction 错型/重复打标与 getTransactionTags N+1(→F/E);account_local_ds 3 处越界 const 化(行为等价,留着)。
- 修复后:全套 +1048 -4(=基线,零新增);analyze 382 < main 398。

## Review + Test(2026-08-22,pass)

- 首轮 reject(1 BLOCKER:四 local ds DI 缺注册)→ 修复(template create 语义/平衡校验/种子事务/路由测试×4/spec 勘误×2)→ 复审 **pass**(server 源码逐行对照:CalculateNextDate/addMonthsClamped/方向表/CASE 口径全镜像核实)。
- Test 裁决:**pass** — 全套 +1048 -4(=基线 4,零新增);analyze 382 < main 398;requirement coverage:FR-1 tag oracle/FR-2 template record·create 语义/FR-3 方向·事务·分页·平衡校验/FR-4 summary oracle/FR-5 种子·bloc 分支/FR-6 路由×4+零改动回归/NFR-1·2 实测。
- **LOW 残留(记档)**:本地 update 未复跑平衡校验(唯一 UI 调用方恒产平衡对+router 挡复合交易,实际不可达;后续 refactor 提共享 helper 顺带补)。
