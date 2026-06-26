import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/proto/debt/v1/debt.pb.dart' as pb;

/// Maps generated proto DebtDTO / PaymentEntryDTO ↔ domain entities.
///
/// 注意:proto AmortizationMethod 值(UNSPECIFIED=0/EQUAL_PRINCIPAL_INTEREST=1/
/// EQUAL_PRINCIPAL=2/LUMP_SUM=3)与 domain AmortizationMethod 索引
/// (equalPrincipalInterest=0/equalPrincipal=1/lumpSum=2)相差 1,故显式映射而非
/// 直接按 index 转换。
class DebtMapper {
  DebtMapper._();

  static Debt toDomain(pb.DebtDTO dto) {
    return Debt(
      id: dto.id,
      accountId: dto.accountId,
      counterparty: dto.counterparty,
      interestRate: dto.interestRate,
      amortization: _amortFromProto(dto.amortizationMethod),
      startDate: DateTime.parse(dto.startDate),
      dueDate: DateTime.parse(dto.dueDate),
      totalPrincipalCents: dto.totalPrincipalCents.toInt(),
      remainingPrincipalCents: dto.remainingPrincipalCents.toInt(),
      version: dto.version.toInt(),
      createdAt: dto.createdAt.toDateTime(),
      updatedAt: dto.updatedAt.toDateTime(),
    );
  }

  static PaymentEntry paymentEntryToDomain(pb.PaymentEntryDTO dto) {
    return PaymentEntry(
      id: dto.id,
      paymentDate: DateTime.parse(dto.paymentDate),
      principalCents: dto.principalCents.toInt(),
      interestCents: dto.interestCents.toInt(),
      totalCents: dto.totalCents.toInt(),
      paid: dto.paid,
      paidCents: dto.paidCents.toInt(),
      transactionId: dto.transactionId,
    );
  }

  static AmortizationMethod _amortFromProto(pb.AmortizationMethod m) {
    switch (m) {
      case pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL_INTEREST:
        return AmortizationMethod.equalPrincipalInterest;
      case pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL:
        return AmortizationMethod.equalPrincipal;
      case pb.AmortizationMethod.AMORTIZATION_LUMP_SUM:
        return AmortizationMethod.lumpSum;
      default:
        return AmortizationMethod.equalPrincipalInterest;
    }
  }

  static pb.AmortizationMethod amortToProto(AmortizationMethod m) {
    switch (m) {
      case AmortizationMethod.equalPrincipalInterest:
        return pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL_INTEREST;
      case AmortizationMethod.equalPrincipal:
        return pb.AmortizationMethod.AMORTIZATION_EQUAL_PRINCIPAL;
      case AmortizationMethod.lumpSum:
        return pb.AmortizationMethod.AMORTIZATION_LUMP_SUM;
    }
  }
}
