import 'package:drift/drift.dart' hide Column;
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/error/failures.dart';
// Hide the drift row class `Account` (and siblings) — the domain entity owns
// the name in this file; row types are only used via the DAO.
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/account_dao.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';


/// Guest-mode data source for the account module (R6 ADR-1): mirrors the
/// `AccountRemoteDataSource` surface on top of the local drift store.
/// Failures are thrown as core [Failure]s and pass through the repository's
/// `_guard` untouched (write semantics per ADR-4).
@LazySingleton()
class AccountLocalDataSource {
  AccountLocalDataSource(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final db.AppDatabase _db;
  final Uuid _uuid;

  static const _notFound = '账户不存在';

  AccountDao get _dao => _db.accountDao;

  Future<List<Account>> list() async =>
      (await _dao.getAllAccounts()).map(_toEntity).toList();

  /// Reactive tail of the accounts table (dev 反馈⑧b): drift watch mapped to
  /// domain entities. First emission carries the current rows; any later
  /// local write (category creation, balance update, mirror rebuild) fires
  /// again. Failures never surface — the stream is a live cache, callers
  /// keep their one-shot [list] path for first paint / error handling.
  Stream<List<Account>> watchList() =>
      _dao.watchAllAccounts().map((rows) => rows.map(_toEntity).toList());

  /// [markPending] 三态语义(F10 FR-3):guest 路由缺省 false → 行 synced
  /// (无上行语义);boundOfflineLocal / boundRemote 降级分支传 true →
  /// 行 pending 待回网上行(repo `_routedWrite` 落点)。
  Future<Account> create(CreateAccountParams p, {bool markPending = false}) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _dao.insertAccount(db.AccountsCompanion.insert(
      id: id,
      name: p.name,
      // Domain enum index + 1 = backup-contract int (ADR-3; server iotas
      // start at 1).
      accountType: p.accountType.index + 1,
      category: p.category.index + 1,
      currencyCode: p.currencyCode,
      initialBalanceCents: p.initialBalanceCents,
      currentBalanceCents: p.initialBalanceCents,
      ownership: p.ownership.index + 1,
      icon: p.icon,
      color: p.color,
      chartCode: '',
      parentId: Value(p.parentId.isEmpty ? null : p.parentId),
      // F49 并入模式载体户置位;缺省 false。update 为 patch 语义不触此列。
      isSystem: p.isSystem,
      sortOrder: 0,
      institution: p.institution,
      creditLimitCents: Value(p.creditLimitCents == 0 ? null : p.creditLimitCents),
      cardNumberTail: p.cardNumberTail,
      notes: p.notes,
      openingDate: Value(p.openingDate),
      interestRate: Value(p.interestRate),
      creditBillingDay: Value(p.creditBillingDay),
      creditRepaymentDay: Value(p.creditRepaymentDay),
      creditAnnualFeeCents: Value(p.creditAnnualFeeCents),
      investCostCents: Value(p.investCostCents),
      investMarketValueCents: Value(p.investMarketValueCents),
      investReturnYtd: Value(p.investReturnYtd),
      fixedPrincipalCents: Value(p.fixedPrincipalCents),
      fixedStartDate: Value(p.fixedStartDate),
      fixedMaturityDate: Value(p.fixedMaturityDate),
      fixedTermMonths: Value(p.fixedTermMonths),
      goldProductType: p.goldProductType,
      goldQuantity: Value(p.goldQuantity),
      goldBuyPriceCents: Value(p.goldBuyPriceCents),
      goldCurrentPriceCents: Value(p.goldCurrentPriceCents),
      estatePurchasePriceCents: Value(p.estatePurchasePriceCents),
      estateCurrentValueCents: Value(p.estateCurrentValueCents),
      estatePurchaseDate: Value(p.estatePurchaseDate),
      estateDepreciationRate: Value(p.estateDepreciationRate),
      loanOriginalCents: Value(p.loanOriginalCents),
      loanRemainingCents: Value(p.loanRemainingCents),
      loanMonthlyCents: Value(p.loanMonthlyCents),
      loanNextPaymentDate: Value(p.loanNextPaymentDate),
      status: AccountStatus.active.index + 1,
      version: 1,
      createdAt: now,
      updatedAt: now,
      syncState: syncStateValue(markPending),
    ));
    return (await _requireById(id))!;
  }

  Future<Account> getById(String id) async =>
      (await _requireById(id)) ?? (throw const ServerFailure(_notFound));

