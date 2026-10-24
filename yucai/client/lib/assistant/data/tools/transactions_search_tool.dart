// F65-T1 —— transactions_search 只读工具(FR-2,六项过滤 + 聚合摘要)。
//
// 过滤链:start/end(ISO 日期,含端)→ account(账户 id 或名称精确匹配,
// 忽略大小写;零命中 → 自纠 ToolError 引导 accounts_list)→ category
// (AccountCategory 值域名,与交易页筛选同维度)→ keyword(描述 contains
// 忽略大小写)—— 前四项经 TransactionRepository.list 既有过滤路径
// (单一事实源);direction(in|out)在工具内按科目分类(income 科目
// credit 单边 = in;expense 科目 debit 单边 = out,TransactionSummary
// 同口径)。全量页循环(nextPageToken)收集后聚合:笔数/收入合计/支出
// 合计/净额 + top-N 页片(日期/描述/方向/金额/涉及账户),超界页空而
// 汇总不丢(spec FR-2)。逐分一致由 tools_caliber_test 钉死(NFR-1)。
library;

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/assistant/data/tools/tool_args.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// 交易搜索工具:六项过滤 + 过滤后聚合摘要 + 分页 top-N。
class TransactionsSearchTool implements AssistantTool {
  TransactionsSearchTool(this._txns, this._accounts);

  final TransactionRepository _txns;
  final AccountRepository _accounts;

  /// 单轮拉取页大小(全量收集循环的步长;与 UI 无关的内部常量)。
  static const int _fetchPageSize = 200;

  /// 全量收集循环护栏(防异常取数端无限翻页;200×500 = 10 万笔封顶)。
  static const int _maxFetchPages = 500;

  /// category 合法值 = AccountCategory 值域名(const 硬编码副本 ——
  /// parametersSchema 的 const enum 需要编译期常量;对齐守卫测试钉死
  /// 与 AccountCategory.values 派生集一致,镜像 AccountsListTool.legalKinds)。
  static const legalCategories = [
    'savings',
    'creditCard',
    'investment',
    'fixedDeposit',
    'goldFx',
    'realEstate',
    'loan',
    'otherAsset',
    'otherLiability',
    'storedValue',
  ];

  @override
  String get name => 'transactions_search';

  @override
  String get description =>
      'Searches the transaction ledger with filters: date range (start/end, '
      'inclusive ISO dates), account (exact id or name, case-insensitive), '
      'category (account category like savings/creditCard/otherAsset), '
      'keyword (description contains, case-insensitive) and direction '
      '(in = income, out = expense). Returns an aggregate summary over the '
      'matched set (count, income total, expense total, net) plus a '
      'paginated list of top transactions with date/description/direction/'
      'amount/involved accounts. Transfers are neither in nor out and stay '
      'in unfiltered results. Use for "how much did I spend this month / '
      'what income did I receive / list card transactions". Not for '
      'holdings trades or budget execution.';

