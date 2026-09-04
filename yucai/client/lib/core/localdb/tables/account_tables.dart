import 'package:drift/drift.dart';

import '../sync_state.dart' show SyncState;

/// Contract table for the account module: columns mirror the server backup
/// payload (domain struct fields, snake_cased). Money is int64 cents, enums
/// keep their backup-JSON int form, IDs are client-generated UUID strings
/// (design ADR-1/ADR-3).
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get accountType => integer()();
  IntColumn get category => integer()();
  TextColumn get currencyCode => text()();
  IntColumn get initialBalanceCents => integer()();
  IntColumn get currentBalanceCents => integer()();
  IntColumn get ownership => integer()();
  TextColumn get icon => text()();
  TextColumn get color => text()();
  TextColumn get chartCode => text()();
  TextColumn get parentId => text().nullable()();
  BoolColumn get isSystem => boolean()();
  IntColumn get sortOrder => integer()();
  TextColumn get institution => text()();
  IntColumn get creditLimitCents => integer().nullable()();
  TextColumn get cardNumberTail => text()();
  TextColumn get notes => text()();
  DateTimeColumn get openingDate => dateTime().nullable()();
  RealColumn get interestRate => real().nullable()();
  IntColumn get creditBillingDay => integer().nullable()();
  IntColumn get creditRepaymentDay => integer().nullable()();
  IntColumn get creditAnnualFeeCents => integer().nullable()();
  IntColumn get investCostCents => integer().nullable()();
  IntColumn get investMarketValueCents => integer().nullable()();
  RealColumn get investReturnYtd => real().nullable()();
  IntColumn get fixedPrincipalCents => integer().nullable()();
  DateTimeColumn get fixedStartDate => dateTime().nullable()();
  DateTimeColumn get fixedMaturityDate => dateTime().nullable()();
  IntColumn get fixedTermMonths => integer().nullable()();
  TextColumn get goldProductType => text()();
  RealColumn get goldQuantity => real().nullable()();
  IntColumn get goldBuyPriceCents => integer().nullable()();
  IntColumn get goldCurrentPriceCents => integer().nullable()();
  IntColumn get estatePurchasePriceCents => integer().nullable()();
  IntColumn get estateCurrentValueCents => integer().nullable()();
  DateTimeColumn get estatePurchaseDate => dateTime().nullable()();
  RealColumn get estateDepreciationRate => real().nullable()();
  IntColumn get loanOriginalCents => integer().nullable()();
  IntColumn get loanRemainingCents => integer().nullable()();
  IntColumn get loanMonthlyCents => integer().nullable()();
  DateTimeColumn get loanNextPaymentDate => dateTime().nullable()();
  IntColumn get status => integer()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// F10 FR-3/ADR-2:同步状态(synced=镜像行/guest 行;pending=离线或降级
  /// 写待上行)。旧库迁移加列时以默认回填 synced。
  TextColumn get syncState =>
      text().withDefault(const Constant(SyncState.synced))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local-owned reference table (NOT in the backup contract): system chart of
/// accounts seeded per install; Accounts.chartCode references code (design
/// ADR-3, own-table class).
class ChartOfAccounts extends Table {
  TextColumn get code => text()();
  TextColumn get name => text()();
  IntColumn get level => integer()();
  IntColumn get accountType => integer()();
  TextColumn get parentCode => text()();
  IntColumn get balanceDirection => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {code};
}
