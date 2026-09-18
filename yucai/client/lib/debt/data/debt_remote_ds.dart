import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/debt/data/mappers/debt_mapper.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;
import 'package:yucai_client/proto/common/v1/recurrence.pbenum.dart' as pbcommon;
import 'package:yucai_client/proto/debt/v1/debt.pb.dart' as pb;
import 'package:yucai_client/proto/debt/v1/debt.pbgrpc.dart' as grpc;

/// Wraps the generated DebtServiceClient. Throws GrpcError on failure (caught
/// and mapped by the repo layer). Mirrors AccountRemoteDataSource: every RPC
/// is wrapped in AuthRetryCaller so a 401 triggers a transparent refresh +
/// single retry.
///
/// 7 RPCs: list / get / create / update / delete / recordPayment /
/// upcomingPayments.
///
/// AmortizationMethod off-by-one: proto values are 0=UNSPECIFIED, 1-3 = the
/// three methods, while domain AmortizationMethod indices are 0-2. We therefore
/// translate by NAME via DebtMapper.amortToProto(AmortizationMethod.values[i])
/// on create — NOT by passing the index straight to proto (which would land on
/// UNSPECIFIED for index 0 and be off-by-one elsewhere).
/// 远端调用统一超时:绑定态服务器不可达且连接静默挂起时,若无 deadline
/// 则写操作永远 pending(表单转圈)。超时抛 GrpcError(unavailable) →
/// writeWithFallback 自动降级本地(pending 上行)。
const Duration kDebtRemoteTimeout = Duration(seconds: 15);

