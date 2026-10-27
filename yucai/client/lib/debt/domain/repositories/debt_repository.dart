import 'package:dartz/dartz.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/debt/domain/bank_plan_parser.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

abstract class DebtRepository {
  /// 列出债务。`typeFilter` 非空时只返回该方向(borrowedIn / borrowedOut)。
  Future<Either<Failure, List<Debt>>> list({DebtType? typeFilter});
  Future<Either<Failure, DebtDetail>> get(String id);
  Future<Either<Failure, Debt>> create({
    required String accountId,
    required String counterparty,
    required double interestRate,
    required int amortizationIndex, // AmortizationMethod.index
    required DateTime startDate,
    required DateTime dueDate,
    required int totalPrincipalCents,
    required DebtType type,
    String subtype = '',
    String? sourceAccountId,
    String contact = '',
    String contractRef = '',
    String guarantorName = '',
    String guarantorContact = '',
    String? collectionAccountId,
    int cycle = 2,
    int interval = 1,
    int weekdayMask = 0,
    int monthlyMode = 0,
    int nth = 0,
    int termPeriods = 0,
    int interestWaivedCents = 0,
    // 卡贷(F48):月度账单日锚点(0=锚起始日)+ 每期固定手续费(分,
    // 0=常规摊销)。guest-local v1 —— proto CreateDebtRequest 无对应字段,
    // bound 路由不透传(见 DebtRepositoryImpl 注)。
    int billingDay = 0,
    int flatFeeCents = 0,
    // F50 债级开关:剩余本金是否计入挂接卡额度占用(默认 true;本地私有
    // 列,remote 不透传,见 DebtRepositoryImpl 注)。
    bool countsTowardCardLimit = true,
    // 信用卡分期重构:负债余额已含本金,跳过开账双写(否则欠款翻倍)。
    // 仅 borrowedIn;与 sourceAccountId 互斥。
    bool restructureOnly = false,
    // F57 首期锚点(卡贷并入模式):true = 放款当期起扣(平安口径,首期 =
    // 放款日当天);false(默认)= 放款次月(现状)。**生成期参数** —— 仅
    // local DS 消费(物化进期表日期,不持久化,零 drift 列/零 proto;remote
    // 不透传,见 DebtRepositoryImpl 注)。
    bool firstPeriodFromDisbursement = false,
  });
  Future<Either<Failure, Debt>> update({
    required String id,
    required String counterparty,
    required double interestRate,
    required int version,
    // F33-T4:空串 = 不修改(新旧 client 兼容),守卫在 DS 层。
    String subtype = '',
    String contact = '',
    String contractRef = '',
    String guarantorName = '',
    String guarantorContact = '',
    String? collectionAccountId,
    int? amortizationIndex,
    DateTime? dueDate,
    int termPeriods = 0,
    int? cycle,
    int? interval,
    int? weekdayMask,
    int? monthlyMode,
    int? nth,
    int? interestWaivedCents,
    // F50 债级开关:编辑保存写入(默认 true;表单加载已回填既有值,非
    // 卡贷路径恒原值)。本地私有列,remote 不透传。
    bool countsTowardCardLimit = true,
  });
  Future<Either<Failure, void>> delete(String id);

  /// 标记已还(历史还款,不记账;已还期次拒绝)。
  Future<Either<Failure, PaymentEntry>> markEntryPaid({
    required String debtId,
    required String entryId,
  });
  /// 记账还款。[subsidyCents]/[subsidyAccountId] = 财政贴息(政策性利息
  /// 补贴,仅借入债):>0 时三腿分录 —— 借债务(期表全额)/ 贷还款账户
  /// (净额)/ 贷补贴收入账户(贴息)。远端 proto 无补贴字段,>0 时由
  /// 实现层拦截报错。
  Future<Either<Failure, PaymentEntry>> recordPayment({
    required String debtId,
    required String scheduleEntryId,
    required String fromAccountId,
    int subsidyCents = 0,
    String? subsidyAccountId,
  });

  /// 导入银行还款计划(v15):按日期覆写未还期次的本金/利息/优惠
  /// (已还冻结)。远端路由暂不支持(proto 无期表优惠字段)。
  Future<Either<Failure, ({int applied, List<DateTime> noMatch, int skippedPaid})>>
      importBankSchedule({
    required String debtId,
    required List<BankPlanRow> rows,
  });

  /// 账单制整单还款(独立账单卡贷,如 e招贷):周期内全部到期未还期次
  /// 合并为一笔还款交易并批量标记已还 —— 镜像银行「X日出账、Y日前
  /// 一次还清」。远端无批量 RPC,退化为逐期还款(合计口径一致)。
  Future<Either<Failure, void>> repayBill({
    required String loanAccountId,
    required List<({String debtId, String entryId})> items,
    required String fromAccountId,
    String? description,
  });

  /// 单期改日(未还期次;已还期次冻结,目标日期撞已有期次会被拒绝)。
  Future<Either<Failure, PaymentEntry>> setPaymentDate({
    required String debtId,
    required String entryId,
    required DateTime paymentDate,
  });
  Future<Either<Failure, List<Debt>>> upcomingPayments(int daysAhead);
}