  @override
  Map<String, Object> get parametersSchema => const {
        'type': 'object',
        'properties': {
          'start': {
            'type': 'string',
            'description': 'Inclusive lower bound, ISO date YYYY-MM-DD.',
          },
          'end': {
            'type': 'string',
            'description': 'Inclusive upper bound, ISO date YYYY-MM-DD.',
          },
          'account': {
            'type': 'string',
            'description':
                'Account id or exact account name (case-insensitive); '
                'call accounts_list first to see names.',
          },
          'category': {
            'type': 'string',
            'enum': legalCategories,
            'description': 'Optional account-category filter.',
          },
          'keyword': {
            'type': 'string',
            'description':
                'Optional description keyword (contains, case-insensitive).',
          },
          'direction': {
            'type': 'string',
            'enum': ['in', 'out'],
            'description':
                'in = income transactions, out = expense transactions.',
          },
          'page': {
            'type': 'integer',
            'minimum': 1,
            'description': '1-based page number (default 1).',
          },
          'page_size': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 50,
            'description': 'Items per page, 1..50 (default 20).',
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, Object> args) async {
    // ── 参数解析(语义非法 → 自纠 ToolError)──
    final startRaw = lenientString(args['start']);
    final endRaw = lenientString(args['end']);
    DateTime? start;
    DateTime? end;
    if (startRaw != null) {
      start = DateTime.tryParse(startRaw);
      if (start == null) {
        return ToolError(
          'invalid start "$startRaw"; expected an ISO date like 2026-08-01',
        );
      }
    }
    if (endRaw != null) {
      end = DateTime.tryParse(endRaw);
      if (end == null) {
        return ToolError(
          'invalid end "$endRaw"; expected an ISO date like 2026-08-31',
        );
      }
    }
    if (start != null && end != null && start.isAfter(end)) {
      return const ToolError(
        'start is after end; swap the two dates and retry',
      );
    }

    // category 合法值含 camelCase(otherAsset 等)→ 大小写不敏感匹配后
    // 归一到规范值(镜像 checkKindFilter 的自纠语义,但双路 lowercase)。
    final categoryArg = lenientString(args['category']);
    String? category;
    if (categoryArg != null) {
      final matches = legalCategories
          .where((c) => c.toLowerCase() == categoryArg.toLowerCase())
          .toList();
      if (matches.isEmpty) {
        return ToolError(
          'invalid category "$categoryArg"; allowed values: '
          '${legalCategories.join(', ')}',
        );
      }
      category = matches.single;
    }

    final direction = lenientString(args['direction'])?.toLowerCase();
    if (direction != null && direction != 'in' && direction != 'out') {
      return const ToolError(
        'invalid direction; allowed values: in, out',
      );
    }

    final keyword = lenientString(args['keyword']);
    final page = parsePagination(args);

    // ── 账户映射(id/name → 实体;名称精确匹配忽略大小写)──
    final accountsResult = await _accounts.list();
    final List<Account>? accountList =
        accountsResult.fold((l) => null, (r) => r);
    if (accountList == null) {
      return const ToolError(
        'failed to load accounts from the local store; '
        'ask the user to retry later',
      );
    }
    final accountArg = lenientString(args['account']);
    Set<String>? accountIds;
    if (accountArg != null) {
      final lower = accountArg.toLowerCase();
      final matches = accountList
          .where((a) =>
              a.id.toLowerCase() == lower || a.name.toLowerCase() == lower)
          .toList();
      if (matches.isEmpty) {
        return ToolError(
          'no account matches "$accountArg"; '
          'call accounts_list to see the available account names',
        );
      }
      accountIds = {for (final a in matches) a.id};
    }
    final nameOf = {for (final a in accountList) a.id: a.name};

    // ── 仓库过滤页循环(date/account 单命中/category/keyword 走 repo 既有
    //    过滤路径;account 多命中 + direction 工具内过滤)──
    AccountCategory? categoryEnum;
    if (category != null) {
      final matches =
          AccountCategory.values.where((c) => c.name == category).toList();
      if (matches.isEmpty) {
        // 白名单已拦(防御路径,镜像 AccountsListTool L1 自纠)。
        return ToolError(
          'invalid category "$category"; allowed values: '
          '${legalCategories.join(', ')}',
        );
      }
      categoryEnum = matches.single;
    }
    final singleAccountId =
        accountIds != null && accountIds.length == 1 ? accountIds.single : null;

    final collected = <Transaction>[];
    var token = '';
    var pages = 0;
    while (true) {
      final result = await _txns.list(ListTransactionsParams(
        accountId: singleAccountId,
        dateFrom: start,
        dateTo: end,
        category: categoryEnum,
        searchText: keyword,
        pageSize: _fetchPageSize,
        pageToken: token.isEmpty ? null : token,
      ));
      final ListTransactionsResult? pageResult =
          result.fold((l) => null, (r) => r);
      if (pageResult == null) {
        return const ToolError(
          'failed to load transactions from the local store; '
          'ask the user to retry later',
        );
      }
      collected.addAll(pageResult.transactions);
      token = pageResult.nextPageToken;
      if (!pageResult.hasMore) break;
      pages++;
      if (pages > _maxFetchPages) {
        return const ToolError(
          'transaction search window is too large; narrow it with dates, '
          'account or keyword and retry',
        );
      }
    }

    // ── 工具内过滤:account 多命中(any entry 涉及,repo 同口径)+
    //    direction(in = income 科目 credit 单边;out = expense 科目
    //    debit 单边,TransactionSummary 同口径)。──
    final typeOf = {
      for (final a in accountList) a.id: a.accountType,
    };
    bool isIn(Transaction t) => t.entries.any((e) =>
        typeOf[e.accountId] == AccountType.income && e.creditCents > 0);
    bool isOut(Transaction t) => t.entries.any((e) =>
        typeOf[e.accountId] == AccountType.expense && e.debitCents > 0);

    final ids = accountIds;
    final filtered = collected.where((t) {
      if (ids != null &&
          !t.entries.any((e) => ids.contains(e.accountId))) {
        return false;
      }
      if (direction == 'in' && !isIn(t)) return false;
      if (direction == 'out' && !isOut(t)) return false;
      return true;
    }).toList();

    // ── 过滤后聚合摘要(收入/支出 = 科目单边口径,summary RPC 同式)──
    var income = 0;
    var expense = 0;
    for (final t in filtered) {
      for (final e in t.entries) {
        final type = typeOf[e.accountId];
        if (type == AccountType.income) {
          income += e.creditCents; // income accounts: credit side counts
        } else if (type == AccountType.expense) {
          expense += e.debitCents; // expense accounts: debit side counts
        }
      }
    }

    final start_ = (page.page - 1) * page.pageSize;
    final slice = start_ >= filtered.length
        ? const <Transaction>[]
        : filtered.skip(start_).take(page.pageSize).toList();

    return ToolData({
      if (startRaw != null) 'start': startRaw,
      if (endRaw != null) 'end': endRaw,
      if (accountArg != null) 'account': accountArg,
      if (category != null) 'category': category,
      if (keyword != null) 'keyword': keyword,
      if (direction != null) 'direction': direction,
      'transactions': [
        for (final t in slice)
          {
            'date': _isoDate(t.transactionDate),
            'description': t.description,
            'direction': isIn(t)
                ? 'in'
                : isOut(t)
                    ? 'out'
                    : 'other',
            'amountCents': t.totalDebitCents,
            'amountYuan': yuan(t.totalDebitCents),
            'accounts': [
              for (final id in t.entries.map((e) => e.accountId).toSet())
                if (nameOf[id] != null) nameOf[id]!,
            ],
          }
      ],
      'summary': {
        'count': filtered.length,
        'incomeCents': income,
        'incomeYuan': yuan(income),
        'expenseCents': expense,
        'expenseYuan': yuan(expense),
        'netCents': income - expense,
        'netYuan': yuan(income - expense),
      },
      ...paginationMeta(
        page: page.page,
        pageSize: page.pageSize,
        totalCount: filtered.length,
      ),
    });
  }

  /// 本地时区 yyyy-MM-dd(交易日展示口径)。
  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