@LazySingleton()
class DebtRemoteDataSource {
  DebtRemoteDataSource(this._grpcClient, this._retry) {
    _client = grpc.DebtServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;

  Future<T> _retryWithTimeout<T>(Future<T> Function() op) =>
      _retry.call(() => op().timeout(kDebtRemoteTimeout,
          onTimeout: () => throw GrpcError.unavailable()));
  late final grpc.DebtServiceClient _client;

  Future<List<Debt>> list({DebtType? typeFilter}) async {
    return _retryWithTimeout(() async {
      final res = await _client.listDebts(pb.ListDebtsRequest(
        page: common.PageRequest(pageSize: 100),
        typeFilter: typeFilter == null
            ? null
            : DebtMapper.debtTypeToProto(typeFilter),
      ));
      return res.debts.map(DebtMapper.toDomain).toList();
    });
  }

  Future<DebtDetail> get(String id) async {
    return _retryWithTimeout(() async {
      final res = await _client.getDebt(pb.GetDebtRequest(id: id));
      final d = res.debt;
      return DebtDetail(
        debt: DebtMapper.toDomain(d.debt),
        schedule: d.schedule.map(DebtMapper.paymentEntryToDomain).toList(),
      );
    });
  }

  Future<Debt> create({
    required String accountId,
    required String counterparty,
    required double interestRate,
    required int amortizationIndex,
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
  }) async {
    return _retryWithTimeout(() async {
      final res = await _client.createDebt(pb.CreateDebtRequest(
        accountId: accountId,
        counterparty: counterparty,
        interestRate: interestRate,
        amortizationMethod: DebtMapper.amortToProto(
          AmortizationMethod.values[amortizationIndex],
        ),
        startDate: _fmtDate(startDate),
        dueDate: _fmtDate(dueDate),
        totalPrincipalCents: Int64(totalPrincipalCents),
        debtType: DebtMapper.debtTypeToProto(type),
        // subtype 纯 String 直传(无映射),默认 '' 与 domain Debt.subtype 默认一致。
        subtype: subtype,
        // source_account_id:borrowedOut 双写资金来源(cash asset);borrowedIn
        // 或未选 → '' → 后端不双写。
        sourceAccountId: sourceAccountId ?? '',
        // receivables 对齐字段(Task 11):自由文本直传 + collection_account_id
        // 空串 = 未关联(borrowedOut 服务端强制,客户端 form 已先校验)。
        contact: contact,
        contractRef: contractRef,
        // 担保人字段(2026-09 用户需求):自由文本直传,'' = 无。
        guarantorName: guarantorName,
        guarantorContact: guarantorContact,
        collectionAccountId: collectionAccountId ?? '',
        cycle: pbcommon.RecurrenceCycle.valueOf(cycle) ??
            pbcommon.RecurrenceCycle.RECURRENCE_CYCLE_MONTHLY,
        interval: interval,
        weekdayMask: weekdayMask,
        monthlyMode: monthlyMode == 1
            ? pbcommon.RecurrenceMonthlyMode.MONTHLY_MODE_BY_NTH_WEEKDAY
            : pbcommon.RecurrenceMonthlyMode.MONTHLY_MODE_BY_DATE,
        nth: nth,
        termPeriods: termPeriods,
        interestWaivedCents: Int64(interestWaivedCents),
      ));
      return DebtMapper.toDomain(res.debt);
    });
  }

  Future<Debt> update({
    required String id,
    required String counterparty,
    required double interestRate,
    required int version,
    // F33-T4:空串 = 不修改(新旧 client 兼容;proto3 string 无 presence,
    // '' 即服务端 UpdateDebt 的「保持现状」信号,与本地守卫同语义)。
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
  }) async {
    return _retryWithTimeout(() async {
      final res = await _client.updateDebt(pb.UpdateDebtRequest(
        id: id,
        counterparty: counterparty,
        interestRate: interestRate,
        version: Int64(version),
        // F33-T4:subtype 字段 19(regen 已有),空串 = 不修改。
        subtype: subtype,
        // receivables 对齐字段(Task 11):空字符串清字段,collection_account_id
        // 空串 = 解除关联(对齐服务端 UpdateDebt 语义)。担保人字段同语义
        //(2026-09):空串清字段。
        contact: contact,
        contractRef: contractRef,
        guarantorName: guarantorName,
        guarantorContact: guarantorContact,
        collectionAccountId: collectionAccountId ?? '',
        // 影响期次的编辑(0/空 = 保持现状,旧调用方行为不变)。
        amortizationMethod: amortizationIndex == null
            ? pb.AmortizationMethod.AMORTIZATION_UNSPECIFIED
            : DebtMapper.amortToProto(
                AmortizationMethod.values[amortizationIndex]),
        dueDate: dueDate == null ? '' : _fmtDate(dueDate),
        termPeriods: termPeriods,
        cycle: cycle == null
            ? pbcommon.RecurrenceCycle.RECURRENCE_CYCLE_UNSPECIFIED
            : pbcommon.RecurrenceCycle.valueOf(cycle) ??
                pbcommon.RecurrenceCycle.RECURRENCE_CYCLE_MONTHLY,
        interval: interval ?? 0,
        weekdayMask: weekdayMask ?? 0,
        monthlyMode: (monthlyMode ?? 0) == 1
            ? pbcommon.RecurrenceMonthlyMode.MONTHLY_MODE_BY_NTH_WEEKDAY
            : pbcommon.RecurrenceMonthlyMode.MONTHLY_MODE_BY_DATE,
        nth: nth ?? 0,
        // presence-aware:nil = 保持现状;set = 替换(0 清零)。
        interestWaivedCents:
            interestWaivedCents == null ? null : Int64(interestWaivedCents),
      ));
      return DebtMapper.toDomain(res.debt);
    });
  }

  /// 标记已还(历史还款,不记账)。
  Future<PaymentEntry> markEntryPaid({
    required String debtId,
    required String entryId,
  }) async {
    return _retryWithTimeout(() async {
      final res = await _client.markEntryPaid(pb.MarkEntryPaidRequest(
        debtId: debtId,
        entryId: entryId,
      ));
      return DebtMapper.paymentEntryToDomain(res.entry);
    });
  }

  Future<void> delete(String id) async {
    return _retryWithTimeout(() async {
      await _client.deleteDebt(pb.DeleteDebtRequest(id: id));
    });
  }

  Future<PaymentEntry> recordPayment({
    required String debtId,
    required String scheduleEntryId,
    required String fromAccountId,
  }) async {
    return _retryWithTimeout(() async {
      final res = await _client.recordPayment(pb.RecordPaymentRequest(
        debtId: debtId,
        scheduleEntryId: scheduleEntryId,
        fromAccountId: fromAccountId,
      ));
      return DebtMapper.paymentEntryToDomain(res.entry);
    });
  }

  /// 单期改日(Google-Calendar 式;冻结期次服务端拒绝)。
  Future<PaymentEntry> setPaymentDate({
    required String debtId,
    required String entryId,
    required DateTime paymentDate,
  }) async {
    return _retryWithTimeout(() async {
      final res = await _client.setPaymentDate(pb.SetPaymentDateRequest(
        debtId: debtId,
        entryId: entryId,
        paymentDate: _fmtDate(paymentDate),
      ));
      return DebtMapper.paymentEntryToDomain(res.entry);
    });
  }

  Future<List<Debt>> upcomingPayments(int daysAhead) async {
    return _retryWithTimeout(() async {
      final res = await _client.getUpcomingPayments(
          pb.GetUpcomingPaymentsRequest(daysAhead: daysAhead));
      return res.debts.map(DebtMapper.toDomain).toList();
    });
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
