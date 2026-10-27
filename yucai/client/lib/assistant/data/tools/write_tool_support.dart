// F70-T1 —— 三写工具共用支撑(ADR-1/ADR-4/ADR-6)。
//
// 写工具 = 提案器:execute 只做「解析」(名称→内部 id / 定位复用只读面 /
// 金额元转 cents / 日期缺省今天 / 枚举自纠),结果一律
// ToolData{requiresApproval:true, action, preview} —— 零落库(ADR-1,
// 单测 mock repo verifyNever 钉死);实际写由 WriteExecutor(T2)在用户
// 确认回调后走 TransactionRepository 表单同管道。
//
// 本文件沉淀三工具共用的解析/消歧/定位件:
//  - [loadVisibleAccounts] 载体户出局(账户页同口径);
//  - [resolveUnique] 名称→账户(零命中/多候选 → 自纠 ToolError 列候选,
//    澄清原则:让 LLM 拿着候选问用户);
//  - [parseYuanToCents] / [parseIsoDateArg] lenient 参数解析(镜像
//    tool_args.dart 宽松策略);
//  - [locateSingle] 改/删定位 = TransactionRepository.list 既有过滤路径
//    (keyword+时间窗;全缺省 = 最近一笔,时间倒序首条 in/out,跳过转账)
//    + [txnSummary] 前后对比摘要(T3 diff 卡数据源)。
library;

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/assistant/data/tools/tool_args.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// ToolError 通用兜底:本地存储读取失败(与只读工具同文案族)。
const ToolError accountsLoadFailed = ToolError(
  'failed to load accounts from the local store; ask the user to retry later',
);

/// ToolError 通用兜底:交易读取失败。
const ToolError txnsLoadFailed = ToolError(
  'failed to load transactions from the local store; '
  'ask the user to retry later',
);

/// 账户全量加载(写工具第一步:解析池 + typeOf/nameOf 映射原料)。
Future<(List<Account>?, ToolError?)> loadAccounts(
  AccountRepository repo,
) async {
  final result = await repo.list();
  final List<Account>? accounts = result.fold((l) => null, (r) => r);
  if (accounts == null) return (null, accountsLoadFailed);
  return (accounts, null);
}

/// 名称 → 唯一账户(大小写不敏感精确匹配;[pool] 已按用途过滤)。
/// 零命中 → ToolError 携 [zeroGuidance](F70-T3:[guideHint] 非 null 时
/// 另携结构标记 + 实体名,v20 V4 引导卡判型用;文案不变);多候选 →
/// ToolError 列前 [maxCandidates] 个名称让 LLM 问用户(ADR-4 澄清)。
(Account?, ToolError?) resolveUnique(
  String name,
  List<Account> pool, {
  required String what,
  required String zeroGuidance,
  int maxCandidates = 3,
  ToolGuideHint? guideHint,
}) {
  final lower = name.toLowerCase();
  final matches =
      pool.where((a) => a.name.toLowerCase() == lower).toList();
  if (matches.isEmpty) {
    return (
      null,
      ToolError('no $what matches "$name"; $zeroGuidance',
          guideHint: guideHint, guideName: name),
    );
  }
  if (matches.length > 1) {
    final names = matches.take(maxCandidates).map((a) => a.name).toSet();
    return (
      null,
      ToolError(
        'multiple $what match "$name" '
        '(${matches.length} accounts): ${names.join(', ')}; '
        'ask the user which one they mean',
      ),
    );
  }
  return (matches.single, null);
}

/// 金额(元)→ cents:lenient int/double/数字串(可带千分位逗号);
/// 缺失/垃圾/<=0 → 自纠 [ToolError]([field] 供消息定位)。
(int?, ToolError?) parseYuanToCents(Object? v, String field) {
  double? yuan;
  if (v is num) {
    yuan = v.toDouble();
  } else if (v is String) {
    yuan = double.tryParse(v.trim().replaceAll(',', ''));
  }
  if (yuan == null) {
    return (
      null,
      ToolError(
        'invalid $field "$v"; expected a positive amount in yuan, e.g. 35 '
        'or 35.5',
      ),
    );
  }
  final cents = (yuan * 100).round();
  if (cents <= 0) {
    return (
      null,
      ToolError(
        'invalid $field "$v"; the amount must be greater than zero',
      ),
    );
  }
  return (cents, null);
}

