// F70-T1 —— transaction_add 写工具(FR-1,ADR-1 两段执行)。
//
// 提案器:解析口述参数(方向/金额/描述/账户/分类/日期)→ 名称解析为内部
// id(账户 = 资产/负债付款户;分类 = expense/income 科目账户,与表单
// account-as-category 下拉同源)→ 一律返回
// ToolData{requiresApproval:true, action(内部 id), preview} —— 零落库;
// 实际落库 = WriteExecutor(T2)确认回调后走 TransactionRepository 表单同
// 管道(recordExpense/recordIncome)。解析歧义 → ToolError 列候选让 LLM
// 问用户(澄清原则);查无账户/分类 → 引导(FR-4:助手不直接建户)。
library;

import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/domain/account_visibility.dart';
import 'package:yucai_client/assistant/data/tools/tool_args.dart';
import 'package:yucai_client/assistant/data/tools/write_tool_support.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';

/// 记一笔提案工具(支出/收入;转账 backlog)。
class TransactionAddTool implements AssistantTool {
  TransactionAddTool(this._accounts, [this._clock]);

  final AccountRepository _accounts;

  /// 日期缺省「今天」时钟(测试注入;缺省当前时刻)。
  final DateTime Function()? _clock;

  @override
  String get name => 'transaction_add';

  @override
  String get description =>
      'Proposes recording one expense or income transaction (direction, '
      'amount in yuan, description, account, category, date). The proposal '
      'is shown to the user for confirmation first — nothing is recorded '
      'until the user confirms. account must be an existing asset or '
      'liability account name (e.g. a bank card); category must be an '
      'expense category for direction=out (e.g. food, transport) or an '
      'income category for direction=in — call accounts_list to see the '
      'names. date defaults to today. Use for "record a 35 yuan lunch on '
      'my bank card". Not for transfers or creating accounts.';

  @override
  Map<String, Object> get parametersSchema => const {
        'type': 'object',
        'properties': {
          'direction': {
            'type': 'string',
            'enum': ['in', 'out'],
            'description':
                'out = expense, in = income. Required.',
          },
          'amount': {
            'type': 'number',
            'description':
                'Positive amount in yuan, e.g. 35 or 35.5. Required.',
          },
          'description': {
            'type': 'string',
            'description': 'Short payee or note, e.g. lunch.',
          },
          'account': {
            'type': 'string',
            'description':
                'Exact account name the money leaves (out) or lands in '
                '(in), case-insensitive; call accounts_list first. Required.',
          },
          'category': {
            'type': 'string',
            'description':
                'Expense category name for out / income category name for '
                'in, matching the user wording (e.g. lunch -> food). '
                'Required.',
          },
          'date': {
            'type': 'string',
            'description': 'ISO date YYYY-MM-DD; defaults to today.',
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, Object> args) async {
    // ── direction(必填,枚举自纠)──
    final directionRaw = lenientString(args['direction'])?.toLowerCase();
    if (directionRaw == null) {
      return const ToolError(
        'direction is required; allowed values: in, out',
      );
    }
    final direction = WriteDirection.fromWire(directionRaw);
    if (direction == null) {
      return const ToolError(
        'invalid direction; allowed values: in, out',
      );
    }

    // ── amount(必填,元 → cents)──
    final amountArg = args['amount'];
    if (amountArg == null) {
      return const ToolError(
        'amount is required: a positive amount in yuan, e.g. 35 or 35.5',
      );
    }
    final (amountCents, amountError) = parseYuanToCents(amountArg, 'amount');
    if (amountError != null) return amountError;

    // ── date(缺省今天)──
    final (parsedDate, dateError) = parseIsoDateArg(args['date'], 'date');
    if (dateError != null) return dateError;
    final date = parsedDate ?? _clock?.call() ?? DateTime.now();

    // ── 账户/分类解析池(载体户出局,与账户页同口径)──
    final (accounts, loadError) = await loadAccounts(_accounts);
    if (loadError != null) return loadError;
    final visible = AccountVisibility.userVisible(accounts!);
    final paymentPool = visible
        .where((a) =>
            a.accountType == AccountType.asset ||
            a.accountType == AccountType.liability)
        .toList();
    final categoryPool = visible
        .where((a) => direction == WriteDirection.outflow
            ? a.accountType == AccountType.expense
            : a.accountType == AccountType.income)
        .toList();

    // ── account(必填:名称 → 唯一资产/负债户)──
    final accountArg = lenientString(args['account']);
    if (accountArg == null) {
      return const ToolError(
        'account is required; call accounts_list to see the available '
        'account names and ask the user which one to use',
      );
    }
    final (account, accountError) = resolveUnique(
      accountArg,
      paymentPool,
      what: 'account',
      zeroGuidance: 'call accounts_list to see the available account names, '
          'or offer to create the account via the accounts form',
    );
    if (accountError != null) return accountError;

    // ── category(必填:名称 → 唯一科目账户;缺省推导是 LLM 的职责,
    //    工具不猜 —— 缺失即列全部分类让 LLM 选/问用户)。──
    final categoryArg = lenientString(args['category']);
    if (categoryArg == null) {
      if (categoryPool.isEmpty) {
        return ToolError(
          'category is required for direction=${direction.wire} but no '
          '${direction.wire == 'out' ? 'expense' : 'income'} category '
          'account exists yet; offer to create one via the categories form',
        );
      }
      return ToolError(
        'category is required for direction=${direction.wire}; available '
        'categories: '
        '${categoryPool.map((a) => a.name).join(', ')}; pick the one that '
        'matches the description, or ask the user',
      );
    }
    final (category, categoryError) = resolveUnique(
      categoryArg,
      categoryPool,
      what: 'category',
      zeroGuidance: 'available categories: '
          '${categoryPool.map((a) => a.name).join(', ')}; pick the closest '
          'one, or offer to create it via the categories form',
    );
    if (categoryError != null) return categoryError;

    // ── 提案(ADR-1:零落库;typed 域对象保证不变量后序列化)。──
    final description = lenientString(args['description']) ?? '';
    final action = TransactionAdd(
      direction: direction,
      amountCents: amountCents!,
      description: description,
      accountId: account!.id,
      categoryId: category!.id,
      date: date,
    );
    return ToolData({
      'requiresApproval': true,
      'action': {
        'type': 'transaction_add',
        'direction': direction.wire,
        'amountCents': action.amountCents,
        'description': action.description,
        'accountId': action.accountId,
        'categoryId': action.categoryId,
        'date': isoDate(action.date),
      },
      'preview': {
        'direction': direction.wire,
        'amountCents': action.amountCents,
        'amountYuan': yuan(action.amountCents),
        'description': action.description,
        'account': account.name,
        'category': category.name,
        'date': isoDate(action.date),
      },
    });
  }
}
