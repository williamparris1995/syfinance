/// F43 财务报告 —— [ReportLedgerStore] 的 drift adapter(T2,ADR-2)。
///
/// 直读 core/localdb DAO(core=共享基建,非任何模块私有):accounts =
/// AccountDao 全量行;entries = TransactionEntries × Transactions 头行
/// (date)× Accounts(denormalized 类型/账类)。读全量一次拉取,不做流式
/// 分页(YAGNI,NFR-1 性能测试钉门);表结构变化只改本 adapter(design
/// 风险表:drift schema 演进单点隔离)。
///
/// 换算口径(account_local_ds 写入口径,ADR-3):
/// - Accounts.accountType / Transactions 列存的 contract int 即 T1 行 VO
///   的 type(1 asset / 2 liability / 3 equity / 4 income / 5 expense);
/// - Accounts.category 本地 int = AccountCategory.index + 1(枚举共 10 项,
///   值域 1..10)→ 枚举名字符串;0/越界 = 旧数据缺失 → null(与
///   transaction_local_ds 的分类映射守卫同款)。不 import proto。
library;

import 'package:drift/drift.dart' hide Column;
import 'package:injectable/injectable.dart';

import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/recurrence/next_after.dart';
import 'package:yucai_client/core/recurrence/recurrence_rule.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/domain/report_ledger_store.dart';

@LazySingleton(as: ReportLedgerStore)
class ReportLedgerStoreImpl implements ReportLedgerStore {
  ReportLedgerStoreImpl(this._db);

  final db.AppDatabase _db;

  @override
  Future<List<AccountRow>> accounts() async {
    final rows = await _db.accountDao.getAllAccounts();
    return [
      for (final a in rows)
        AccountRow(
          id: a.id,
          type: a.accountType,
          category: _categoryName(a.category),
          // T5-R1:账户展示名带入(收支构成行显示科目名的数据源)。
          name: a.name,
          initialBalanceCents: a.initialBalanceCents,
          currencyCode: a.currencyCode,
        ),
    ];
  }