  /// [markPending]:bound 路由对 synced 行的本地 update 置回 pending(整行
  /// 待上行,FR-3);guest 路由缺省不改动 syncState。
  Future<Account> update(UpdateAccountParams p, {bool markPending = false}) async {
    final row = await _requireById(p.id);
    if (row == null) throw const ServerFailure(_notFound);
    // Optimistic-concurrency mirror of the remote 409: a stale version is
    // rejected instead of silently overwriting (ADR-4).
    if (p.version != row.version) {
      throw const ServerFailure('数据已过期，请刷新后重试');
    }
    // Patch semantics mirror the remote API: only non-default fields are
    // written ('' / 0 / null = leave untouched); the version bumps by one
    // (ADR-4). Value.absent() keeps the stored value.
    Value<String> str(String v) =>
        v.isEmpty ? const Value.absent() : Value(v);
    Value<int> nonZero(int v) => v == 0 ? const Value.absent() : Value(v);
    Value<T?> orAbsent<T>(T? v) => v == null ? const Value.absent() : Value(v);

    await _dao.updateAccount(db.AccountsCompanion(
      id: Value(p.id),
      name: str(p.name),
      icon: str(p.icon),
      color: str(p.color),
      parentId: p.parentId.isEmpty
          ? const Value.absent()
          : Value(p.parentId),
      institution: str(p.institution),
      cardNumberTail: str(p.cardNumberTail),
      notes: str(p.notes),
      goldProductType: str(p.goldProductType),
      creditLimitCents: nonZero(p.creditLimitCents),
      status: p.status == null
          ? const Value.absent()
          : Value(p.status!.index + 1),
      // F49 编辑切换同步:isSystem 三态(null = absent 不动,true/false 写)。
      isSystem: p.isSystem == null ? const Value.absent() : Value(p.isSystem!),
      openingDate: orAbsent(p.openingDate),
      interestRate: orAbsent(p.interestRate),
      // 账单日/还款日:显式值优先;清空旗标(独立→并入)且未带显式值 →
      // 写 NULL(转载体);否则 absent 不动。
      creditBillingDay: p.clearCreditScheduleDays && p.creditBillingDay == null
          ? const Value(null)
          : orAbsent(p.creditBillingDay),
      creditRepaymentDay:
          p.clearCreditScheduleDays && p.creditRepaymentDay == null
              ? const Value(null)
              : orAbsent(p.creditRepaymentDay),
      creditAnnualFeeCents: orAbsent(p.creditAnnualFeeCents),
      investCostCents: orAbsent(p.investCostCents),
      investMarketValueCents: orAbsent(p.investMarketValueCents),
      investReturnYtd: orAbsent(p.investReturnYtd),
      fixedPrincipalCents: orAbsent(p.fixedPrincipalCents),
      fixedStartDate: orAbsent(p.fixedStartDate),
      fixedMaturityDate: orAbsent(p.fixedMaturityDate),
      fixedTermMonths: orAbsent(p.fixedTermMonths),
      goldQuantity: orAbsent(p.goldQuantity),
      goldBuyPriceCents: orAbsent(p.goldBuyPriceCents),
      goldCurrentPriceCents: orAbsent(p.goldCurrentPriceCents),
      estatePurchasePriceCents: orAbsent(p.estatePurchasePriceCents),
      estateCurrentValueCents: orAbsent(p.estateCurrentValueCents),
      estatePurchaseDate: orAbsent(p.estatePurchaseDate),
      estateDepreciationRate: orAbsent(p.estateDepreciationRate),
      loanOriginalCents: orAbsent(p.loanOriginalCents),
      loanRemainingCents: orAbsent(p.loanRemainingCents),
      loanMonthlyCents: orAbsent(p.loanMonthlyCents),
      loanNextPaymentDate: orAbsent(p.loanNextPaymentDate),
      // 信用卡「当前欠款」手工校正（null = 不更新；负债余额 credit-正）。
      currentBalanceCents: p.currentBalanceCents == null
          ? const Value.absent()
          : Value(p.currentBalanceCents!),
      version: Value(row.version + 1),
      updatedAt: Value(DateTime.now().toUtc()),
      syncState: markPending ? const Value(SyncState.pending) : const Value.absent(),
    ));
    return (await _requireById(p.id))!;
  }

  /// [writeTombstone]:bound 路由删除硬删行后补墓碑(FR-4,防镜像
  /// delete-all+rebuild 复活);guest 删除不写墓碑(绑定走全量首传)。
  Future<void> delete(String id, {bool writeTombstone = false}) async {
    final row = await _requireById(id);
    if (row == null) throw const ServerFailure(_notFound);
    // Same guard and wording as the remote non-zero-balance rule — guest
    // habits must match bound habits (ADR-4). 守卫通过后的删除才墓碑。
    if (row.currentBalanceCents != 0) {
      throw const ServerFailure('账户余额非零，无法删除，请先清空余额或转账后再试');
    }
    // 引用守卫(镜像 server DeleteAccount R5-E decision 5):交易分录引用
    // 该账户时拒绝删除 —— 此前 guest 路径漏此检查,零余额但带历史交易的
    // 账户被删后分录成孤儿,触发启动自检「悬挂引用」横幅(2026-10-08)。
    // 归档(关闭账户)是带历史账户的正确归宿。
    final n = await _db.customSelect(
        'SELECT COUNT(*) AS n FROM transaction_entries WHERE account_id = ?',
        variables: [Variable.withString(id)]).getSingle();
    if ((n.data['n'] as int? ?? 0) > 0) {
      throw const ServerFailure('该账户有交易记录，无法删除；可改用「关闭账户」归档');
    }
    await _db.transaction(() async {
      await _dao.deleteAccountById(id);
      if (writeTombstone) {
        await _db.syncTombstoneDao.upsertTombstone(
            db.SyncTombstonesCompanion.insert(
                module: SyncModule.account,
                entityId: id,
                deletedAt: DateTime.now().toUtc()));
      }
    });
  }

