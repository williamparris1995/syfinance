import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/debt/data/mappers/debt_mapper.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/proto/debt/v1/debt.pb.dart' as pb;

void main() {
  test('DebtMapper.toDomain: proto → entity', () {
    final dto = pb.DebtDTO()
      ..id = 'd1'
      ..accountId = 'a1'
      ..counterparty = '招行'
      ..interestRate = 4.2
      ..amortizationMethod =
          pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL_INTEREST
      ..startDate = '2024-01-01'
      ..dueDate = '2034-01-01'
      ..totalPrincipalCents = $fixnum.Int64(280000000)
      ..remainingPrincipalCents = $fixnum.Int64(210000000)
      ..version = $fixnum.Int64(1);
    final d = DebtMapper.toDomain(dto);
    expect(d.id, 'd1');
    expect(d.amortization, AmortizationMethod.equalPrincipalInterest);
    expect(d.startDate, DateTime(2024, 1, 1));
  });

  test('DebtMapper.paymentEntryToDomain', () {
    final dto = pb.PaymentEntryDTO()
      ..id = 'e1'
      ..paymentDate = '2024-02-01'
      ..principalCents = $fixnum.Int64(100000)
      ..interestCents = $fixnum.Int64(5000)
      ..totalCents = $fixnum.Int64(105000)
      ..paid = true
      ..paidCents = $fixnum.Int64(105000)
      ..transactionId = 't1';
    final e = DebtMapper.paymentEntryToDomain(dto);
    expect(e.paid, true);
    expect(e.status, PaymentStatus.paid);
  });

  test('DebtMapper.amortToProto: round-trip', () {
    expect(
      DebtMapper.amortToProto(AmortizationMethod.equalPrincipalInterest),
      pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL_INTEREST,
    );
    expect(
      DebtMapper.amortToProto(AmortizationMethod.equalPrincipal),
      pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL,
    );
    expect(
      DebtMapper.amortToProto(AmortizationMethod.lumpSum),
      pb.AmortizationMethod.AMORTIZATION_LUMP_SUM,
    );
  });
}
