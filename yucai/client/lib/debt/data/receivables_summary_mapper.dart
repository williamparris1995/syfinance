// ReceivablesSummary mapper(receivables 对齐,Task 8)—— proto
// ReceivablesSummaryDTO → domain ReceivablesSummary。
//
// cents 字段为 proto Int64(getter),用 `.toInt()` 转 domain int —— 对齐
// holding goal_view_mapper / budget mapper 的 Int64 模式。
// nextPaymentDate:proto date-only string,空串 → null(domain 可空),
// 非空用 tryParse(date-only ISO 解析失败落 null,不抛)。
import 'package:yucai_client/debt/domain/entities/receivables_summary.dart';
import 'package:yucai_client/proto/debt/v1/debt.pb.dart' as pb;

/// ReceivablesSummaryDTO → ReceivablesSummary。cents Int64→int,
/// nextPaymentDate 空串 → null。
ReceivablesSummary receivablesSummaryDtoToEntity(pb.ReceivablesSummaryDTO dto) {
  return ReceivablesSummary(
    totalPrincipalCents: dto.totalPrincipalCents.toInt(),
    totalRemainingCents: dto.totalRemainingCents.toInt(),
    totalCollectedCents: dto.totalCollectedCents.toInt(),
    pendingInterestCents: dto.pendingInterestCents.toInt(),
    count: dto.count,
    overdueCount: dto.overdueCount,
    overdueAmountCents: dto.overdueAmountCents.toInt(),
    principalTrendCents: dto.principalTrendCents.toInt(),
    remainingTrendCents: dto.remainingTrendCents.toInt(),
    nextPaymentDate: dto.nextPaymentDate.isEmpty
        ? null
        : DateTime.tryParse(dto.nextPaymentDate),
    nextPaymentAmountCents: dto.nextPaymentAmountCents.toInt(),
    nextPaymentCounterparty: dto.nextPaymentCounterparty,
    nextPaymentPeriodNo: dto.nextPaymentPeriodNo,
  );
}
