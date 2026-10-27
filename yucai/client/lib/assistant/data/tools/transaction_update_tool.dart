// F70-T1 —— transaction_update 写工具(FR-2,ADR-1/ADR-4)。
//
// 提案器:定位(复用只读面 keyword+时间窗 / 全缺省 = 最近一笔,跳过转账)
// → 多候选 ToolError 列前 3 让 LLM 问用户 → 增量字段解析(new_amount/
// new_description/new_category/new_account/new_date,至少一字段;分类按
// 定位笔方向解析;账户解析到资产/负债户)→ ToolData{requiresApproval,
// action(patch 内部 id), preview{before, after}} 零落库。实际更新 =
// WriteExecutor(T2)确认回调后走 TransactionRepository.update 表单同管道
// (全分录重建 + optimistic version 由执行器完成)。
library;

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/account_visibility.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/assistant/data/tools/tool_args.dart';
import 'package:yucai_client/assistant/data/tools/write_tool_support.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

/// 改一笔提案工具(增量字段;方向不可改 —— 改方向 = 删旧建新,不在 v1)。
class TransactionUpdateTool implements AssistantTool {
  TransactionUpdateTool(this._txns, this._accounts);

  final TransactionRepository _txns;
  final AccountRepository _accounts;

  @override
  String get name => 'transaction_update';

  @override
  String get description =>
      'Proposes updating one existing expense or income transaction. '
      'Locate it with keyword (description contains) and/or a date window '
      '(date_start/date_end, ISO dates); with no filters it targets the '
      'most recent transaction. At least one new_* field is required: '
      'new_amount (yuan), new_description, new_category (must fit the '
      'transaction direction), new_account (asset/liability account name), '
      'new_date. The change is shown to the user for confirmation first — '
      'nothing is modified until the user confirms. If several '
      'transactions match, ask the user which one. Not for transfers.';

  @override
  Map<String, Object> get parametersSchema => const {
        'type': 'object',
        'properties': {
          'keyword': {
            'type': 'string',
            'description':
                'Description keyword of the transaction to update '
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
          'new_amount': {
            'type': 'number',
            'description': 'New total amount in yuan, e.g. 40.',
          },
          'new_description': {
            'type': 'string',
            'description': 'New description.',
          },
          'new_category': {
            'type': 'string',
            'description':
                'New category account name; must be an expense category '
                'for expense transactions, an income category for income.',
          },
          'new_account': {
            'type': 'string',
            'description':
                'New asset/liability account name (where money leaves or '
                'lands).',
          },
          'new_date': {
            'type': 'string',
            'description': 'New transaction date, ISO YYYY-MM-DD.',
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

    // ── 增量字段解析(先raw判定「至少一字段」,再逐项解析)──
    final newAmountArg = args['new_amount'];
    final newDescription = lenientString(args['new_description']);
    final newCategoryArg = lenientString(args['new_category']);
    final newAccountArg = lenientString(args['new_account']);
    final newDateArg = lenientString(args['new_date']);
    if (newAmountArg == null &&
        newDescription == null &&
        newCategoryArg == null &&
        newAccountArg == null &&
        newDateArg == null) {
      return const ToolError(
        'at least one of new_amount, new_description, new_category, '
        'new_account, new_date is required',
      );
    }
    int? newAmountCents;
    if (newAmountArg != null) {
      final (cents, err) = parseYuanToCents(newAmountArg, 'new_amount');
      if (err != null) return err;
      newAmountCents = cents;
    }
    DateTime? newDate;
    if (newDateArg != null) {
      final (parsed, err) = parseIsoDateArg(newDateArg, 'new_date');
      if (err != null) return err;
      newDate = parsed;
    }

    // ── 账户映射原料(全量 typeOf/nameOf + 解析池)──
    final (accounts, loadError) = await loadAccounts(_accounts);
    if (loadError != null) return loadError;
    final typeOf = {
      for (final a in accounts!) a.id: a.accountType,
    };
    final nameOf = {
      for (final a in accounts) a.id: a.name,
    };
    final visible = AccountVisibility.userVisible(accounts);
    final paymentPool = visible
        .where((a) =>
            a.accountType == AccountType.asset ||
            a.accountType == AccountType.liability)
        .toList();

    // ── 定位(ADR-4:复用只读面;多候选列前 3 问用户)──
    final (located, locateError) = await locateSingle(
      _txns,
      typeOf: typeOf,
      keyword: keyword,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    if (locateError != null) return locateError;
    final txn = located!;
    final direction =
        txnIsIn(txn, typeOf) ? 'in' : 'out'; // locateSingle 已滤转账

    // ── new_category 按定位笔方向解析 ──
    Account? newCategory;
    if (newCategoryArg != null) {
      final pool = visible
          .where((a) => direction == 'out'
              ? a.accountType == AccountType.expense
              : a.accountType == AccountType.income)
          .toList();
      final (resolved, err) = resolveUnique(
        newCategoryArg,
        pool,
        what: 'category',
        zeroGuidance: 'available categories for direction=$direction: '
            '${pool.map((a) => a.name).join(', ')}; pick the closest one, '
            'or offer to create it via the categories form',
        // FR-4 分类引导补齐(评审 T3-M3):分类零命中同出引导卡。
        guideHint: ToolGuideHint.unknownAccount,
        guideAmountYuan: yuan(newAmountCents ?? txn.totalDebitCents),
      );
      if (err != null) return err;
      newCategory = resolved;
    }

    // ── new_account 解析到资产/负债户 ──
    Account? newAccount;
    if (newAccountArg != null) {
      final (resolved, err) = resolveUnique(
        newAccountArg,
        paymentPool,
        what: 'account',
        zeroGuidance: 'call accounts_list to see the available account names',
        // F70-T3 V4:账户零命中携结构标记 + 请求金额(评审 T3-M2;金额 =
        // new_amount,未改则定位笔现额 —— 引导卡参数行不丢上下文)。
        guideHint: ToolGuideHint.unknownAccount,
        guideAmountYuan: yuan(newAmountCents ?? txn.totalDebitCents),
      );
      if (err != null) return err;
      newAccount = resolved;
    }

    // ── 提案(ADR-1:零落库;typed patch 保证「至少一字段」不变量)。──
    final patch = TransactionPatch(
      amountCents: newAmountCents,
      description: newDescription,
      categoryId: newCategory?.id,
      accountId: newAccount?.id,
      date: newDate,
    );
    final before = txnSummary(txn, typeOf, nameOf);
    final after = {
      ...before,
      if (patch.amountCents != null) 'amountCents': patch.amountCents!,
      if (patch.amountCents != null) 'amountYuan': yuan(patch.amountCents!),
      if (patch.description != null) 'description': patch.description!,
      if (newCategory != null) 'category': newCategory.name,
      if (newAccount != null) 'account': newAccount.name,
      if (patch.date != null) 'date': isoDate(patch.date!),
    };
    return ToolData({
      'requiresApproval': true,
      'action': {
        'type': 'transaction_update',
        // 方向随提案携带(T2 执行器全分录重建的借贷侧依据;方向不可改)。
        'direction': direction,
        'transactionId': txn.id,
        'patch': {
          if (patch.amountCents != null) 'amountCents': patch.amountCents!,
          if (patch.description != null) 'description': patch.description!,
          if (patch.categoryId != null) 'categoryId': patch.categoryId!,
          if (patch.accountId != null) 'accountId': patch.accountId!,
          if (patch.date != null) 'date': isoDate(patch.date!),
        },
      },
      'preview': {'before': before, 'after': after},
    });
  }
}
