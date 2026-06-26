import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart' as tspb;

import 'package:yucai_client/core/network/auth_interceptor.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/debt/data/debt_remote_ds.dart';
import 'package:yucai_client/debt/data/mappers/debt_mapper.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;
import 'package:yucai_client/proto/debt/v1/debt.pb.dart' as pb;

class _MockGrpcClient extends Mock implements GrpcClient {}

pb.DebtDTO _dto(String id, {int amort = 1}) => pb.DebtDTO(
      id: id,
      accountId: 'acc-1',
      counterparty: 'Bank',
      interestRate: 5.0,
      amortizationMethod: pb.AmortizationMethod.valueOf(amort)!,
      startDate: '2026-01-01',
      dueDate: '2027-01-01',
      totalPrincipalCents: Int64(100000),
      remainingPrincipalCents: Int64(100000),
      version: Int64(1),
      createdAt: tspb.Timestamp.fromDateTime(DateTime(2026, 1, 1)),
      updatedAt: tspb.Timestamp.fromDateTime(DateTime(2026, 1, 1)),
    );

void main() {
  late _MockGrpcClient grpcClient;
  late AuthRetryCaller retry;

  setUp(() {
    grpcClient = _MockGrpcClient();
    retry = AuthRetryCaller();
    registerFallbackValue(pb.ListDebtsRequest());
    registerFallbackValue(pb.CreateDebtRequest());
    registerFallbackValue(common.PageRequest());
  });

  // The real DebtRemoteDataSource constructs its own DebtServiceClient from
  // GrpcClient.channel + authInterceptor (mirrors AccountRemoteDataSource), so
  // we cannot substitute a mock gRPC client through DI. We instead verify the
  // mapper pipeline that the DS delegates to — the DS is a thin wrapper, so the
  // mapping (incl. the off-by-one AmortizationMethod handling) is the only
  // non-trivial logic it carries.

  test('list() pipeline maps 2 DebtDTO → 2 Debt via DebtMapper.toDomain',
      () async {
    final dtos = [_dto('d1'), _dto('d2')];
    final debts = dtos.map(DebtMapper.toDomain).toList();
    expect(debts, isA<List<Debt>>());
    expect(debts.length, 2);
    expect(debts.first.id, 'd1');
    expect(debts.first.amortization, AmortizationMethod.equalPrincipalInterest);
  });

  test(
      'create() maps AmortizationMethod by name to fix proto off-by-one '
      '(domain 0-2 → proto 1-3)', () {
    expect(
      DebtMapper.amortToProto(AmortizationMethod.values[0]),
      pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL_INTEREST,
    );
    expect(
      DebtMapper.amortToProto(AmortizationMethod.values[1]),
      pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL,
    );
    expect(
      DebtMapper.amortToProto(AmortizationMethod.values[2]),
      pb.AmortizationMethod.AMORTIZATION_LUMP_SUM,
    );
  });

  test('get() pipeline maps DebtDetailDTO → DebtDetail (debt + schedule)',
      () async {
    final detail = pb.DebtDetailDTO(
      debt: _dto('d1'),
      schedule: [
        pb.PaymentEntryDTO(
          id: 'p1',
          paymentDate: '2026-02-01',
          principalCents: Int64(8000),
          interestCents: Int64(400),
          totalCents: Int64(8400),
          paid: false,
          paidCents: Int64(0),
          transactionId: '',
        ),
      ],
    );
    final mapped = DebtDetail(
      debt: DebtMapper.toDomain(detail.debt),
      schedule: detail.schedule.map(DebtMapper.paymentEntryToDomain).toList(),
    );
    expect(mapped.debt.id, 'd1');
    expect(mapped.schedule.length, 1);
    expect(mapped.schedule.first.totalCents, 8400);
  });

  test('recordPayment pipeline maps RecordPaymentResponse.entry → PaymentEntry',
      () {
    final res = pb.RecordPaymentResponse(
      entry: pb.PaymentEntryDTO(
        id: 'p1',
        paymentDate: '2026-02-01',
        principalCents: Int64(8000),
        interestCents: Int64(400),
        totalCents: Int64(8400),
        paid: true,
        paidCents: Int64(8400),
        transactionId: 'tx-1',
      ),
    );
    final entry = DebtMapper.paymentEntryToDomain(res.entry);
    expect(entry.paid, isTrue);
    expect(entry.transactionId, 'tx-1');
  });

  test('DebtRemoteDataSource is constructible with GrpcClient + retry', () {
    // The DS constructor eagerly builds a DebtServiceClient from
    // GrpcClient.channel + authInterceptor — stub both so construction succeeds.
    // A real ClientChannel is cheap to construct and never connects until a
    // call is made (which we don't make here).
    when(() => grpcClient.channel)
        .thenReturn(ClientChannel('localhost', port: 9999));
    when(() => grpcClient.authInterceptor).thenReturn(AuthInterceptor());
    final ds = DebtRemoteDataSource(grpcClient, retry);
    expect(ds, isA<DebtRemoteDataSource>());
  });
}
