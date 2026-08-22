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