/// ISO 日期参数(yyyy-MM-dd)→ [DateTime];非法 → 自纠 [ToolError]。
(DateTime?, ToolError?) parseIsoDateArg(Object? v, String field) {
  final raw = lenientString(v);
  if (raw == null) return (null, null);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return (
      null,
      ToolError(
        'invalid $field "$raw"; expected an ISO date like 2026-08-01',
      ),
    );
  }
  return (parsed, null);
}

/// 本地时区 yyyy-MM-dd(与表单/工具 ISO 参数同格式)。
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 工具 ToolData.action JSON → typed [WriteAction](F70-T2 确认门反序列化;
/// 三写工具序列化形状的镜像解码)。**任何字段缺失/类型不符/枚举非法 →
/// null**(调用方 = agent loop:解析失败不发写提案事件 —— 降级为普通
/// 工具结果,零卡零写;确认门代码语义:无卡即无执行)。
WriteAction? writeActionFromJson(Map<String, Object?> json) {
  switch (json['type']) {
    case 'transaction_add':
      final direction =
          WriteDirection.fromWire(json['direction'] as String? ?? '');
      final amountCents = json['amountCents'];
      final date = DateTime.tryParse(json['date'] as String? ?? '');
      if (direction == null || amountCents is! int || date == null) {
        return null;
      }
      return TransactionAdd(
        direction: direction,
        amountCents: amountCents,
        description: json['description'] as String? ?? '',
        accountId: json['accountId'] as String? ?? '',
        categoryId: json['categoryId'] as String? ?? '',
        date: date,
      );
    case 'transaction_update':
      final direction =
          WriteDirection.fromWire(json['direction'] as String? ?? '');
      final transactionId = json['transactionId'] as String?;
      final patchJson = json['patch'];
      if (direction == null || transactionId == null || patchJson is! Map) {
        return null;
      }
      final amountCents = patchJson['amountCents'];
      final rawDate = patchJson['date'];
      final date = rawDate == null ? null : DateTime.tryParse('$rawDate');
      if ((amountCents != null && amountCents is! int) ||
          (rawDate != null && date == null)) {
        return null;
      }
      // patch「至少一字段」是 TransactionPatch 常开不变量(构造即抛)——
      // 解码侧先判空集,杜绝异常冒泡(本函数契约:非法 → null 不抛)。
      final hasAnyField = amountCents != null ||
          patchJson['description'] != null ||
          patchJson['categoryId'] != null ||
          patchJson['accountId'] != null ||
          rawDate != null;
      if (!hasAnyField) return null;
      return TransactionUpdate(
        direction: direction,
        transactionId: transactionId,
        patch: TransactionPatch(
          amountCents: amountCents,
          description: patchJson['description'] as String?,
          categoryId: patchJson['categoryId'] as String?,
          accountId: patchJson['accountId'] as String?,
          date: date,
        ),
      );
    case 'transaction_delete':
      final transactionId = json['transactionId'] as String?;
      if (transactionId == null) return null;
      return TransactionDelete(transactionId: transactionId);
    default:
      return null;
  }
}

/// 单笔交易的 in/out 判定(与 transactions_search 同口径:income 科目
/// credit 单边 = in;expense 科目 debit 单边 = out;转账两者皆否)。
bool txnIsIn(Transaction t, Map<String, AccountType> typeOf) => t.entries
    .any((e) => typeOf[e.accountId] == AccountType.income && e.creditCents > 0);

bool txnIsOut(Transaction t, Map<String, AccountType> typeOf) => t.entries
    .any((e) => typeOf[e.accountId] == AccountType.expense && e.debitCents > 0);

/// 定位改/删目标(ADR-4 复用只读面):keyword(描述 contains,repo 既有
/// 路径)+ 时间窗;**全缺省 = 最近一笔**(时间倒序首条 in/out,转账出局
/// —— v1 只改/删支出收入笔)。零命中 → ToolError 引导 transactions_search;
/// 多候选 → ToolError 列前 [maxCandidates] 条(date/description/amount)让
/// LLM 问用户。
Future<(Transaction?, ToolError?)> locateSingle(
  TransactionRepository txns, {
  required Map<String, AccountType> typeOf,
  String? keyword,
  DateTime? dateFrom,
  DateTime? dateTo,
  int fetchPageSize = 10,
  int maxCandidates = 3,
}) async {
  if (keyword == null && dateFrom == null && dateTo == null) {
    // 最近一笔:时间倒序(repo 默认序 date DESC)首条 in/out。
    final result = await txns.list(ListTransactionsParams(
      pageSize: fetchPageSize,
    ));
    final page = result.fold((l) => null, (r) => r);
    if (page == null) return (null, txnsLoadFailed);
    for (final t in page.transactions) {
      if (txnIsIn(t, typeOf) || txnIsOut(t, typeOf)) return (t, null);
    }
    return (
      null,
      const ToolError(
        'no income or expense transaction found yet (transfers are out of '
        'scope); nothing to update or delete',
      ),
    );
  }

  final result = await txns.list(ListTransactionsParams(
    dateFrom: dateFrom,
    dateTo: dateTo,
    searchText: keyword,
    pageSize: fetchPageSize,
  ));
  final page = result.fold((l) => null, (r) => r);
  if (page == null) return (null, txnsLoadFailed);
  final matches = page.transactions
      .where((t) => txnIsIn(t, typeOf) || txnIsOut(t, typeOf))
      .toList();
  if (matches.isEmpty) {
    return (
      null,
      const ToolError(
        'no transaction matches the keyword or date window; call '
        'transactions_search to locate it or widen the date range',
      ),
    );
  }
  if (matches.length > 1) {
    final items = matches
        .take(maxCandidates)
        .map((t) =>
            '${isoDate(t.transactionDate)} ${t.description} '
            '${yuan(t.totalDebitCents)}')
        .join('; ');
    return (
      null,
      ToolError(
        'multiple transactions match (${matches.length} found): $items; '
        'ask the user which one they mean',
      ),
    );
  }
  return (matches.single, null);
}

/// 定位笔的人类可读摘要(T3 确认卡 before/after 与 preview 数据源):
/// direction/account/category 均按名称展示;category = expense/income
/// 科目分录所涉账户,account = 其余分录(资产/负债付款户)。
Map<String, Object> txnSummary(
  Transaction t,
  Map<String, AccountType> typeOf,
  Map<String, String> nameOf,
) {
  final isIn = txnIsIn(t, typeOf);
  final isOut = txnIsOut(t, typeOf);
  TransactionEntry? categoryEntry;
  for (final e in t.entries) {
    if (isIn && typeOf[e.accountId] == AccountType.income ||
        isOut && typeOf[e.accountId] == AccountType.expense) {
      categoryEntry = e;
      break;
    }
  }
  TransactionEntry? assetEntry;
  if (categoryEntry != null) {
    for (final e in t.entries) {
      if (e != categoryEntry) {
        assetEntry = e;
        break;
      }
    }
  }
  return {
    'date': isoDate(t.transactionDate),
    'description': t.description,
    'direction': isIn ? 'in' : (isOut ? 'out' : 'other'),
    'amountCents': t.totalDebitCents,
    'amountYuan': yuan(t.totalDebitCents),
    'account': assetEntry == null ? '' : (nameOf[assetEntry.accountId] ?? ''),
    'category':
        categoryEntry == null ? '' : (nameOf[categoryEntry.accountId] ?? ''),
  };
}
