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
          initialBalanceCents: a.initialBalanceCents,
          currencyCode: a.currencyCode,
        ),
    ];
  }

  @override
  Future<List<LedgerEntryRow>> entries() async {
    // 头行:交易日期(本地时区,墙钟不变式与 transaction_local_ds._toEntity
    // 同款 toLocal 修复;新行带本地 offset 为 no-op,旧行 Z 后缀被修复)。
    final heads = await _db.transactionDao.getAllTransactions();
    final dateByTxn = {
      for (final h in heads) h.id: h.transactionDate.toLocal(),
    };
    // 账户:denormalized 类型/账类(免逐条目查表)。
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
}
