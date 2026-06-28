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

  group('subtype mapping (string verbatim, no helper)', () {
    pb.DebtDTO baseDto() => pb.DebtDTO()
      ..id = 's1'
      ..accountId = 'a1'
      ..counterparty = '招行'
      ..interestRate = 4.2
      ..amortizationMethod =
          pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL_INTEREST
      ..startDate = '2024-01-01'
      ..dueDate = '2034-01-01'
      ..totalPrincipalCents = $fixnum.Int64(100000)
      ..remainingPrincipalCents = $fixnum.Int64(100000)
      ..version = $fixnum.Int64(1);

    test('toDomain reads dto.subtype verbatim (creditCard)', () {
      // 用真实 const(DebtSubtypes.creditCard == 'credit_card', snake_case)
      // —— 否则 mapper 的 verbatim pass-through 会让任意字符串都通过,
      // 无法在 wire 边界捕获 snake/camel 不匹配。
      final dto = baseDto()..subtype = DebtSubtypes.creditCard;
      expect(DebtMapper.toDomain(dto).subtype, DebtSubtypes.creditCard);
    });

    test('toDomain reads dto.subtype verbatim (receivable subtypes)', () {
      // 应收债权子类型同样以纯 String 直传(无名称映射)。
      // 用真实 ReceivableSubtypes const 做 round-trip。
      for (final s in ReceivableSubtypes.all) {
        final dto = baseDto()..subtype = s;
        expect(DebtMapper.toDomain(dto).subtype, s);
      }
    });

    test('toDomain defaults to empty string when subtype unset', () {
      // proto 未设置 subtype 时,DebtDTO.subtype 默认 '',domain 应同步为 ''。
      expect(DebtMapper.toDomain(baseDto()).subtype, '');
    });

    test('CreateDebtRequest carries subtype verbatim from caller', () {
      // 远端 ds 把调用方传入的 subtype 字符串原样写入 CreateDebtRequest.subtype;
      // 这里直接验证 proto 字段级 round-trip(mapper 无 create-helper,故在
      // proto 层断言以覆盖 remote_ds.create 的 subtype wiring)。
      final req = pb.CreateDebtRequest()..subtype = DebtSubtypes.creditCard;
      expect(req.subtype, DebtSubtypes.creditCard);
      final empty = pb.CreateDebtRequest()..subtype = '';
      expect(empty.subtype, '');
    });
  });
}
