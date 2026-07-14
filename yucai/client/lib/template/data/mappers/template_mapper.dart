import 'package:yucai_client/proto/template/v1/template.pb.dart' as pb;
import 'package:yucai_client/template/domain/entities/template_entity.dart';

/// proto TemplateDTO ↔ domain Template 转换(对齐 debt/tag mapper)。
/// version/amountCents Int64 → int(.toInt());Timestamp → DateTime(.toDateTime())。
/// 空字符串 ID/日期/分类 → null(语义化可选字段)。
class TemplateMapper {
  TemplateMapper._();

  static Template toDomain(pb.TemplateDTO dto) {
    return Template(
      id: dto.id,
      name: dto.name,
      description: dto.description,
      amountCents: dto.amountCents.toInt(),
      direction: toDomainDirection(dto.direction),
      sourceAccountId: _emptyToNull(dto.sourceAccountId),
      destinationAccountId: _emptyToNull(dto.destinationAccountId),
      cycle: toDomainCycle(dto.cycle),
      cycleDays: dto.cycleDays,
      billingDay: dto.billingDay,
      nextDate: _emptyToNull(dto.nextDate),
      startDate: _emptyToNull(dto.startDate),
      endDate: _emptyToNull(dto.endDate),
      autoRecord: dto.autoRecord,
      paused: dto.paused,
      lastTransactionId: _emptyToNull(dto.lastTransactionId),
      category: _emptyToNull(dto.category),
      version: dto.version.toInt(),
      createdAt: dto.createdAt.toDateTime(),
      updatedAt: dto.updatedAt.toDateTime(),
    );
  }

  /// proto RecordTransactionResponse → domain RecordResult。
  static RecordResult toRecordResult(pb.RecordTransactionResponse res) {
    return RecordResult(
      transactionId: res.transactionId,
      nextDate: res.hasNextDate() ? res.nextDate.toDateTime() : null,
    );
  }

  // ---- enum 转换(proto ↔ domain;data 层集中转换,domain 不 import proto)----

  static TemplateDirection toDomainDirection(pb.TemplateDirection d) {
    switch (d) {
      case pb.TemplateDirection.DIRECTION_EXPENSE:
        return TemplateDirection.expense;
      case pb.TemplateDirection.DIRECTION_INCOME:
        return TemplateDirection.income;
      case pb.TemplateDirection.DIRECTION_TRANSFER:
        return TemplateDirection.transfer;
      default:
        return TemplateDirection.unspecified;
    }
  }

  static pb.TemplateDirection toPbDirection(TemplateDirection d) {
    switch (d) {
      case TemplateDirection.expense:
        return pb.TemplateDirection.DIRECTION_EXPENSE;
      case TemplateDirection.income:
        return pb.TemplateDirection.DIRECTION_INCOME;
      case TemplateDirection.transfer:
        return pb.TemplateDirection.DIRECTION_TRANSFER;
      case TemplateDirection.unspecified:
        return pb.TemplateDirection.DIRECTION_UNSPECIFIED;
    }
  }

  static TemplateCycle toDomainCycle(pb.TemplateCycle c) {
    switch (c) {
      case pb.TemplateCycle.CYCLE_WEEKLY:
        return TemplateCycle.weekly;
      case pb.TemplateCycle.CYCLE_MONTHLY:
        return TemplateCycle.monthly;
      case pb.TemplateCycle.CYCLE_YEARLY:
        return TemplateCycle.yearly;
      case pb.TemplateCycle.CYCLE_CUSTOM:
        return TemplateCycle.custom;
      default:
        return TemplateCycle.unspecified;
    }
  }

  static pb.TemplateCycle toPbCycle(TemplateCycle c) {
    switch (c) {
      case TemplateCycle.weekly:
        return pb.TemplateCycle.CYCLE_WEEKLY;
      case TemplateCycle.monthly:
        return pb.TemplateCycle.CYCLE_MONTHLY;
      case TemplateCycle.yearly:
        return pb.TemplateCycle.CYCLE_YEARLY;
      case TemplateCycle.custom:
        return pb.TemplateCycle.CYCLE_CUSTOM;
      case TemplateCycle.unspecified:
        return pb.TemplateCycle.CYCLE_UNSPECIFIED;
    }
  }

  static String? _emptyToNull(String s) => s.isEmpty ? null : s;
}
