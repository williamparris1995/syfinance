import 'package:fixnum/fixnum.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/debt/data/mappers/debt_mapper.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;
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
  late final grpc.DebtServiceClient _client;

  Future<List<Debt>> list() async {
    return _retry.call(() async {
      final res = await _client.listDebts(pb.ListDebtsRequest(
        page: common.PageRequest(pageSize: 100),
      ));
      return res.debts.map(DebtMapper.toDomain).toList();
    });
  }

  Future<DebtDetail> get(String id) async {
    return _retry.call(() async {
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
  }) async {
    return _retry.call(() async {
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
      ));
      return DebtMapper.toDomain(res.debt);
    });
  }

  Future<Debt> update({
    required String id,
    required String counterparty,
    required double interestRate,
    required int version,
  }) async {
    return _retry.call(() async {
      final res = await _client.updateDebt(pb.UpdateDebtRequest(
        id: id,
        counterparty: counterparty,
        interestRate: interestRate,
        version: Int64(version),
      ));
      return DebtMapper.toDomain(res.debt);
    });
  }

  Future<void> delete(String id) async {
    return _retry.call(() async {
      await _client.deleteDebt(pb.DeleteDebtRequest(id: id));
    });
  }

  Future<PaymentEntry> recordPayment({
    required String debtId,
    required String scheduleEntryId,
    required String fromAccountId,
  }) async {
    return _retry.call(() async {
      final res = await _client.recordPayment(pb.RecordPaymentRequest(
        debtId: debtId,
        scheduleEntryId: scheduleEntryId,
        fromAccountId: fromAccountId,
      ));
      return DebtMapper.paymentEntryToDomain(res.entry);
    });
  }

  Future<List<Debt>> upcomingPayments(int daysAhead) async {
    return _retry.call(() async {
      final res = await _client.getUpcomingPayments(
          pb.GetUpcomingPaymentsRequest(daysAhead: daysAhead));
      return res.debts.map(DebtMapper.toDomain).toList();
    });
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
