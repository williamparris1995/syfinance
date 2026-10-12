# F58 并账时机=到期日(平安口径)热修(用户同意 2026-10-12)
银行事实:平安现金分期每期独立出账(放款对应日),到期=下一期出账日;卡待还只含已到期未还,分期剩余不含已出账期次(自由窗口)。现 app 在出账日即并账,须改。

## T1 catchup 到期触发(debt_local_ds.dart catchupCardLoanMerges)
期次按日期升序;entry k 的到期日 = dates[k+1](末期 = 自身+1 月,月钳)。条件从 !e.paymentDate.isAfter(todayStart) 改为到期日 ≤ todayStart。注释钉银行口径。

## T2 回退修复(repairs.dart,marker f58_unmerge_overmerged_v1)
对四债(沿 runF57Ts4PingAnRedate 的 ID 清单)当前 paid 且 transactionId 非空的期次,凡「到期日 > now」者:置 unpaid/paidCents=0/transactionId=null,并**余额安全删除**其并入交易(借载体/贷卡 X 的逆:载体 currentBalance += total[credit-正欠款口径下欠款回升]、卡 currentBalance −= total;删 transaction_entries + transactions 行)。F36 不变式自然回位(balance==totalPrincipal−Σpaid)。幂等 marker。
注意方向核对:并入时载体欠款减、卡欠款加;回退相反。删行用 DAO 直删(guest 无墓碑,catchup 不写墓碑)。

## T3 占用/徽标剩余口径(debt_query.dart)
cardLoanOccupationCents 与 cardInstallmentSummary 改为只计 unpaid 且 paymentDate > now 的期次(未出账口径;注释:银行剩余不含已出账期次,已到期者经卡待还计入)。Debt 实体 remainingPrincipalCents 不动(F36 锁)。

## 测试(各自文件+回归)
catchup 三例(到期前不并/到期日并/末期+1月);修复两例(过度并入回退+幂等+余额断言);口径两例(出账日当天不计/次日记)。全量绿+analyze 基线。
