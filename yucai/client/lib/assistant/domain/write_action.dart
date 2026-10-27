/// F70 写域契约 —— 待确认写操作(ADR-1 两段执行)。
///
/// 写工具 `execute()` 只**解析**口述参数为 [WriteAction](名称已解析为内部
/// id,不暴露给 LLM);实际落库由独立 `WriteExecutor` 在用户确认回调后执行
/// (T2)。三态:Add / Update(patch 至少一字段)/ Delete。
///
/// [Object.toString] 全 ASCII(非可打印 ASCII 剔除):[WriteAction] 可能进
/// 日志串(审计/幂等调试),项目门禁 = 日志串无 CJK(镜像
/// AssistantAuditLog._asciiOnly 口径);自由文本(description)经 [_ascii]
/// 过滤,id/日期为天然 ASCII。
library;

import 'package:equatable/equatable.dart';

/// 记账方向(wire 值 `in`/`out` 与 transactions_search direction 同口径;
/// Dart 保留字 `in` 不可作枚举名,故 inflow/outflow + [wire] 映射)。
enum WriteDirection {
  /// 收入(income 科目 credit 单边)。
  inflow('in'),

  /// 支出(expense 科目 debit 单边)。
  outflow('out');

  const WriteDirection(this.wire);

  /// LLM/工具层线格式(`in`/`out`)。
  final String wire;

  /// 大小写不敏感归一;未知值 → null(调用方裁决自纠)。
  static WriteDirection? fromWire(String raw) {
    final lower = raw.trim().toLowerCase();
    for (final v in values) {
      if (v.wire == lower) return v;
    }
    return null;
  }
}

/// 待确认写操作(sealed;消费方穷尽分支)。
sealed class WriteAction extends Equatable {
  const WriteAction();
}

/// 记一笔(支出/收入):direction + 金额 + 描述 + 账户(付款/收款资产户
/// 内部 id)+ 分类(expense/income 科目账户内部 id,account-as-category
/// 与表单下拉同源)+ 日期。转账 backlog(spec Out of scope)。
class TransactionAdd extends WriteAction {
  TransactionAdd({
    required this.direction,
    required this.amountCents,
    required this.description,
    required this.accountId,
    required this.categoryId,
    required this.date,
  }) {
    if (amountCents <= 0) {
      // 恒正式不变量(assert 在 release 关闭,写域用 ArgumentError 常开)。
      throw ArgumentError.value(
          amountCents, 'amountCents', 'must be positive');
    }
  }

  final WriteDirection direction;
  final int amountCents;
  final String description;
  final String accountId;
  final String categoryId;

  /// 会计日(本地时区;工具层日期缺省今天)。
  final DateTime date;

  @override
  List<Object?> get props =>
      [direction, amountCents, description, accountId, categoryId, date];

  @override
  String toString() =>
      'TransactionAdd(direction=${direction.wire}, amountCents=$amountCents, '
      'description=${_ascii(description)}, accountId=${_ascii(accountId)}, '
      'categoryId=${_ascii(categoryId)}, date=${_isoDate(date)})';
}

/// 增量补丁(至少一字段;全 null → [ArgumentError])。categoryId/accountId
/// 为**解析后内部 id**(categoryId=expense/income 科目账户;accountId=
/// 资产/负债付款账户)——与 [TransactionAdd] 同源,方向不可改(改方向 =
/// 删旧建新,不在 v1)。
class TransactionPatch extends Equatable {
  TransactionPatch({
    this.amountCents,
    this.description,
    this.categoryId,
    this.accountId,
    this.date,
  }) {
    if (amountCents == null &&
        description == null &&
        categoryId == null &&
        accountId == null &&
        date == null) {
      // 「至少一字段」是 patch 语义的一部分(全 null = 无操作),常开守卫。
      throw ArgumentError('TransactionPatch requires at least one field');
    }
    if (amountCents != null && amountCents! <= 0) {
      throw ArgumentError.value(
          amountCents, 'amountCents', 'must be positive');
    }
  }

  /// null = 不改(金额恒正由工具层自纠保证)。
  final int? amountCents;
  final String? description;
  final String? categoryId;
  final String? accountId;

  /// null = 不改。
  final DateTime? date;

  @override
  List<Object?> get props =>
      [amountCents, description, categoryId, accountId, date];

  @override
  String toString() => 'TransactionPatch(${[
        if (amountCents != null) 'amountCents=$amountCents',
        if (description != null) 'description=${_ascii(description!)}',
        if (categoryId != null) 'categoryId=${_ascii(categoryId!)}',
        if (accountId != null) 'accountId=${_ascii(accountId!)}',
        if (date != null) 'date=${_isoDate(date!)}',
      ].join(', ')})';
}

/// 改一笔:定位笔内部 id + 增量补丁。执行器(T2)在确认回调时按
/// optimistic version 全分录重建(UpdateTransactionParams 契约)。
class TransactionUpdate extends WriteAction {
  const TransactionUpdate({required this.transactionId, required this.patch});

  final String transactionId;
  final TransactionPatch patch;

  @override
  List<Object?> get props => [transactionId, patch];

  @override
  String toString() =>
      'TransactionUpdate(transactionId=${_ascii(transactionId)}, '
      'patch=$patch)';
}

/// 删一笔:定位笔内部 id(destructive,确认卡强提示)。
class TransactionDelete extends WriteAction {
  const TransactionDelete({required this.transactionId});

  final String transactionId;

  @override
  List<Object?> get props => [transactionId];

  @override
  String toString() =>
      'TransactionDelete(transactionId=${_ascii(transactionId)})';
}

/// 剔除非可打印 ASCII(0x20..0x7E)—— toString 全 ASCII 门(日志串无 CJK)。
String _ascii(String value) => String.fromCharCodes(
      value.codeUnits.where((c) => c >= 0x20 && c <= 0x7E),
    );

/// 本地时区 yyyy-MM-dd(交易日口径,与工具层 ISO 参数同格式)。
String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
