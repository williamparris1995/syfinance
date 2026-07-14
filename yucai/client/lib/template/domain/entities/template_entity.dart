import 'package:equatable/equatable.dart';

/// 交易方向(对齐 proto TemplateDirection,客户端独立枚举;data 层 mapper 负责转换)。
enum TemplateDirection { unspecified, expense, income, transfer }

/// 周期(对齐 proto TemplateCycle,客户端独立枚举;data 层 mapper 负责转换)。
enum TemplateCycle { unspecified, weekly, monthly, yearly, custom }

/// 交易模板实体。对应 proto TemplateDTO(20 字段)。
class Template extends Equatable {
  const Template({
    required this.id,
    required this.name,
    required this.description,
    required this.amountCents,
    required this.direction,
    required this.sourceAccountId,
    required this.destinationAccountId,
    required this.cycle,
    required this.cycleDays,
    required this.billingDay,
    required this.nextDate,
    required this.startDate,
    required this.endDate,
    required this.autoRecord,
    required this.paused,
    required this.lastTransactionId,
    required this.category,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final int amountCents; // proto Int64 → domain int(.toInt())
  final TemplateDirection direction;
  final String? sourceAccountId; // transfer 源账户,非 transfer 为 null
  final String? destinationAccountId; // transfer 目标账户
  final TemplateCycle cycle;
  final int cycleDays; // CYCLE_CUSTOM 时自定义天数
  final int billingDay; // 月度账单日(1-28)
  final String? nextDate; // 下一笔预计日期(服务端算,date-only string)
  final String? startDate; // 起始日期
  final String? endDate; // 结束日期
  final bool autoRecord; // 自动记账(scheduler 触发)
  final bool paused; // 暂停
  final String? lastTransactionId; // 上次记账产生的 txn id('' → null)
  final String? category; // 分类(对应 expense 账户名,'' → null)
  final int version; // proto Int64 → domain int(.toInt())
  final DateTime createdAt; // proto Timestamp → DateTime
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        amountCents,
        direction,
        sourceAccountId,
        destinationAccountId,
        cycle,
        cycleDays,
        billingDay,
        nextDate,
        startDate,
        endDate,
        autoRecord,
        paused,
        lastTransactionId,
        category,
        version,
        createdAt,
        updatedAt,
      ];
}

/// record 操作结果(对应 proto RecordTransactionResponse)。
class RecordResult extends Equatable {
  const RecordResult({required this.transactionId, this.nextDate});

  final String transactionId; // 新建的 transaction id
  final DateTime? nextDate; // 下一笔预计日期(无则 null)

  @override
  List<Object?> get props => [transactionId, nextDate];
}
