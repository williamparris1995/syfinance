// Repo-level guest routing for the four feature-D modules — mirrors the
// account routing group (feature C): guest → local (zero remote calls),
// session → remote.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db
    hide Transaction, TransactionEntry, Tag, TransactionTemplate;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/currency/data/currency_remote_ds.dart';
import 'package:yucai_client/currency/data/currency_repository_impl.dart';
import 'package:yucai_client/tag/data/tag_repository_impl.dart';
import 'package:yucai_client/tag/data/tag_remote_ds.dart';
import 'package:yucai_client/template/data/template_local_ds.dart';
import 'package:yucai_client/template/data/template_remote_ds.dart';
import 'package:yucai_client/template/data/template_repository_impl.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/data/transaction_remote_ds.dart';
import 'package:yucai_client/transaction/data/transaction_repository_impl.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

class _MockTagRemote extends Mock implements TagRemoteDataSource {}
class _MockTemplateRemote extends Mock implements TemplateRemoteDataSource {}
class _MockTxnRemote extends Mock implements TransactionRemoteDataSource {}
class _MockCurrencyRemote extends Mock implements CurrencyRemoteDataSource {}

void main() {
  late db.AppDatabase database;
  late SessionModeTracker tracker;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    tracker = SessionModeTracker()..isGuest = true;
    registerFallbackValue(const ListTransactionsParams());
  });

  tearDown(() => database.close());

  test('tag: guest create stays local, remote untouched', () async {
    final remote = _MockTagRemote();
    final repo = TagRepositoryImpl(remote, TagLocalDataSource(database), tracker);
    final result = await repo.create(name: 'x', color: '#000000');
    expect(result.isRight(), isTrue);
    verifyNever(() => remote.create(name: any(named: 'name'), color: any(named: 'color')));
  });

  test('template: guest create stays local', () async {
    final remote = _MockTemplateRemote();
    final repo = TemplateRepositoryImpl(
        remote, TemplateLocalDataSource(database, TransactionLocalDataSource(database)), tracker);
    final result = await repo.create(
      name: 'rent',
      amountCents: 100,
      direction: TemplateDirection.expense,
      cycle: TemplateCycle.monthly,
      sourceAccountId: 'a',
      category: 'c',
    );
    expect(result.isRight(), isTrue);
    verifyNever(() => remote.create(
        name: any(named: 'name'),
        description: any(named: 'description'),
        amountCents: any(named: 'amountCents')));
  });

  test('transaction: guest list reads local, session flips to remote',
      () async {
    final remote = _MockTxnRemote();
    final repo = TransactionRepositoryImpl(
        remote, TransactionLocalDataSource(database), tracker);
    final local = await repo.list(const ListTransactionsParams());
    expect(local.fold((_) => null, (r) => r)!.transactions, isEmpty);
    verifyNever(() => remote.list(any()));

    tracker.isGuest = false;
    when(() => remote.list(any()))
        .thenAnswer((_) async => const ListTransactionsResult(transactions: []));
    final remoteResult = await repo.list(const ListTransactionsParams());
    expect(remoteResult.isRight(), isTrue);
    verify(() => remote.list(any())).called(1);
  });

  test('currency: guest list seeds locally, remote untouched', () async {
    final remote = _MockCurrencyRemote();
    final repo = CurrencyRepositoryImpl(
        remote, CurrencyLocalDataSource(database), tracker);
    final result = await repo.list();
    expect(result.isRight(), isTrue);
    result.fold((_) => fail('expected Right'), (list) {
      expect(list.map((c) => c.code), contains('CNY'));
    });
    verifyNever(() => remote.list());
  });
}