  Future<Account?> _requireById(String id) async =>
      _dao.getAccountById(id).then((row) => row == null ? null : _toEntity(row));

  Account _toEntity(db.Account row) => Account(
        id: row.id,
        name: row.name,
        accountType: AccountType.values[row.accountType - 1],
        category: AccountCategory.values[row.category - 1],
        currencyCode: row.currencyCode,
        initialBalanceCents: row.initialBalanceCents,
        currentBalanceCents: row.currentBalanceCents,
        ownership: Ownership.values[row.ownership - 1],
        status: AccountStatus.values[row.status - 1],
        icon: row.icon,
        color: row.color,
        parentId: row.parentId ?? '',
        isSystem: row.isSystem,
        institution: row.institution,
        creditLimitCents: row.creditLimitCents ?? 0,
        cardNumberTail: row.cardNumberTail,
        notes: row.notes,
        openingDate: row.openingDate,
        interestRate: row.interestRate,
        creditBillingDay: row.creditBillingDay,
        creditRepaymentDay: row.creditRepaymentDay,
        creditAnnualFeeCents: row.creditAnnualFeeCents,
        investCostCents: row.investCostCents,
        investMarketValueCents: row.investMarketValueCents,
        investReturnYtd: row.investReturnYtd,
        fixedPrincipalCents: row.fixedPrincipalCents,
        fixedStartDate: row.fixedStartDate,
        fixedMaturityDate: row.fixedMaturityDate,
        fixedTermMonths: row.fixedTermMonths,
        goldProductType: row.goldProductType,
        goldQuantity: row.goldQuantity,
        goldBuyPriceCents: row.goldBuyPriceCents,
        goldCurrentPriceCents: row.goldCurrentPriceCents,
        estatePurchasePriceCents: row.estatePurchasePriceCents,
        estateCurrentValueCents: row.estateCurrentValueCents,
        estatePurchaseDate: row.estatePurchaseDate,
        estateDepreciationRate: row.estateDepreciationRate,
        loanOriginalCents: row.loanOriginalCents,
        loanRemainingCents: row.loanRemainingCents,
        loanMonthlyCents: row.loanMonthlyCents,
        loanNextPaymentDate: row.loanNextPaymentDate,
        version: row.version,
        createdAt: row.createdAt,
      );
}

/// F49 FR-5 [AccountCloser] port 实现(债删自动关户;guest 本地 drift 写)。
///
/// 三重门(任一不满足 = no-op):①isSystem=true(并入模式载体;独立账单
/// 真实账户 isSystem=false 天然挡);②currentBalanceCents==0;③名下无其他
/// debt_type=1 借入债。通过 → status=archived(存库 2,与既有「关闭账户」
/// 路径[UpdateAccountParams.status]同源)+ version 推进 + updatedAt,
/// 余额/分录零改动(永不删除账户)。
///
/// 事务:调用方(debt DS delete)在 `_database.transaction` 内调用 —— 本
/// 实现持有同一 AppDatabase 实例,一次性 select(禁 watch 流:事务占用的
/// 单连接上流式查询死锁)自然加入同事务,关户与债删同生共死;若未来改为
/// 独立连接的远端实现,须退化为事务后调用并容忍失败静默(由调用方钉死)。
@LazySingleton(as: AccountCloser)
class AccountCloserImpl implements AccountCloser {
  AccountCloserImpl(this._db);

  final db.AppDatabase _db;

  @override
  Future<void> closeIfEmptyCarrier(String accountId) async {
    final account = await _db.accountDao.getAccountById(accountId);
    if (account == null) return; // 账户不存在(已删/镜像清库)= no-op
    if (!account.isSystem) return;
    if (account.currentBalanceCents != 0) return;
    // 名下无其他 debt_type=1 借入债(一次性读;调用时被删债已出表)。
    final otherBorrowedIn = await (_db.select(_db.debts)
          ..where((d) => d.accountId.equals(accountId) & d.debtType.equals(1)))
        .get();
    if (otherBorrowedIn.isNotEmpty) return;
    await (_db.update(_db.accounts)..where((a) => a.id.equals(accountId)))
        .write(db.AccountsCompanion(
      status: Value(AccountStatus.archived.index + 1),
      version: Value(account.version + 1),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
  }
}