  @override
  Future<List<LedgerEntryRow>> entries() async {
    // 头行:交易日期 **raw 直通**(T2-R1 评审 Important,对齐 transaction
    // 模块唯一消费者 _toEntity L531 的口径)。镜像行(bound_mirror 写入
    // _utc → drift Z 后缀文本)读回即 UTC 形态:raw 任何时区都保有正确
    // 瞬间与 UTC 公历日;若做 toLocal,UTC 以西设备会把镜像行的日历日
    // 回退一天(月初行跨出报告期),污染按日历日分桶的下游。
    final heads = await _db.transactionDao.getAllTransactions();
    final dateByTxn = {
      for (final h in heads) h.id: h.transactionDate,
    };
    // 账户:denormalized 类型/账类(免逐条目查表)。accounts()/entries()
    // 各拉一次全表是有意的:accounts 表量级为用户账户数(个位~十位行),
    // 远小于分录表,二次读成本可忽略;adapter 保持无状态(快照语义,
    // 汇编单遍消费),不做跨方法缓存。
    final accountRows = await _db.accountDao.getAllAccounts();
    final typeById = {for (final a in accountRows) a.id: a.accountType};
    final categoryById = {
      for (final a in accountRows) a.id: _categoryName(a.category),
    };

    final out = [
      for (final e in await _db.transactionDao.getAllEntries())
        LedgerEntryRow(
          transactionId: e.transactionId,
          accountId: e.accountId,
          // 孤儿分录(accountId 不在账户表)= 科目已删的历史分录:
          // type 0 / category null 静默降级,basis/classifier/replay 自然
          // 跳过 —— **选择语义**(与下方孤儿头行 `!` fail-fast 不同:
          // 头行缺失=数据结构损坏必须炸,科目缺失=合法业务状态不计)。
          accountType: typeById[e.accountId] ?? 0,
          category: categoryById[e.accountId],
          date: dateByTxn[e.transactionId]!,
          debitCents: e.debitCents,
          creditCents: e.creditCents,
        ),
    ];
    // 日期升序(LLD 单遍口径;同日 tie-break 用 transactionId 保证输出
    // 确定 —— Dart List.sort 非稳定排序,消费者虽对顺序不敏感,确定性
    // 让测试与导出可复现)。
    out.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.transactionId.compareTo(b.transactionId);
    });
    return out;
  }

  /// 本地 category int(= 枚举 index+1)→ AccountCategory 枚举名;
  /// 越界(0/超上限)→ null(旧数据缺失)。
  static String? _categoryName(int stored) {
    if (stored < 1 || stored > AccountCategory.values.length) return null;
    return AccountCategory.values[stored - 1].name;
  }

  // ---- T4 追加:预算行 + 汇率读取(不动既有方法)----

  @override
  Future<List<BudgetRow>> budgetRows() async {
    // 头×item 扁平 join(holding_local_ds 同款直 select,core DAO 无
    // 全量 item 一把读方法;表结构变化仍单点隔离在本 adapter)。
    final heads = await _db.select(_db.budgets).get();
    final items = await _db.select(_db.budgetItems).get();
    final accountRows = await _db.accountDao.getAllAccounts();
    final accountById = {for (final a in accountRows) a.id: a};
    return [
      for (final head in heads)
        for (final item in items.where((i) => i.budgetId == head.id))
          BudgetRow(
            budgetId: head.id,
            month: head.month,
            itemId: item.id,
            accountId: item.accountId,
            accountCategory:
                _categoryName(accountById[item.accountId]?.category ?? 0),
            accountName: accountById[item.accountId]?.name,
            plannedCents: item.plannedAmountCents,
          ),
    ];
  }

  @override
  Future<RateQuote> rateToCny(String currencyCode, DateTime on) async {
    // 该日最近可得:≤ on 按 rateDate 倒序取首条。
    final hist = await (_db.select(_db.rateHistories)
          ..where((t) =>
              t.currencyCode.equals(currencyCode) &
              t.rateDate.isSmallerOrEqualValue(on))
          ..orderBy([(t) => OrderingTerm.desc(t.rateDate)])
          ..limit(1))
        .get();
    final current = await _db.referenceDao.getCurrencyByCode(currencyCode);
    return RateQuote(
      asOfRate: hist.isEmpty ? null : hist.first.exchangeRate,
      currentRate: current?.exchangeRate,
    );
  }

  // ---- T2(F44)追加:模板/交易两读法(MD&A supplement 输入)----

  @override
  Future<List<TemplateRowVO>> templateRows(ReportPeriod period) async {
    // 头行一次拉全:lastTransactionId → 交易日期 join(孤儿 id → null)。
    final dateByTxn = {
      for (final h in await _db.transactionDao.getAllTransactions())
        h.id: h.transactionDate,
    };
    return [
      for (final t in await _db.select(_db.transactionTemplates).get())
        TemplateRowVO(
          id: t.id,
          name: t.name,
          // 落库 int = TemplateDirection.index:1 expense / 2 income /
          // 3 transfer(template_local_ds 写入口径同款判别)。
          expense: t.direction == 1,
          amountCents: t.amountCents,
          paused: t.paused,
          autoRecord: t.autoRecord,
          nextDate: t.nextDate,
          lastRecordedDate: _dateOnlyOf(dateByTxn[t.lastTransactionId]),
          expectedDates: _expectedDates(t, period),
        ),
    ];
  }

  /// [t] 在 [period] 期内的应扣日(startDate 锚定系列)。
  ///
  /// 推演直用 core/recurrence(firstOnSeriesAfter + 链式 nextAfter,零
  /// 复制;interval>1 时系列锚定 startDate,不能从期初重锚)。endDate
  /// 之后不再期望(调度器「发生日 ≤ endDate 才记」同口径);模板侧日期
  /// 全为 UTC date-only,期界先折 UTC 公历日再比(直接比瞬间会在 UTC
  /// 以西设备把首日应扣日错挤出期)。maxSteps 耗尽防御(极早锚点+短
  /// 周期,5000 步仍未到期首):firstOnSeriesAfter 返回最后的推进点
  /// (< start)—— 直接空,关死期前日期灌入(唯一泄漏路径)。
  static List<DateTime> _expectedDates(
    db.TransactionTemplate t,
    ReportPeriod period,
  ) {
    final rule = RecurrenceRule.fromInts(
      cycle: t.cycle,
      cycleDays: t.cycleDays,
      billingDay: t.billingDay,
      interval: t.interval,
      weekdayMask: t.weekdayMask,
      monthlyMode: t.monthlyMode,
      nth: t.nth,
    );
    final anchor = _dateOnlyOf(t.startDate)!;
    final start = _dateOnlyOf(period.start)!;
    final end = _dateOnlyOf(period.endInclusive)!;
    var d = firstOnSeriesAfter(anchor, rule, start);
    if (d.isBefore(start)) return const [];
    final out = <DateTime>[];
    while (!d.isAfter(end)) {
      if (t.endDate == null || !d.isAfter(t.endDate!)) out.add(d);
      d = nextAfter(d, rule);
    }
    return out;
  }

  /// raw 日期 → date-only(取 raw 公历日,去时分秒;null 透传)。
  static DateTime? _dateOnlyOf(DateTime? d) =>
      d == null ? null : DateTime.utc(d.year, d.month, d.day);

  @override
  Future<List<LargeTxnVO>> transactions(ReportPeriod period) async {
    // 复用 entries() 读法:头行 + 分录 + 账户 denorm 类型(date raw 直通
    // 口径同 entries——镜像 Z 行按 UTC 公历日分桶,不做 toLocal)。
    final heads = await _db.transactionDao.getAllTransactions();
    final accountRows = await _db.accountDao.getAllAccounts();
    final typeById = {
      for (final a in accountRows) a.id: a.accountType,
    };
    final expenseByTxn = <String, int>{};
    for (final e in await _db.transactionDao.getAllEntries()) {
      if (typeById[e.accountId] != 5) continue; // 仅 expense 科目腿
      expenseByTxn[e.transactionId] =
          (expenseByTxn[e.transactionId] ?? 0) + e.debitCents;
    }
    final out = [
      for (final h in heads)
        if (period.contains(h.transactionDate))
          LargeTxnVO(
            transactionId: h.id,
            date: h.transactionDate,
            description: h.description,
            expenseCents: expenseByTxn[h.id] ?? 0,
          ),
    ]..retainWhere((t) => t.expenseCents > 0); // 候选集:零支出不进
    out.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.transactionId.compareTo(b.transactionId);
    });
    return out;
  }
}
