import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/debt/data/receivables_summary_mapper.dart';
import 'package:yucai_client/proto/debt/v1/debt.pb.dart' as pb;

// ReceivablesSummaryDataSource 是 GrpcClient.channel + authInterceptor 自建
// DebtServiceClient 的薄壳(对齐 GoalViewDataSource / DebtRemoteDataSource),
// 无法通过 DI 替换真正的 gRPC client。此处验证它委托的 mapper 管线 —— DS
// 仅有的非平凡逻辑就是把 response.summary 喂给 receivablesSummaryDtoToEntity。
// (与 debt_remote_ds_test.dart 同款策略:测 mapper 管线,不测真实 gRPC。)
void main() {
  test('fetch() pipeline maps response.summary via mapper (full DTO)', () {
    final summary = pb.ReceivablesSummaryDTO(
      totalPrincipalCents: $fixnum.Int64(1000000),
      totalRemainingCents: $fixnum.Int64(600000),
      totalCollectedCents: $fixnum.Int64(400000),
      pendingInterestCents: $fixnum.Int64(12000),
      count: 5,
      overdueCount: 1,
      overdueAmountCents: $fixnum.Int64(50000),
      principalTrendCents: $fixnum.Int64(1000000),
      remainingTrendCents: $fixnum.Int64(600000),
      nextPaymentDate: '2026-08-01',
      nextPaymentAmountCents: $fixnum.Int64(25000),
      nextPaymentCounterparty: '张三',
      nextPaymentPeriodNo: 3,
    );
    final entity = receivablesSummaryDtoToEntity(summary);
    expect(entity.totalPrincipalCents, 1000000);
    expect(entity.overdueCount, 1);
    expect(entity.nextPaymentDate, DateTime(2026, 8, 1));
    expect(entity.nextPaymentCounterparty, '张三');
  });

  test('fetch() pipeline tolerates default (empty) summary', () {
    final entity = receivablesSummaryDtoToEntity(pb.ReceivablesSummaryDTO());
    expect(entity.totalPrincipalCents, 0);
    expect(entity.nextPaymentDate, isNull);
    expect(entity.progressPct, 0);
  });
}
