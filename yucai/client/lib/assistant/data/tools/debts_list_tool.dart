// F64-T3 —— debts_list 只读工具(FR-2/NFR-2,credit-正不变式)。
//
// 流程:DebtRepository.list(borrowedIn)→ 未结清过滤(remainingPrincipalCents
// > 0,与 debt_query.debtMatchesListFilter 的 settled 判据同源)→ 每笔
// {counterparty / 剩余本金(cents+元)/ 下期应还 / 到期日 / 逾期标记}+
// 汇总{count, Σ剩余(cents+元)};分页宽松钳位(NFR-2 聚合摘要)。
//
// 到期日口径(F58/F61):card_loan 的 [Debt.nextPaymentDueDate] = 下期出账日
// (自由窗口不红);普通债为 null → 回落 [Debt.nextPaymentDate] 自身(实体
// 注释约定)。逾期 = 到期日 < 今天,**纯日期比较**(镜像 debtDueUrgency 的
// 当日 0 点对齐,剔除时刻/时区抖动:到期日 == 今天不算逾期)。
// nextPayment* 三字段由 debt data 层行映射实填 —— ADR-8 真库断言见
// debts_list_tool_test(策略 A:确有缺列才单点补 mapper)。
library;

import 'package:yucai_client/assistant/data/tools/tool_args.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

/// 债务列表工具:未结清借入债务(剩余本金 + 下期月供/到期日 + 逾期标记)。
class DebtsListTool implements AssistantTool {
  DebtsListTool(this._debts, [this._clock]);

  final DebtRepository _debts;

  /// 逾期判定的「今天」(测试注入;缺省当前时刻)。
  final DateTime Function()? _clock;

  @override
  String get name => 'debts_list';

  @override
  String get description =>
      'Lists unsettled borrowed-in debts (money the user owes): remaining '
      'principal per debt, next payment amount and due date, overdue flag, '
      'plus a count/total summary. Lent-out money (receivables) and fully '
      'repaid debts are excluded. Use for "what debts do I still owe / '
      'when is my next payment / am I overdue". Not for receivables or '
      'per-debt payment schedules.';

  @override
  Map<String, Object> get parametersSchema => const {
        'type': 'object',
        'properties': {
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
    final page = parsePagination(args);

    final result = await _debts.list(typeFilter: DebtType.borrowedIn);
    final List<Debt>? all = result.fold((l) => null, (r) => r);
    if (all == null) {
      return const ToolError(
        'failed to load debts from the local store; '
        'ask the user to retry later',
      );
    }

    // 未结清 = 剩余本金 > 0(与列表页 settled 判据同源);欠款恒正
    // (credit-正不变式)由此构造保证。
    final unsettled =
        all.where((d) => d.remainingPrincipalCents > 0).toList();
    final totalRemaining =
        unsettled.fold(0, (s, d) => s + d.remainingPrincipalCents);

    final now = _clock?.call() ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = (page.page - 1) * page.pageSize;
    final slice = start >= unsettled.length
        ? const <Debt>[]
        : unsettled.skip(start).take(page.pageSize).toList();

    return ToolData({
      'debts': [
        for (final d in slice)
          {
            'counterparty': d.counterparty,
            'remainingPrincipalCents': d.remainingPrincipalCents,
            'remainingPrincipalYuan': yuan(d.remainingPrincipalCents),
            'nextPaymentAmountCents': d.nextPaymentAmountCents,
            'nextPaymentAmountYuan': yuan(d.nextPaymentAmountCents),
            // F61:card_loan 到期日 = 下期出账日;普通债 null → 回落
            // nextPaymentDate 自身(实体口径约定);两者皆空(无期表)→ null。
            'nextPaymentDueDate':
                (d.nextPaymentDueDate ?? d.nextPaymentDate)?.toUtc().toIso8601String(),
            'overdue': _isOverdue(d, today),
          }
      ],
      'summary': {
        'count': unsettled.length,
        'totalRemainingCents': totalRemaining,
        'totalRemainingYuan': yuan(totalRemaining),
      },
      ...paginationMeta(
        page: page.page,
        pageSize: page.pageSize,
        totalCount: unsettled.length,
      ),
    });
  }

  /// 逾期 = 有效到期日(card_loan 用 nextPaymentDueDate,普通债回落
  /// nextPaymentDate)< 今天;纯日期比较(当日 0 点对齐,无时区抖动)。
  static bool _isOverdue(Debt d, DateTime today) {
    final due = d.nextPaymentDueDate ?? d.nextPaymentDate;
    if (due == null) return false;
    return DateTime(due.year, due.month, due.day).isBefore(today);
  }
}
