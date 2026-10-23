// F64-T3 —— accounts_list 只读工具(FR-2/NFR-2,载体户+占用口径)。
//
// 流程:AccountRepository.list() → AccountVisibility 过滤(载体户出局,
// total_count 不计,与 UI 账户页同口径)→ kind 过滤(对齐 AccountType
// 值域)→ 按 accountType 分组汇总 → 分页页片;信用卡类每卡附已用/可用
// (F50 占用口径:卡欠款 + Σ挂卡 card_loan 未出账期次本金 —— 复用
// debt/domain/debt_query.cardLoanOccupationCents 唯一实现,accounts_page
// 同款;期表经 DebtRepository.get 拉取,单债失败静默跳过 = 计 0,与页面
// 降级语义一致)。金额全部 cents + 元双口径(ADR-6);逐分一致由
// tools_caliber_test 参数化钉死(NFR-1)。
library;

import 'package:yucai_client/account/domain/account_visibility.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/assistant/data/tools/tool_args.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/debt/domain/debt_query.dart'
    show cardLoanOccupationCents;
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

/// 账户列表工具:分类汇总 + 每户余额(卡含已用/可用),kind 过滤 + 分页。
class AccountsListTool implements AssistantTool {
  AccountsListTool(this._accounts, this._debts, [this._clock]);

  final AccountRepository _accounts;
  final DebtRepository _debts;

  /// 占用口径「未出账」分界时钟(测试注入;缺省当前时刻)。
  final DateTime Function()? _clock;

  /// kind 合法值 = AccountType 值域名(const 硬编码副本 —— parametersSchema
  /// 的 const enum 需要编译期常量,无法从枚举派生)。**对齐守卫测试**钉死
  /// 与 `AccountType.values` 派生集一致(评审 fixlist M2:漂移即红,
  /// 见 accounts_list_tool_test「legalKinds alignment guard」)。
  static const legalKinds = [
    'asset',
    'liability',
    'equity',
    'income',
    'expense',
  ];

  @override
  String get name => 'accounts_list';

  @override
  String get description =>
      'Lists the user accounts visible in the app (system bookkeeping '
      'carriers are hidden, same as the accounts page): per-type subtotal '
      'summary plus a paginated page of accounts with name/type/balance. '
      'Credit cards also show used/available credit including attached '
      'card-loan occupation. Optional kind filter: asset, liability, '
      'equity, income, expense. Use for "which accounts do I have / how '
      'much is on my credit card". Not for holdings or single-account '
      'transaction history.';

  @override
  Map<String, Object> get parametersSchema => const {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': legalKinds,
            'description': 'Optional account type filter.',
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
    final kind = lenientString(args['kind'])?.toLowerCase();
    final invalid = checkKindFilter(kind, legalKinds);
    if (invalid != null) return invalid;
    final page = parsePagination(args);

    final result = await _accounts.list();
    final List<Account>? all = result.fold((l) => null, (r) => r);
    if (all == null) {
      return const ToolError(
        'failed to load accounts from the local store; '
        'ask the user to retry later',
      );
    }

    // 载体户出局(展示层同口径)→ kind 过滤。
    var visible = AccountVisibility.userVisible(all);
    if (kind != null) {
      // 评审 fixlist L1:未知 kind 不静默按 asset 兜底 —— 白名单
      // (checkKindFilter)理论已拦,防御路径仍显式 ToolError 自纠。
      final matches =
          AccountType.values.where((e) => e.name == kind).toList();
      if (matches.isEmpty) {
        return ToolError(
          'invalid kind "$kind"; allowed values: ${legalKinds.join(', ')}',
        );
      }
      visible = visible.where((a) => a.accountType == matches.single).toList();
    }

    // 分组汇总(按 accountType:count + subtotal 双口径)。
    final groups = <Map<String, Object>>[];
    for (final type in AccountType.values) {
      final bucket = visible.where((a) => a.accountType == type).toList();
      if (bucket.isEmpty) continue;
      final subtotal = bucket.fold(0, (s, a) => s + a.currentBalanceCents);
      groups.add({
        'type': type.name,
        'count': bucket.length,
        'subtotalCents': subtotal,
        'subtotalYuan': yuan(subtotal),
      });
    }

    // 页片(repo 行序稳定;信用卡类补 F50 占用字段)。
    final start = (page.page - 1) * page.pageSize;
    final slice = start >= visible.length
        ? const <Account>[]
        : visible.skip(start).take(page.pageSize).toList();
    // 评审 fixlist L2:整页一次拉借入债列表下传(镜像 accounts_page
    // _loadDebts 整页一次范式),_occupationFor 不再逐卡重拉;
    // 页片无信用卡 → 完全不触发债务取数;失败降级空表(占用计 0)。
    final hasCard = slice.any((a) => a.category == AccountCategory.creditCard);
    List<Debt> borrowedInDebts = const [];
    if (hasCard) {
      final r = await _debts.list(typeFilter: DebtType.borrowedIn);
      r.fold((_) {}, (list) => borrowedInDebts = list);
    }
    final items = <Map<String, Object>>[
      for (final a in slice) await _itemOf(a, borrowedInDebts),
    ];

    return ToolData({
      if (kind != null) 'kind': kind,
      'groups': groups,
      'accounts': items,
      ...paginationMeta(
        page: page.page,
        pageSize: page.pageSize,
        totalCount: visible.length,
      ),
    });
  }

  /// 单账户页片项;信用卡补 {limitCents/limitYuan, usedCents/usedYuan,
  /// availableCents/availableYuan}(F50:已用 = 欠款 + 挂卡占用,可用 =
  /// 限额 − 已用,与 accounts_page「已用/可用」同式;金额字段双口径,
  /// limitYuan 为评审 fixlist L3 补配对)。
  Future<Map<String, Object>> _itemOf(Account a, List<Debt> debts) async {
    final item = <String, Object>{
      'name': a.name,
      'type': a.accountType.name,
      'balanceCents': a.currentBalanceCents,
      'balanceYuan': yuan(a.currentBalanceCents),
    };
    if (a.category != AccountCategory.creditCard) return item;

    final occupation = await _occupationFor(a.id, debts);
    final used = a.currentBalanceCents.abs() + occupation;
    item
      ..['limitCents'] = a.creditLimitCents
      ..['limitYuan'] = yuan(a.creditLimitCents)
      ..['usedCents'] = used
      ..['usedYuan'] = yuan(used)
      ..['availableCents'] = a.creditLimitCents - used
      ..['availableYuan'] = yuan(a.creditLimitCents - used);
    return item;
  }

  /// 挂接该卡的卡贷未出账占用(cardLoanOccupationCents 唯一实现,镜像
  /// accounts_page._cardLoanSchedulesOf:只拉挂卡 card_loan 的期表,单债
  /// 失败静默跳过 = 缺项计 0)。[debts] 为 execute 一次拉取的借入债列表
  /// (评审 fixlist L2:不再逐卡重拉);无挂卡债 → 0。
  Future<int> _occupationFor(String cardId, List<Debt> debts) async {
    final attached = debts
        .where((d) =>
            d.subtype == DebtSubtypes.cardLoan &&
            d.collectionAccountId == cardId)
        .toList();
    if (attached.isEmpty) return 0;

    final schedules = <String, List<PaymentEntry>>{};
    for (final d in attached) {
      final detail = await _debts.get(d.id);
      detail.fold((_) {}, (v) => schedules[d.id] = v.schedule);
    }
    return cardLoanOccupationCents(
      debts,
      cardId,
      schedules,
      now: _clock?.call(),
    );
  }
}
