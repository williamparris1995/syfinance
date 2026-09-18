import 'package:drift/drift.dart' hide Column;
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart'
    show CreateAccountParams;
import 'package:yucai_client/account/domain/value_objects.dart' as acct_vo;
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/recurrence/next_after.dart';
import 'package:yucai_client/core/recurrence/recurrence_rule.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/debt_dao.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/debt/domain/debt_query.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

/// 一次性利息减免(镜像 server domain.ApplyInterestWaiver):
/// 最早几期依次扣减、逐期触底、余量后移;total 重建保持本息一致。
void applyInterestWaiver(
    List<db.PaymentScheduleEntriesCompanion> entries, int waiver) {
  if (waiver <= 0) return;
  var left = waiver;
  for (var i = 0; i < entries.length && left > 0; i++) {
    final cur = entries[i].interestCents.value;
    final take = cur > left ? left : cur;
    final newInterest = cur - take;
    entries[i] = entries[i].copyWith(
      interestCents: Value(newInterest),
      totalCents: Value(entries[i].principalCents.value + newInterest),
    );
    left -= take;
  }
}

/// Guest-mode data source for the debt module (R6, C-paradigm).
///
/// Double-entry linkage mirrors the server (debt_handler.go:450-462 and
/// buildCreateEntries): repayment borrowedIn = credit from + debit debt
/// account, repayment borrowedOut = debit from + credit debt account;
/// borrowedOut create = credit source (cash−) + debit receivable+.
@LazySingleton()
class DebtLocalDataSource {
  DebtLocalDataSource(this._database, this._txns,
      {Uuid? uuid, AccountLocalDataSource? accounts})
      : _uuid = uuid ?? const Uuid(),
        _accounts = accounts ?? AccountLocalDataSource(_database);

  final db.AppDatabase _database;
  final TransactionLocalDataSource _txns;
  final Uuid _uuid;
  final AccountLocalDataSource _accounts;

  DebtDao get _dao => _database.debtDao;

  /// F9 FR-4/ADR-3:可选查询参数(in-memory,默认零变化)。
  ///
  /// - [searchText]:对手方 counterparty contains 忽略大小写(trim 后非空才
  ///   生效,null/空白 = 不过滤)。
  /// - [sortKey]/[sortDir]:四态排序(金额/到期日 × 升/降)。**null = 不排序**
  ///   (保持 DAO 行序,与既有调用逐位一致,NFR-2);传入时复用 domain 纯函数
  ///   [debtCompareQuery](与债务/债权两页前端管道同口径,复用第一)。
  ///   sortDir 缺省 asc(与列表页控件默认态对齐)。
  Future<List<Debt>> list({
    DebtType? typeFilter,
    String? searchText,
    DebtSortKey? sortKey,
    DebtSortDir? sortDir,
  }) async {
    final rows = await _dao.watchAllDebts().first;
    var debts = <Debt>[];
    for (final r in rows) {
      if (typeFilter != null && r.debtType != typeFilter.index + 1) continue;
      debts.add(await _toEntity(r));
    }
    if (searchText != null && searchText.trim().isNotEmpty) {
      debts = debts.where((d) => debtSearchMatches(d, searchText)).toList();
    }
    if (sortKey != null) {
      final dir = sortDir ?? DebtSortDir.asc;
      debts = [...debts]..sort((a, b) => debtCompareQuery(a, b, sortKey, dir));
    }
    return debts;
  }

  Future<DebtDetail> get(String id) async {
    final row = await _require(id);
    final schedule = await _dao.watchScheduleByDebt(id).first;
    return DebtDetail(
      debt: await _toEntity(row),
      schedule: schedule.map(_paymentView).toList(),
    );
  }

