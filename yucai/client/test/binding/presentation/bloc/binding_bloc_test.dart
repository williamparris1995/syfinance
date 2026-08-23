// BindingBloc state machine tests — guard (3 facets) and upload flow with
// mocked repos/ds riding the dual-source seam.
import 'package:dartz/dartz.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/backup/data/backup_remote_ds.dart';
import 'package:yucai_client/backup/data/local_snapshot_exporter.dart';
import 'package:yucai_client/binding/presentation/bloc/binding_bloc.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db hide Holding;
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

class _MockAccounts extends Mock implements AccountRepository {}
class _MockTxns extends Mock implements TransactionRepository {}
class _MockHoldings extends Mock implements HoldingRepository {}
class _MockBackupRemote extends Mock implements BackupRemoteDataSource {}

final _account = Account(
  id: 'a1',
  name: 'x',
  accountType: AccountType.asset,
  category: AccountCategory.savings,
  currencyCode: 'CNY',
  initialBalanceCents: 0,
  currentBalanceCents: 0,
  ownership: Ownership.personal,
  status: AccountStatus.active,
);

void main() {
  late _MockAccounts accounts;
  late _MockTxns txns;
  late _MockHoldings holdings;
  late _MockBackupRemote backupRemote;
  late db.AppDatabase database;
  late BindingBloc bloc;

  setUp(() {
    accounts = _MockAccounts();
    txns = _MockTxns();
    holdings = _MockHoldings();
    backupRemote = _MockBackupRemote();
    database = db.AppDatabase(NativeDatabase.memory());
    bloc = BindingBloc(accounts, txns, holdings,
        LocalSnapshotExporter(database), backupRemote, database);
    registerFallbackValue(ListTransactionsParams());
  });

  tearDown(() => database.close());

  test('empty remote account → readyToUpload', () async {
    when(() => accounts.list()).thenAnswer((_) async => Right([]));
    when(() => txns.list(any())).thenAnswer((_) async =>
        const Right(ListTransactionsResult(transactions: [], totalCount: 0)));
    when(() => holdings.listHoldings(accountId: any(named: 'accountId')))
        .thenAnswer((_) async => Right(<Holding>[]));

    bloc.add(BindingStarted());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(bloc.state.status, BindingStatus.readyToUpload);
  });

  test('non-empty remote account → blocked (M3 guard)', () async {
    when(() => accounts.list()).thenAnswer((_) async => Right([_account]));
    when(() => txns.list(any())).thenAnswer((_) async =>
        const Right(ListTransactionsResult(transactions: [], totalCount: 0)));
    when(() => holdings.listHoldings(accountId: any(named: 'accountId')))
        .thenAnswer((_) async => Right(<Holding>[]));

    bloc.add(BindingStarted());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(bloc.state.status, BindingStatus.blocked);
    expect(bloc.state.blockedReason, contains('已有服务端数据'));
    verifyNever(() => backupRemote.uploadBackup(any()));
  });

  test('upload success → success with verification counts', () async {
    await database.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: 'a1',
      name: 'x',
      accountType: 1,
      category: 2,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: 1,
      icon: '',
      color: '',
      chartCode: '',
      isSystem: false,
      sortOrder: 0,
      institution: '',
      cardNumberTail: '',
      notes: '',
      goldProductType: '',
      status: 1,
      version: 1,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ));
    when(() => backupRemote.uploadBackup(any())).thenAnswer((_) async {});
    when(() => accounts.list()).thenAnswer((_) async => Right([_account]));

    bloc.add(BindingUploadConfirmed());
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(bloc.state.status, BindingStatus.success);
    expect(bloc.state.uploadedEntities, 1);
    expect(bloc.state.verifiedRemoteCount, 1);
    verify(() => backupRemote.uploadBackup(any())).called(1);
  });

  test('upload failure → failed (retryable, local intact)', () async {
    when(() => backupRemote.uploadBackup(any()))
        .thenThrow(Exception('network down'));
    when(() => accounts.list()).thenAnswer((_) async => Right([]));

    bloc.add(BindingUploadConfirmed());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(bloc.state.status, BindingStatus.failed);
    expect(bloc.state.failureMessage, contains('network down'));
    expect((await database.accountDao.getAllAccounts()), isEmpty);
  });
}
