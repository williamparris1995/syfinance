import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/debt/data/receivables_summary_mapper.dart';
import 'package:yucai_client/proto/debt/v1/debt.pb.dart' as pb;

void main() {
  // 全字段填值的 DTO(Int64 cents / String date),验证 .toInt() 与 tryParse 路径。
  pb.ReceivablesSummaryDTO fullDto() => pb.ReceivablesSummaryDTO(
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

  test('receivablesSummaryDtoToEntity: full DTO maps 13 fields verbatim', () {
    final e = receivablesSummaryDtoToEntity(fullDto());
    expect(e.totalPrincipalCents, 1000000);
    expect(e.totalRemainingCents, 600000);
    expect(e.totalCollectedCents, 400000);
    expect(e.pendingInterestCents, 12000);
    expect(e.count, 5);
    expect(e.overdueCount, 1);
    expect(e.overdueAmountCents, 50000);
    expect(e.principalTrendCents, 1000000);
    expect(e.remainingTrendCents, 600000);
    expect(e.nextPaymentDate, DateTime(2026, 8, 1));
    expect(e.nextPaymentAmountCents, 25000);
    expect(e.nextPaymentCounterparty, '张三');
    expect(e.nextPaymentPeriodNo, 3);
  });

  test('Int64 cents -> int (.toInt(), not Int64 leak)', () {
    // 御财惯例:cents 必须落 int,否则 UI 渲染 / 序列化类型错位。
    final e = receivablesSummaryDtoToEntity(fullDto());
    expect(e.totalPrincipalCents, isA<int>());
    expect(e.overdueAmountCents, isA<int>());
    expect(e.nextPaymentAmountCents, isA<int>());
    expect(e.remainingTrendCents, isA<int>());
  });

  test('empty nextPaymentDate -> null (not throw)', () {
    final dto = fullDto()..nextPaymentDate = '';
    expect(receivablesSummaryDtoToEntity(dto).nextPaymentDate, isNull);
  });

  test('malformed nextPaymentDate -> null (tryParse, not throw)', () {
    // date-only string 服务端约定 ISO yyyy-MM-dd,但 tryParse 容错:解析失败
    // 落 null,不抛异常(与 mapper 注释一致)。
    final dto = fullDto()..nextPaymentDate = 'not-a-date';
    expect(receivablesSummaryDtoToEntity(dto).nextPaymentDate, isNull);
  });

  test('default DTO (all zero/empty) maps without throwing', () {
    // 服务端 summary 为空时返回全默认 DTO;mapper 必须稳定产出 entity。
    final e = receivablesSummaryDtoToEntity(pb.ReceivablesSummaryDTO());
    expect(e.totalPrincipalCents, 0);
    expect(e.totalRemainingCents, 0);
    expect(e.totalCollectedCents, 0);
    expect(e.count, 0);
    expect(e.nextPaymentDate, isNull);
    expect(e.nextPaymentCounterparty, '');
    expect(e.nextPaymentPeriodNo, 0);
  });

  test('progressPct: collected / (collected + remaining)', () {
    final e = receivablesSummaryDtoToEntity(fullDto());
    // 400000 / (400000 + 600000) = 0.4
    expect(e.progressPct, closeTo(0.4, 1e-9));
  });

  test('progressPct is 0 when denom <= 0 (avoid divide-by-zero)', () {
    final e = receivablesSummaryDtoToEntity(pb.ReceivablesSummaryDTO());
    expect(e.progressPct, 0);
  });
}
