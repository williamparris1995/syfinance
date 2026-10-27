// F70-T1 —— transaction_delete 写工具(FR-3,ADR-1/ADR-4)。
//
// 提案器:定位同 transaction_update(keyword+时间窗 / 全缺省 = 最近一笔,
// 跳过转账;多候选 ToolError 列前 3)→ ToolData{requiresApproval,
// action{transactionId}, preview{target, destructive:true}} 零落库
// (destructive 强提示数据给 T3 确认卡:「删除不可撤销」)。实际删除 =
// WriteExecutor(T2)确认回调后走 TransactionRepository.delete 表单同款
// 删除管道(关联清理同源)。
library;

import 'package:yucai_client/account/domain/account_visibility.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/assistant/data/tools/tool_args.dart';
import 'package:yucai_client/assistant/data/tools/write_tool_support.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

/// 删一笔提案工具(destructive;全部确认零例外,FR-5)。
class TransactionDeleteTool implements AssistantTool {
  TransactionDeleteTool(this._txns, this._accounts);

  final TransactionRepository _txns;
  final AccountRepository _accounts;

  @override
  String get name => 'transaction_delete';

  @override
  String get description =>
      'Proposes deleting one existing expense or income transaction — '
      'destructive and not undoable. Locate it with keyword (description '
      'contains) and/or a date window (date_start/date_end, ISO dates); '
      'with no filters it targets the most recent transaction. The '
      'deletion is shown to the user for strong confirmation first — '
      'nothing is deleted until the user confirms. If several '
      'transactions match, ask the user which one. Not for transfers.';

  @override
  Map<String, Object> get parametersSchema => const {
        'type': 'object',
        'properties': {
          'keyword': {
            'type': 'string',
            'description':
                'Description keyword of the transaction to delete '
                '(contains, case-insensitive). Omit with no dates = the '
                'most recent transaction.',
          },
          'date_start': {
            'type': 'string',
            'description': 'Inclusive lower bound, ISO date YYYY-MM-DD.',
          },
          'date_end': {
            'type': 'string',
            'description': 'Inclusive upper bound, ISO date YYYY-MM-DD.',
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, Object> args) async {
    // ── 定位过滤(keyword + 时间窗;非法日期自纠)──
    final keyword = lenientString(args['keyword']);
    final (dateFrom, fromError) =
        parseIsoDateArg(args['date_start'], 'date_start');
    if (fromError != null) return fromError;
    final (dateTo, toError) = parseIsoDateArg(args['date_end'], 'date_end');
    if (toError != null) return toError;

    // ── 账户映射原料(typeOf 判方向/nameOf 出名称;载体户出局)。──
    final (accounts, loadError) = await loadAccounts(_accounts);
    if (loadError != null) return loadError;
    final typeOf = {
      for (final a in accounts!) a.id: a.accountType,
    };
    final nameOf = {
      for (final a in AccountVisibility.userVisible(accounts)) a.id: a.name,
    };

    // ── 定位(ADR-4:复用只读面;多候选列前 3 问用户)。──
    final (located, locateError) = await locateSingle(
      _txns,
      typeOf: typeOf,
      keyword: keyword,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    if (locateError != null) return locateError;
    final txn = located!;

    // ── 提案(ADR-1:零落库;destructive 强提示位给 T3 确认卡)。──
    return ToolData({
      'requiresApproval': true,
      'action': {
        'type': 'transaction_delete',
        'transactionId': txn.id,
      },
      'preview': {
        'destructive': true,
        'target': txnSummary(txn, typeOf, nameOf),
      },
    });
  }
}
