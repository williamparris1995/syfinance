// F39 guest local snapshot loop — service contract tests (temp-dir style,
// same shape as template_local_ds_test's in-memory database harness).
//
// Covered oracles:
// 1. runNow writes exactly one parseable envelope snapshot file (non-empty,
//    first byte `{`); runDailyIfDue is gated to once per UTC day via the
//    `local_snapshot_last_date` app_meta marker.
// 2. Retention: after a runDue with 9 older snapshots present, only the 7
//    newest (by descending file name = chronological) survive.
// 3. restoreFrom rolls the store back to the snapshot state (ArchiveImporter
//    semantics). Path traversal / non-snapshot names are rejected.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/backup/data/archive_importer.dart';
import 'package:yucai_client/backup/data/local_snapshot_exporter.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/settings/data/local_snapshot_service.dart';

void main() {
  late db.AppDatabase database;
  late LocalSnapshotService service;
  late Directory tempRoot;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    tempRoot = await Directory.systemTemp.createTemp('yucai_snap_test');
    service = LocalSnapshotService(
      database: database,
      exporter: LocalSnapshotExporter(database),
      importer: ArchiveImporter(database),
      supportDirFn: () async => tempRoot,
    );
  });

  tearDown(() async {
    await database.close();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  db.AccountsCompanion accountRow(String id, {int balance = 1000000}) =>
      db.AccountsCompanion.insert(
        id: id,
        name: 'Cash',
        accountType: 1,
        category: 2,
        currencyCode: 'CNY',
        initialBalanceCents: balance,
        currentBalanceCents: balance,
        ownership: 1,
        icon: '',
        color: '',
        chartCode: '1001',
        isSystem: false,
        sortOrder: 0,
        institution: '',
        cardNumberTail: '',
        notes: '',
        goldProductType: '',
        status: 1,
        version: 3,
        createdAt: DateTime.utc(2026, 8, 23),
        updatedAt: DateTime.utc(2026, 8, 23),
      );

  Directory backupDir() => Directory('${tempRoot.path}/local_backups');

  String utcToday() {
    final n = DateTime.now().toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}';
  }

  test('runNow writes one parseable snapshot file (non-empty, JSON object)',
      () async {
    final file = await service.runNow();

    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));
    final bytes = file.readAsBytesSync();
    expect(utf8.decode(bytes).startsWith('{'), isTrue);
    // Content must be a full BackupEnvelope (ArchiveImporter-parsable shape).
    final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(envelope['version'], 1);
    expect(envelope['modules'], isA<Map>());
    expect(file.uri.pathSegments.last,
        matches(RegExp(r'^snapshot-\d{8}-\d{6}\.json$')));

    final list = await service.listSnapshots();
    expect(list, hasLength(1));
    expect(list.single.sizeBytes, bytes.length);
    expect(list.single.fileName, file.uri.pathSegments.last);
  });

  test('runDailyIfDue runs once per UTC day (marker-gated)', () async {
    await service.runDailyIfDue();
    await service.runDailyIfDue(); // same day → no second snapshot

    final list = await service.listSnapshots();
    expect(list, hasLength(1));

    final marker = await (database.select(database.appMeta)
          ..where((t) => t.key.equals(LocalSnapshotService.markerKey)))
        .getSingleOrNull();
    expect(marker, isNotNull);
    expect(marker!.value, utcToday());
  });

  test('retention: only the 7 newest snapshots survive a daily run', () async {
    // Nine pre-existing snapshots with lexicographically (and thus
    // chronologically) older names; timestamps backdated as well.
    for (var d = 1; d <= 9; d++) {
      final f = File(
          '${backupDir().path}/snapshot-2026090$d-120000.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      final old = DateTime.utc(2026, 9, d, 12);
      f.setLastModifiedSync(old);
    }

    await service.runDailyIfDue();

    final list = await service.listSnapshots(); // descending order
    expect(list, hasLength(7));
    // Newest kept first: the snapshot created by this daily run (today).
    expect(list.first.fileName,
        matches(RegExp(r'^snapshot-\d{8}-\d{6}\.json$')));
    expect(list.first.fileName,
        isNot(startsWith('snapshot-2026090'))); // not a fake
    // The three oldest fakes were pruned; the six newest fakes remain.
    expect(list.any((s) => s.fileName == 'snapshot-20260903-120000.json'),
        isFalse);
    expect(list.any((s) => s.fileName == 'snapshot-20260904-120000.json'),
        isTrue);
    expect(list.last.fileName, 'snapshot-20260904-120000.json');
  });

  test('restoreFrom rolls the store back to the snapshot state', () async {
    await database.accountDao.insertAccount(accountRow('a1', balance: 111));
    final snap = await service.runNow();
    final snapName = snap.uri.pathSegments.last;

    // Diverge after the snapshot: one extra marker account.
    await database.accountDao.insertAccount(accountRow('a2', balance: 222));
    expect(await database.accountDao.getAllAccounts(), hasLength(2));

    await service.restoreFrom(snapName);

    final accounts = await database.accountDao.getAllAccounts();
    expect(accounts, hasLength(1));
    expect(accounts.single.id, 'a1');
    expect(accounts.single.currentBalanceCents, 111);
  });

  test('path traversal and non-snapshot names are rejected', () async {
    await expectLater(
        service.deleteSnapshot('../evil.json'), throwsA(isA<ValidationFailure>()));
    await expectLater(service.deleteSnapshot(r'..\..\secret.json'),
        throwsA(isA<ValidationFailure>()));
    await expectLater(
        service.deleteSnapshot('other-20260919-120000.json'),
        throwsA(isA<ValidationFailure>()));
    await expectLater(
        service.restoreFrom('../evil.json'), throwsA(isA<ValidationFailure>()));

    // A well-formed name is accepted and actually deletes the file.
    final f = File('${backupDir().path}/snapshot-20260901-010101.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{}');
    await service.deleteSnapshot('snapshot-20260901-010101.json');
    expect(f.existsSync(), isFalse);
  });
}
