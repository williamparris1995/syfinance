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

  Future<Account> create(CreateAccountParams p) async {
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
      isSystem: false,
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
    ));
    return (await _requireById(id))!;
  }

  Future<Account> getById(String id) async =>
      (await _requireById(id)) ?? (throw const ServerFailure(_notFound));

  Future<Account> update(UpdateAccountParams p) async {
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
      openingDate: orAbsent(p.openingDate),
      interestRate: orAbsent(p.interestRate),
      creditBillingDay: orAbsent(p.creditBillingDay),
      creditRepaymentDay: orAbsent(p.creditRepaymentDay),
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
      version: Value(row.version + 1),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
    return (await _requireById(p.id))!;
  }

  Future<void> delete(String id) async {
    final row = await _requireById(id);
    if (row == null) throw const ServerFailure(_notFound);
    // Same guard and wording as the remote non-zero-balance rule — guest
    // habits must match bound habits (ADR-4).
    if (row.currentBalanceCents != 0) {
      throw const ServerFailure('账户余额非零，无法删除，请先清空余额或转账后再试');
    }
    await _dao.deleteAccountById(id);
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
