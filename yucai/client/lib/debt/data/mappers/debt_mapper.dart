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
      type: debtTypeFromProto(dto.debtType),
      // subtype 是纯 String,与 proto 直传,无名称映射(区别于 DebtType)。
      subtype: dto.subtype,
      // receivables 对齐字段(Task 8):cents 为 proto Int64(getter),`.toInt()`
      // 转 domain int(对齐 holding/budget mapper);collectionAccountId 空串 → null;
      // nextPaymentDate 空串 → null,非空用 tryParse(date-only string 解析失败
      // 不抛,落 null,与可空语义一致)。
      contact: dto.contact,
      contractRef: dto.contractRef,
      collectionAccountId:
          dto.collectionAccountId.isEmpty ? null : dto.collectionAccountId,
      nextPaymentDate:
          dto.nextPaymentDate.isEmpty ? null : DateTime.tryParse(dto.nextPaymentDate),
      nextPaymentAmountCents: dto.nextPaymentAmountCents.toInt(),
      nextPaymentPeriodNo: dto.nextPaymentPeriodNo,
      remainingTrendCents: dto.remainingTrendCents.toInt(),
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

  /// proto DebtType → domain DebtType。
  ///
  /// 与 AmortizationMethod 同样的 off-by-one:proto 值为 UNSPECIFIED=0 /
  /// BORROWED_IN=1 / BORROWED_OUT=2,而 domain 索引为 borrowedIn=0 /
  /// borrowedOut=1,二者不对齐,故按符号 NAME 显式映射,绝不按 int 强转。
  /// UNSPECIFIED 折叠为 borrowedIn(匹配服务端旧行为:既有/未指定债务为借入)。
  static DebtType debtTypeFromProto(pb.DebtType t) {
    switch (t) {
      case pb.DebtType.DEBT_TYPE_BORROWED_OUT:
        return DebtType.borrowedOut;
      case pb.DebtType.DEBT_TYPE_BORROWED_IN:
      case pb.DebtType.DEBT_TYPE_UNSPECIFIED:
      default:
        // UNSPECIFIED 折叠为 borrowedIn(匹配服务端旧行为:既有/未指定债务为借入)。
        return DebtType.borrowedIn;
    }
  }

  /// domain DebtType → proto DebtType。debtTypeFromProto 的逆映射
  /// (UNSPECIFIED 在正向不可达,故为部分逆)。
  static pb.DebtType debtTypeToProto(DebtType t) {
    switch (t) {
      case DebtType.borrowedIn:
        return pb.DebtType.DEBT_TYPE_BORROWED_IN;
      case DebtType.borrowedOut:
        return pb.DebtType.DEBT_TYPE_BORROWED_OUT;
    }
  }
}
