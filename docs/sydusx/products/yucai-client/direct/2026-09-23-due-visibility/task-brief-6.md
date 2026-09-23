# Task T7(fix)— 信用卡到期金额改上期账单口径

用户验收报告:还款日提醒的金额把**本周期未出账消费**计入;领域规则=还款日应还的是
**上期账单**。行业实践(银行/支付宝/Chase)统一:应还=账单口径,与当前总欠款分开。
本票修:①提醒金额源(单一修点,toast/聚合条/收件箱全继承);②还款对话框基数
(用户拍板「一起改对齐」)。

项目:御财 Flutter 客户端 `yucai/client/`。相关文档:
`docs/sydusx/products/yucai-client/direct/2026-09-23-due-visibility/`(本 feature 上下文)。

## 现状事实(已核实)

- `core/notifications/credit_card_due_source.dart`:候选金额=卡 `currentBalanceCents`
  (总欠款),候选条件=余额>0。
- 卡实体/表已有 `creditBillingDay`(账单日 1-31,可空,表单可编辑)。
- 分录表 `TransactionEntries{id, transactionId, accountId, chartOfAccountCode,
  debitCents, creditCents}`;日期在 `Transactions.transactionDate`(join 取)。
- 负债方向规则:`accountType` liability(2)→ `credit − debit`
  (`transaction/data/balance_updater.dart` `_entryDelta`,照抄自 server 规则——
  本任务在 core 内**内联同规则+注释同源声明**,core 不 import transaction 模块)。
- 信用卡卡种判定:category=credit_card(due source 里 `_kCreditCardCategoryCode=2`);
  欠款 credit-正。

## 交付物

1. **共享推导**(新文件 `lib/core/notifications/credit_card_statement.dart`):
   `CreditCardStatementDue.compute({required AppDatabase db, required String accountId,
   required int accountType, required int currentBalanceCents, int? billingDay,
   DateTime Function() clock})` → `Future<int>`(上期账单应还,分):
   - billingDay == null → 直接返回 currentBalanceCents(降级=现状,注释钉死);
   - 最近已过账单日 D = ≤今天的最近账单日(月长 clamp 照 due source `_clampDay`
     先例,可提为共享静态);
   - Δ = Σ(该卡 TransactionEntries join Transactions,`transactionDate > D` 且 ≤ 今日
     末)× 负债方向(credit−debit;消费为正、还款为负);
   - 应还 = max(0, currentBalanceCents − Δ);**账单日当天消费算已出账**(date>D 严格,
     注释声明口径,各行账单日当天归属不同,按此默认)。
   - 时钟注入可测。此计算**只读**,不动余额。
2. **CreditCardDueSource 改造**:每卡应还 = 共享推导;**应还 ≤ 0 → 不产候选**
   (还清上期账单后即使本周期有消费也不再催——用户领域规则);候选 totalCents=应还
   (billingDay null 降级现状);overdue 金额同步=应还。窗口/entryId/clamp 逻辑不动。
3. **还款对话框对齐**(`account/presentation/widgets/credit_card_repay_dialog.dart`):
   全额基数=共享推导的应还(账单日已设,文案「全额(上期账单)」;未设降级=当前欠款,
   文案「全额」维持);最低=应还×10%;分期基数=应还。对话框经共享推导与提醒源
   **同一数字**(account→core import 合法)。金额只读态/余额不足拦截同步基数。
4. **测试**(TDD 先红后绿):
   - 推导:消费在账单日后剔除/还款冲减/应还 clamp 0/账单日 null 降级/跨月 clamp/
     账单日当天消费算已出账/空交易(纯手工余额)Δ=0;
   - 源:应还>0 才候选(本周期消费-only 卡不出候选)/金额=应还/降级路径/overdue 金额;
   - 对话框:全额基数与标签两形/最低 10% 基数/与源同数(同 fixture 断言相等)。
   - 修既有源测试的口径断言(原断言金额=总欠款的改为账单口径——是本票目的,注明)。

## 约束

- 中文注释;core 不 import feature 模块;不改还款记账分录语义(还多少记多少);
- 不动 banner/inbox/tray(消费同一 DueScheduleEntry,自动正);
- 既有 2028 测全绿 + analyze 净增 0。

## 完成门

1. `flutter test`(全量)全绿;2. `flutter analyze` 净增 0;
3. 最终回复:文件清单、测试数字、口径规则清单(含账单日当天归属)、偏离裁决。
