// F64-T3 —— 助手工具共用:lenient 参数解析(分页/kind)。
//
// LLM 产出的 JSON 参数类型不可信(int/double/带空白字符串均可能出现),
// 解析策略 = 宽松(能救则救):数值按 num/String 双路 coerce,垃圾值回落
// 缺省;仅语义非法(如未知 kind)返回可自纠 [ToolError](由调用方裁决)。
// 金额元字符串复用 core 纯函数 DueReminderPolicy.formatYuan(两位小数 +
// 千分位;presentation 各页 formatCents 私有且带币符,不复用 —— 此为 core
// 既有等价纯函数,复用第一)。
library;

import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart'
    show DueReminderPolicy;

/// 分页缺省/上限(NFR-2:page_size 上限 50,聚合摘要禁全表倒出)。
const int kDefaultPageSize = 20;
const int kMaxPageSize = 50;

/// lenient num → int? :int/double 直转,字符串 tryParse,其余 null。
int? lenientInt(Object? v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

/// lenient 字符串参数:非 String/null/空白 → null(= 未提供)。
String? lenientString(Object? v) {
  if (v is! String) return null;
  final s = v.trim();
  return s.isEmpty ? null : s;
}

/// 解析 {page, page_size} → 宽松钳位后的 (page≥1, pageSize∈[1,50])。
/// 缺省 page=1 / page_size=20;page<1 → 1;page_size 越界 → 钳到边界;
/// 垃圾类型 → 缺省(宽松,不报错)。
({int page, int pageSize}) parsePagination(Map<String, Object> args) {
  final page = lenientInt(args['page']) ?? 1;
  final size = lenientInt(args['page_size']) ?? kDefaultPageSize;
  return (
    page: page < 1 ? 1 : page,
    pageSize: size < 1 ? 1 : (size > kMaxPageSize ? kMaxPageSize : size),
  );
}

/// kind 过滤(对齐 AccountType 值域):null/空 = 不过滤;非法值 →
/// [ToolError] 列全部合法值(自纠消息,LLM 改参重试)。
ToolResult? checkKindFilter(String? kind, List<String> legalValues) {
  if (kind == null) return null;
  if (legalValues.contains(kind)) return null;
  return ToolError(
    'invalid kind "$kind"; allowed values: ${legalValues.join(', ')}',
  );
}

/// cents → 元字符串(两位小数 + 千分位,负数带 -)。
String yuan(int cents) => DueReminderPolicy.formatYuan(cents);

/// 分页元数据附加字段:{page,pageSize,totalCount,totalPages,hasMore}。
Map<String, Object> paginationMeta({
  required int page,
  required int pageSize,
  required int totalCount,
}) {
  final totalPages = totalCount == 0 ? 0 : ((totalCount - 1) ~/ pageSize) + 1;
  return {
    'page': page,
    'pageSize': pageSize,
    'totalCount': totalCount,
    'totalPages': totalPages,
    'hasMore': page < totalPages,
  };
}
