import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/debt/data/mappers/debt_mapper.dart';
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

  group('DebtType mapping', () {
    test('debtTypeFromProto: BORROWED_IN / BORROWED_OUT / UNSPECIFIED', () {
      expect(
        DebtMapper.debtTypeFromProto(pb.DebtType.DEBT_TYPE_BORROWED_IN),
        DebtType.borrowedIn,
      );
      expect(
        DebtMapper.debtTypeFromProto(pb.DebtType.DEBT_TYPE_BORROWED_OUT),
        DebtType.borrowedOut,
      );
      // UNSPECIFIED must collapse to borrowedIn (NOT throw / NOT become borrowedOut).
      expect(
        DebtMapper.debtTypeFromProto(pb.DebtType.DEBT_TYPE_UNSPECIFIED),
        DebtType.borrowedIn,
      );
    });

    test('debtTypeToProto: both domain values', () {
      expect(
        DebtMapper.debtTypeToProto(DebtType.borrowedIn),
        pb.DebtType.DEBT_TYPE_BORROWED_IN,
      );
      expect(
        DebtMapper.debtTypeToProto(DebtType.borrowedOut),
        pb.DebtType.DEBT_TYPE_BORROWED_OUT,
      );
    });

    test('debtTypeToProto ∘ debtTypeFromProto is identity (excluding UNSPECIFIED)',
        () {
      for (final proto in [
        pb.DebtType.DEBT_TYPE_BORROWED_IN,
        pb.DebtType.DEBT_TYPE_BORROWED_OUT,
      ]) {
        expect(DebtMapper.debtTypeToProto(DebtMapper.debtTypeFromProto(proto)),
            proto);
      }
    });

    test('toDomain reads dto.debtType', () {
      final dto = pb.DebtDTO()
        ..id = 'd2'
        ..accountId = 'a1'
        ..counterparty = '张三'
        ..interestRate = 5.0
        ..amortizationMethod =
            pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL_INTEREST
        ..startDate = '2024-01-01'
        ..dueDate = '2025-01-01'
        ..totalPrincipalCents = $fixnum.Int64(100000)
        ..remainingPrincipalCents = $fixnum.Int64(100000)
        ..version = $fixnum.Int64(1)
        ..debtType = pb.DebtType.DEBT_TYPE_BORROWED_OUT;
      final d = DebtMapper.toDomain(dto);
      expect(d.type, DebtType.borrowedOut);
    });

    test('toDomain defaults to borrowedIn when debtType is UNSPECIFIED', () {
      final dto = pb.DebtDTO()
        ..id = 'd3'
        ..accountId = 'a1'
        ..counterparty = '李四'
        ..interestRate = 3.0
        ..amortizationMethod =
            pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL_INTEREST
        ..startDate = '2024-01-01'
        ..dueDate = '2025-01-01'
        ..totalPrincipalCents = $fixnum.Int64(50000)
        ..remainingPrincipalCents = $fixnum.Int64(50000)
        ..version = $fixnum.Int64(1)
        ..debtType = pb.DebtType.DEBT_TYPE_UNSPECIFIED;
      expect(DebtMapper.toDomain(dto).type, DebtType.borrowedIn);
    });
  });
}