  Future<Debt> create({
    required String accountId,
    required String counterparty,
    required double interestRate,
    required int amortizationIndex,
    required DateTime startDate,
    required DateTime dueDate,
    required int totalPrincipalCents,
    required DebtType type,
    String subtype = '',
    String? sourceAccountId,
    String contact = '',
    String contractRef = '',
    String guarantorName = '',
    String guarantorContact = '',
    String? collectionAccountId,
    int cycle = 2,
    int interval = 1,
    int weekdayMask = 0,
    int monthlyMode = 0,
    int nth = 0,
    int termPeriods = 0,
    int interestWaivedCents = 0,
    bool markPending = false,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final rule = RecurrenceRule.fromInts(
        cycle: cycle,
        interval: interval,
        weekdayMask: weekdayMask,
        monthlyMode: monthlyMode,
        nth: nth);
    // 按期数模式:due 由末个发生日推导(镜像 server CreateDebt)。
    var due = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
    if (termPeriods > 0) {
      final dates = scheduleDatesFrom(rule, start, due, termPeriods);
      due = dates.last;
    }
    await _database.transaction(() async {
      await _dao.insertDebt(db.DebtsCompanion.insert(
        id: id,
        accountId: accountId,
        counterparty: counterparty,
        interestRate: interestRate,
        amortizationMethod: amortizationIndex + 1,
        cycle: Value(cycle),
        interval: Value(interval),
        weekdayMask: Value(weekdayMask),
        monthlyMode: Value(monthlyMode),
        nth: Value(nth),
        interestWaivedCents: Value(interestWaivedCents),
        startDate: start,
        dueDate: due,
        totalPrincipalCents: totalPrincipalCents,
        debtType: type.index + 1,
        subtype: subtype,
        contact: contact,
        contractRef: contractRef,
        guarantorName: Value(guarantorName),
        guarantorContact: Value(guarantorContact),
        collectionAccountId: Value(collectionAccountId),
        version: 1,
        createdAt: now,
        updatedAt: now,
        syncState: syncStateValue(markPending),
      ));
      // Amortization schedule at create (rule-driven;镜像 server 新
      // AmortizationCalculator:日期 = scheduleDatesFrom,金额 = 期利率公式,
      // 月度 interval=1 与旧算法逐位一致)。
      final generated = _generateSchedule(
        debtId: id,
        method: amortizationIndex,
        rule: rule,
        startDate: start,
        dueDate: due,
        termPeriods: termPeriods,
        totalPrincipalCents: totalPrincipalCents,
        interestRate: interestRate,
      );
      // 一次性利息减免(镜像 server ApplyInterestWaiver):最早几期依次扣减。
      applyInterestWaiver(generated, interestWaivedCents);
      for (final e in generated) {
        await _dao.insertScheduleEntry(e);
      }
      // borrowedIn create double-writes cash IN(user-acceptance 补齐;server
      // 现状借入创建不入账 → 净资产误降,经济学上缺现金侧 —— 本地先对齐
      // 用户语义,server 侧跟随为后续 ticket):
      //   debit 到账账户(资产 +本金)/ credit 关联债务账户(负债 +本金)。
      if (type == DebtType.borrowedIn && (sourceAccountId ?? '').isNotEmpty) {
        final dst = await _database.accountDao.getAccountById(sourceAccountId!);
        if (dst == null) throw const ServerFailure('到账账户不存在');
        await _txns.recordTransaction(
            RecordTransactionParams(
          transactionDate:
              DateTime.utc(startDate.year, startDate.month, startDate.day),
          description: '借入 $counterparty 到账',
          entries: [
            TransactionEntry(
                accountId: sourceAccountId,
                debitCents: totalPrincipalCents,
                creditCents: 0),
            TransactionEntry(
                accountId: accountId,
                debitCents: 0,
                creditCents: totalPrincipalCents),
          ],
        ), markPending: markPending);
      }
      // borrowedOut create double-writes cash out (server buildCreateEntries):
      // credit source (cash−) + debit receivable account (+).
      if (type == DebtType.borrowedOut && (sourceAccountId ?? '').isNotEmpty) {
        final src = await _database.accountDao.getAccountById(sourceAccountId!);
        if (src == null) throw const ServerFailure('资金账户不存在');
        await _txns.recordTransaction(
            RecordTransactionParams(
          transactionDate:
              DateTime.utc(startDate.year, startDate.month, startDate.day),
          description: '借出 $counterparty',
          entries: [
            TransactionEntry(
                accountId: sourceAccountId,
                debitCents: 0,
                creditCents: totalPrincipalCents),
            TransactionEntry(
                accountId: accountId,
                debitCents: totalPrincipalCents,
                creditCents: 0),
          ],
        ), markPending: markPending);
      }
    });
    return _toEntity(await _require(id));
  }

  /// 影响期次的参数(摊销方法/到期日/期数/周期规则)可选传入:
  /// null/0 = 保持现状(旧调用方行为不变);任一变化即触发
  /// Google-Calendar 式重排 —— 已发生期次(paid/paidCents>0/关联交易)冻结,
  /// 未发生期次按新参数从剩余本金重排(镜像 server UpdateDebt)。
  Future<Debt> update({
    required String id,
    required String counterparty,
    required double interestRate,
    required int version,
    String contact = '',
    String contractRef = '',
    String guarantorName = '',
    String guarantorContact = '',
    String? collectionAccountId,
    int? amortizationIndex,
    DateTime? dueDate,
    int termPeriods = 0,
    int? cycle,
    int? interval,
    int? weekdayMask,
    int? monthlyMode,
    int? nth,
    int? interestWaivedCents,
    bool markPending = false,
  }) async {
    final row = await _require(id);
    if (row.version != version) {
      throw const ServerFailure('数据已过期，请刷新后重试');
    }
    final newMethod = amortizationIndex ?? row.amortizationMethod - 1;
    final newCycle = cycle ?? row.cycle;
    final newInterval = interval ?? row.interval;
    final newWeekdayMask = weekdayMask ?? row.weekdayMask;
    final newMonthlyMode = monthlyMode ?? row.monthlyMode;
    final newNth = nth ?? row.nth;
    final newWaiver = interestWaivedCents ?? row.interestWaivedCents;
    final newDue = dueDate == null
        ? row.dueDate
        : DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
    final rule = RecurrenceRule.fromInts(
        cycle: newCycle,
        interval: newInterval,
        weekdayMask: newWeekdayMask,
        monthlyMode: newMonthlyMode,
        nth: newNth);
    final scheduleChanged = newMethod != row.amortizationMethod - 1 ||
        interestRate != row.interestRate ||
        rule != RecurrenceRule.fromInts(
            cycle: row.cycle,
            interval: row.interval,
            weekdayMask: row.weekdayMask,
            monthlyMode: row.monthlyMode,
            nth: row.nth) ||
        (dueDate != null && newDue != row.dueDate) ||
        termPeriods > 0 ||
        newWaiver != row.interestWaivedCents;

    var effectiveDue = newDue;
    await _database.transaction(() async {
      if (scheduleChanged) {
        // 一次性读(勿用 watch().first:流式查询在事务占用的单连接上会死锁)。
        final schedule = await _dao.getScheduleByDebt(id);
        final frozen = schedule
            .where((e) => e.paid || e.paidCents > 0 || (e.transactionId ?? '').isNotEmpty)
            .toList()
          ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));
        final anchor = frozen.isEmpty
            ? DateTime.utc(row.startDate.year, row.startDate.month, row.startDate.day)
            : frozen.last.paymentDate;
        var paidPrincipal = 0;
        for (final e in frozen) {
          paidPrincipal += e.principalCents;
        }
        final remaining =
            (row.totalPrincipalCents - paidPrincipal).clamp(0, row.totalPrincipalCents);
        final dates = scheduleDatesFrom(rule, anchor, newDue, termPeriods);
        effectiveDue = dates.last;
        // 删除未冻结期次,插入重排后的未来期次。
        final futures = _generateFutureSchedule(
          debtId: id,
          method: newMethod,
          rule: rule,
          anchor: anchor,
          dates: dates,
          remainingPrincipalCents: remaining,
          interestRate: interestRate,
        );
        applyInterestWaiver(futures, newWaiver);
        // 减免超剩余期次利息总额 → 拒绝(镜像 server)。
        final totalInterest =
            futures.fold(0, (a, e) => a + e.interestCents.value);
        if (newWaiver > totalInterest) {
          throw const ValidationFailure('利息减免不能超过利息总额');
        }
        // 删除未冻结期次(逐条;冻结判定与 server ReplaceFutureSchedule
        // 的 SQL 条件 paid=false AND paid_cents=0 AND transaction_id IS NULL 互补)。
        for (final e in schedule) {
          final isFrozen =
              e.paid || e.paidCents > 0 || (e.transactionId ?? '').isNotEmpty;
          if (!isFrozen) {
            await _dao.deleteScheduleEntry(e.id);
          }
        }
        for (final e in futures) {
          await _dao.insertScheduleEntry(e);
        }
      }
      await _dao.updateDebt(db.DebtsCompanion(
        id: Value(id),
        counterparty: Value(counterparty),
        interestRate: Value(interestRate),
        amortizationMethod: Value(newMethod + 1),
        cycle: Value(newCycle),
        interval: Value(newInterval),
        weekdayMask: Value(newWeekdayMask),
        monthlyMode: Value(newMonthlyMode),
        nth: Value(newNth),
        interestWaivedCents: Value(newWaiver),
        dueDate: Value(effectiveDue),
        contact: Value(contact),
        contractRef: Value(contractRef),
        guarantorName: Value(guarantorName),
        guarantorContact: Value(guarantorContact),
        collectionAccountId: Value(collectionAccountId),
        version: Value(row.version + 1),
        updatedAt: Value(DateTime.now().toUtc()),
        syncState: markPending
            ? const Value(SyncState.pending)
            : const Value.absent(),
      ));
    });
    return _toEntity(await _require(id));
  }

  /// 单期改日(Google-Calendar 式;镜像 server SetPaymentDate):
  /// 已还期次冻结;目标日期不得撞同一债务的其他期次;不得早于起始日。
  /// 头行版本 +1 并置 pending(期次整包随 T3 收集器上行)。
  Future<PaymentEntry> setPaymentDate({
    required String debtId,
    required String entryId,
    required DateTime paymentDate,
    bool markPending = false,
  }) async {
    final row = await _require(debtId);
    final schedule = await _dao.getScheduleByDebt(debtId);
    final entry = schedule.where((s) => s.id == entryId).firstOrNull;
    if (entry == null) throw const ServerFailure('还款期次不存在');
    if (entry.paid || entry.paidCents > 0 || (entry.transactionId ?? '').isNotEmpty) {
      throw const ServerFailure('该期次已还款，不可修改');
    }
    final newDate =
        DateTime.utc(paymentDate.year, paymentDate.month, paymentDate.day);
    if (!newDate.isAfter(DateTime.utc(row.startDate.year, row.startDate.month, row.startDate.day))) {
      throw const ValidationFailure('还款日期需晚于借出日期');
    }
    for (final other in schedule) {
      if (other.id != entryId &&
          other.paymentDate.year == newDate.year &&
          other.paymentDate.month == newDate.month &&
          other.paymentDate.day == newDate.day) {
        throw const ValidationFailure('该日期已有其他还款计划');
      }
    }
    await _database.transaction(() async {
      await _dao.updateScheduleEntry(db.PaymentScheduleEntriesCompanion(
        id: Value(entryId),
        paymentDate: Value(newDate),
      ));
      await _dao.updateDebt(db.DebtsCompanion(
        id: Value(debtId),
        version: Value(row.version + 1),
        updatedAt: Value(DateTime.now().toUtc()),
        syncState: markPending
            ? const Value(SyncState.pending)
            : const Value.absent(),
      ));
    });
    final updated = await _dao.getScheduleEntryById(entryId);
    return _paymentView(updated!);
  }

  /// 标记已还(历史还款,不记账;镜像 server MarkEntryPaid):
  /// paid/paidCents 落库,TransactionID 保持 null(区别于真实记账还款);
  /// 头行版本 +1 并置 pending。再标记 → 拒绝(冻结)。
  Future<PaymentEntry> markEntryPaid({
    required String debtId,
    required String entryId,
    bool markPending = false,
  }) async {
    final row = await _require(debtId);
    final schedule = await _dao.getScheduleByDebt(debtId);
    final entry = schedule.where((s) => s.id == entryId).firstOrNull;
    if (entry == null) throw const ServerFailure('还款期次不存在');
    if (entry.paid || entry.paidCents > 0 || (entry.transactionId ?? '').isNotEmpty) {
      throw const ServerFailure('该期次已还款，不可重复标记');
    }
    await _database.transaction(() async {
      await _dao.updateScheduleEntry(db.PaymentScheduleEntriesCompanion(
        id: Value(entryId),
        paid: const Value(true),
        paidCents: Value(entry.totalCents),
      ));
      await _dao.updateDebt(db.DebtsCompanion(
        id: Value(debtId),
        version: Value(row.version + 1),
        updatedAt: Value(DateTime.now().toUtc()),
        syncState: markPending
            ? const Value(SyncState.pending)
            : const Value.absent(),
      ));
      // 结转平衡分录:标记已还虽然当年没有走账,但债务账户余额必须与剩余
      // 同步下降,否则「个人待还款」等账户与债务模块永久对不上。对方科目 =
      // 系统权益户「历史还款结转」(期初调整的会计惯例),自动兜底补建。
      final isBorrowedIn = row.debtType == DebtType.borrowedIn.index + 1;
      final settlement = await _ensureSettlementAccount(markPending: markPending);
      await _txns.recordTransaction(
          RecordTransactionParams(
        transactionDate: entry.paymentDate,
        description: '标记已还 ${row.counterparty}',
        entries: [
          // borrowedIn:负债下降 = 借记债务户;borrowedOut(债权):资产下降 = 贷记。
          TransactionEntry(
              accountId: row.accountId,
              debitCents: isBorrowedIn ? entry.totalCents : 0,
              creditCents: isBorrowedIn ? 0 : entry.totalCents),
          TransactionEntry(
              accountId: settlement,
              debitCents: isBorrowedIn ? 0 : entry.totalCents,
              creditCents: isBorrowedIn ? entry.totalCents : 0),
        ],
      ), markPending: markPending);
    });
    final updated = await _dao.getScheduleEntryById(entryId);
    return _paymentView(updated!);
  }

  /// 兜底补建系统权益户「历史还款结转」(幂等:同名+同类型复用)。
  Future<String> _ensureSettlementAccount({bool markPending = false}) async {
    const name = '历史还款结转';
    const wantType = 3; // AccountType.equity
    final existing = await _database.select(_database.accounts).get();
    final match = existing
        .where((a) => a.name == name && a.accountType == wantType)
        .firstOrNull;
    if (match != null) return match.id;
    final created = await _accounts.create(
      CreateAccountParams(
        name: name,
        accountType: acct_vo.AccountType.equity,
        category: acct_vo.AccountCategory.otherAsset,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        ownership: acct_vo.Ownership.personal,
      ),
      markPending: markPending,
    );
    return created.id;
  }

  /// [writeTombstone]:bound 路由删除硬删行后补墓碑(FR-4);guest 删除不写
  /// 墓碑(绑定走全量首传)。
  Future<void> delete(String id, {bool writeTombstone = false}) async {
    if (await _dao.getDebtById(id) == null) throw const ServerFailure('债务不存在');
    await _database.transaction(() async {
      await _dao.deleteDebtById(id); // schedule cascades
      if (writeTombstone) {
        await _database.syncTombstoneDao.upsertTombstone(
            db.SyncTombstonesCompanion.insert(
                module: SyncModule.debt,
                entityId: id,
                deletedAt: DateTime.now().toUtc()));
      }
    });
  }

  /// [markPending]:复合写(FR-3)—— 还款双分录交易头行与债务头行在同一
  /// 事务内置 pending(债务头行本身未变字段,但期次已还的本地事实须由
  /// pending 状态保护,镜像刷新不得抹掉;T3 收集器按头行收集整包)。
  Future<PaymentEntry> recordPayment({
    required String debtId,
    required String scheduleEntryId,
    required String fromAccountId,
    bool markPending = false,
  }) async {
    final row = await _require(debtId);
    final schedule = await _dao.watchScheduleByDebt(debtId).first;
    final entry = schedule.where((s) => s.id == scheduleEntryId).firstOrNull;
    if (entry == null) throw const ServerFailure('还款期次不存在');
    if (entry.paid) throw const ServerFailure('该期次已还款');

    late PaymentEntry paid;
    await _database.transaction(() async {
      // Double-entry repayment (server debt_handler.go:450-462):
      // borrowedIn = credit from + debit debt (liability−);
      // borrowedOut = debit from + credit debt (receivable−).
      final isBorrowedIn = row.debtType == DebtType.borrowedIn.index + 1;
      final txn = await _txns.recordTransaction(
          RecordTransactionParams(
        transactionDate: entry.paymentDate,
        description: '还款 ${row.counterparty}',
        entries: [
          TransactionEntry(
              accountId: isBorrowedIn ? row.accountId : fromAccountId,
              debitCents: entry.totalCents,
              creditCents: 0),
          TransactionEntry(
              accountId: isBorrowedIn ? fromAccountId : row.accountId,
              debitCents: 0,
              creditCents: entry.totalCents),
        ],
      ), markPending: markPending);
      await _dao.updateScheduleEntry(db.PaymentScheduleEntriesCompanion(
        id: Value(scheduleEntryId),
        paid: const Value(true),
        paidCents: Value(entry.totalCents),
        transactionId: Value(txn.id),
      ));
      if (markPending) {
        // 债务头行置 pending:期次已还的本地事实随头行被镜像协调保护。
        await _dao.updateDebt(db.DebtsCompanion(
          id: Value(debtId),
          syncState: const Value(SyncState.pending),
        ));
      }
      paid = _paymentView(
          (await _dao.getScheduleEntryById(scheduleEntryId))!);
    });
    return paid;
  }

  Future<List<Debt>> upcomingPayments(int daysAhead) async {
    final rows = await _dao.watchAllDebts().first;
    final deadline = DateTime.now().toUtc().add(Duration(days: daysAhead));
    final out = <Debt>[];
    for (final r in rows) {
      final e = await _toEntity(r);
      if (e.nextPaymentDate != null && !e.nextPaymentDate!.isAfter(deadline)) {
        out.add(e);
      }
    }
    return out;
  }

  // ---- amortization(rule-driven;镜像 server 新 AmortizationCalculator) ----

  List<db.PaymentScheduleEntriesCompanion> _generateSchedule({
    required String debtId,
    required int method, // AmortizationMethod.index
    required RecurrenceRule rule,
    required DateTime startDate,
    required DateTime dueDate,
    required int termPeriods,
    required int totalPrincipalCents,
    required double interestRate,
  }) {
    final dates = scheduleDatesFrom(rule, startDate, dueDate, termPeriods);
    return _buildEntries(
      debtId: debtId,
      method: method,
      rule: rule,
      anchor: startDate,
      dates: dates,
      principalCents: totalPrincipalCents,
      annualRate: interestRate,
    );
  }

  /// 编辑重排:未来期次 = 剩余本金按新参数生成(冻结期次由调用方保留)。
  List<db.PaymentScheduleEntriesCompanion> _generateFutureSchedule({
    required String debtId,
    required int method,
    required RecurrenceRule rule,
    required DateTime anchor,
    required List<DateTime> dates,
    required int remainingPrincipalCents,
    required double interestRate,
  }) =>
      _buildEntries(
        debtId: debtId,
        method: method,
        rule: rule,
        anchor: anchor,
        dates: dates,
        principalCents: remainingPrincipalCents,
        annualRate: interestRate,
      );

  List<db.PaymentScheduleEntriesCompanion> _buildEntries({
    required String debtId,
    required int method,
    required RecurrenceRule rule,
    required DateTime anchor,
    required List<DateTime> dates,
    required int principalCents,
    required double annualRate,
  }) {
    switch (method) {
      case 2: // lumpSum
        return _lumpSum(debtId, anchor, dates, principalCents, annualRate, rule);
      case 1: // equalPrincipal
        return _equalPrincipal(debtId, dates, principalCents, annualRate, rule);
      case 3: // interestFirst(先息后本)
        return _interestFirst(debtId, dates, principalCents, annualRate, rule);
      default: // equalPrincipalInterest(未知 → 默认,与 server 一致)
        return _equalInstallment(debtId, dates, principalCents, annualRate, rule);
    }
  }

  /// 先息后本:每期付全本金×期利率的利息,末期一次还本。
  List<db.PaymentScheduleEntriesCompanion> _interestFirst(String debtId,
      List<DateTime> dates, int principal, double rate, RecurrenceRule rule) {
    final n = dates.length;
    final periodRate = rate * periodYears(rule);
    final interest = (principal * periodRate).round();
    final out = <db.PaymentScheduleEntriesCompanion>[];
    for (var i = 0; i < n; i++) {
      final principalPart = i == n - 1 ? principal : 0;
      out.add(db.PaymentScheduleEntriesCompanion.insert(
        id: _uuid.v4(),
        debtId: debtId,
        paymentDate: dates[i],
        principalCents: principalPart,
        interestCents: interest,
        totalCents: principalPart + interest,
        paidCents: 0,
        paid: false,
      ));
    }
    return out;
  }

  List<db.PaymentScheduleEntriesCompanion> _lumpSum(String debtId,
      DateTime anchor, List<DateTime> dates, int principal, double rate,
      RecurrenceRule rule) {
    final last = dates.last;
    double years;
    if (rule.cycle == RecurrenceCycle.monthly) {
      years = monthsBetween(anchor, last) / 12.0;
    } else {
      years = last.difference(anchor).inDays / 365;
      if (years <= 0) years = periodYears(rule) * dates.length;
    }
    final interest = (principal * rate * years).round();
    return [
      db.PaymentScheduleEntriesCompanion.insert(
        id: _uuid.v4(),
        debtId: debtId,
        paymentDate: last,
        principalCents: principal,
        interestCents: interest,
        totalCents: principal + interest,
        paidCents: 0,
        paid: false,
      )
    ];
  }

  List<db.PaymentScheduleEntriesCompanion> _equalPrincipal(String debtId,
      List<DateTime> dates, int principal, double rate, RecurrenceRule rule) {
    final n = dates.length;
    final periodRate = rate * periodYears(rule);
    final perPeriod = principal / n;
    var remaining = principal.toDouble();
    final out = <db.PaymentScheduleEntriesCompanion>[];
    for (var i = 0; i < n; i++) {
      final interest = (remaining * periodRate).round();
      final principalPart = i == n - 1 ? remaining.round() : perPeriod.round();
      out.add(db.PaymentScheduleEntriesCompanion.insert(
        id: _uuid.v4(),
        debtId: debtId,
        paymentDate: dates[i],
        principalCents: principalPart,
        interestCents: interest,
        totalCents: principalPart + interest,
        paidCents: 0,
        paid: false,
      ));
      remaining -= principalPart;
    }
    return out;
  }

  List<db.PaymentScheduleEntriesCompanion> _equalInstallment(String debtId,
      List<DateTime> dates, int principal, double rate, RecurrenceRule rule) {
    final n = dates.length;
    final periodRate = rate * periodYears(rule);
    final p = principal.toDouble();
    double payment;
    if (periodRate == 0) {
      payment = p / n;
    } else {
      final factor = _pow(1 + periodRate, n);
      payment = p * periodRate * factor / (factor - 1);
    }
    var remaining = p;
    final out = <db.PaymentScheduleEntriesCompanion>[];
    for (var i = 0; i < n; i++) {
      final interest = (remaining * periodRate).round();
      final principalPart =
          i == n - 1 ? remaining.round() : payment.round() - interest;
      out.add(db.PaymentScheduleEntriesCompanion.insert(
        id: _uuid.v4(),
        debtId: debtId,
        paymentDate: dates[i],
        principalCents: principalPart,
        interestCents: interest,
        totalCents: principalPart + interest,
        paidCents: 0,
        paid: false,
      ));
      remaining -= principalPart;
    }
    return out;
  }

  double _pow(double base, int exp) {
    var r = 1.0;
    for (var i = 0; i < exp; i++) {
      r *= base;
    }
    return r;
  }

  Future<db.Debt> _require(String id) async {
    final row = await _dao.getDebtById(id);
    if (row == null) throw const ServerFailure('债务不存在');
    return row;
  }

  PaymentEntry _paymentView(db.PaymentScheduleEntry s) => PaymentEntry(
        id: s.id,
        paymentDate: s.paymentDate,
        principalCents: s.principalCents,
        interestCents: s.interestCents,
        totalCents: s.totalCents,
        paid: s.paid,
        paidCents: s.paidCents,
        transactionId: s.transactionId ?? '',
      );

  Future<Debt> _toEntity(db.Debt r) async {
    final schedule = await _dao.watchScheduleByDebt(r.id).first;
    final unpaid = schedule.where((s) => !s.paid).toList()
      ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));
    final next = unpaid.firstOrNull;
    final paidCents = schedule.fold(0, (a, s) => a + s.paidCents);
    // 本息口径:未还期次利息合计(镜像 server RemainingInterest)。
    final unpaidInterest =
        unpaid.fold(0, (a, s) => a + s.interestCents);
    return Debt(
      id: r.id,
      accountId: r.accountId,
      counterparty: r.counterparty,
      interestRate: r.interestRate,
      amortization: AmortizationMethod.values[r.amortizationMethod - 1],
      startDate: r.startDate,
      dueDate: r.dueDate,
      totalPrincipalCents: r.totalPrincipalCents,
      remainingPrincipalCents: r.totalPrincipalCents - paidCents,
      version: r.version,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      type: DebtType.values[r.debtType - 1],
      cycle: r.cycle,
      interval: r.interval,
      weekdayMask: r.weekdayMask,
      monthlyMode: r.monthlyMode,
      nth: r.nth,
      interestWaivedCents: r.interestWaivedCents,
      unpaidInterestCents: unpaidInterest,
      subtype: r.subtype,
      contact: r.contact,
      contractRef: r.contractRef,
      guarantorName: r.guarantorName,
      guarantorContact: r.guarantorContact,
      collectionAccountId: r.collectionAccountId,
      nextPaymentDate: next?.paymentDate,
      nextPaymentAmountCents: next?.totalCents ?? 0,
      nextPaymentPeriodNo: next == null ? 0 : schedule.indexOf(next) + 1,
      remainingTrendCents: r.totalPrincipalCents - paidCents,
    );
  }
}
