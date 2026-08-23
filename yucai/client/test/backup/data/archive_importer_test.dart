// ArchiveImporter tests — full-replace semantics from a G-exporter envelope
// (round-trip: export local → import into fresh store → facets equal) and
// rollback on bad payloads.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/backup/data/archive_importer.dart';
import 'package:yucai_client/backup/data/local_snapshot_exporter.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db
    hide Holding, Transaction, TransactionEntry;

void main() {
  late db.AppDatabase source;
  late db.AppDatabase target;
  late ArchiveImporter importer;

  setUp(() {
    source = db.AppDatabase(NativeDatabase.memory());
    target = db.AppDatabase(NativeDatabase.memory());
    importer = ArchiveImporter(target);
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<void> seed(String id) => source.accountDao.insertAccount(
        db.AccountsCompanion.insert(
          id: id,
          name: 'n-$id',
          accountType: 1,
          category: 2,
          currencyCode: 'CNY',
          initialBalanceCents: 100,
          currentBalanceCents: 50,
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
          createdAt: DateTime.utc(2026, 8, 23),
          updatedAt: DateTime.utc(2026, 8, 23),
        ),
      );

  test('export → import round-trip replaces the target store', () async {
    await seed('a1');
    await seed('a2');
    final envelope = await LocalSnapshotExporter(source).exportAll();

    await importer.importAll(envelope);

    final rows = await target.accountDao.getAllAccounts();
    expect(rows.map((a) => a.id).toSet(), {'a1', 'a2'});
    expect(rows.first.currentBalanceCents, 50);
    expect(rows.first.name, contains('a'));
  });

  test('import over an existing store replaces (not merges)', () async {
    await seed('old');
    await target.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: 'stale',
      name: 'stale',
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
    final envelope = await LocalSnapshotExporter(source).exportAll();
    await importer.importAll(envelope);
    final rows = await target.accountDao.getAllAccounts();
    expect(rows.map((a) => a.id), isNot(contains('stale')));
    expect(rows, hasLength(1)); // source held only 'old'
  });

  test('bad payload rolls back (target untouched)', () async {
    await target.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: 'keep',
      name: 'keep',
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
    // Envelope with a broken account row (missing required name → drift
    // constraint failure inside the tx).
    // Our importer defaults missing fields — the rollback proof uses a
    // duplicate PK instead.
    final dup = jsonEncode({
      'version': 1,
      'modules': {
        'account': [
          {'ID': 'x1'},
          {'ID': 'x1'},
        ]
      }
    });
    final unsupported = jsonEncode({'version': 2, 'modules': {}});
    expect(() => importer.importAll(utf8.encode(unsupported)),
        throwsA(anything)); // unsupported version
    expect(() => importer.importAll(utf8.encode(dup)), throwsA(anything));
    expect(await target.accountDao.getAllAccounts(),
        hasLength(1)); // 'keep' survived both attempts
  });
}
