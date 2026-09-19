import 'dart:io';

import 'package:drift/drift.dart' show InsertMode;
import 'package:path_provider/path_provider.dart';

import 'package:yucai_client/backup/data/archive_importer.dart';
import 'package:yucai_client/backup/data/local_snapshot_exporter.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart';

/// Guest local snapshot loop (F39): automatic daily + manual snapshots of the
/// local drift store into `<appSupport>/local_backups/snapshot-*.json`, with
/// one-click restore.
///
/// Reuse-first: the heavy lifting rides on the existing backup primitives —
/// [LocalSnapshotExporter.exportAll] produces the envelope bytes (same chain
/// as archive export / F21 pre-reset backup) and [ArchiveImporter.importAll]
/// replaces the whole local store inside a single drift transaction (same
/// chain as archive import; the settings page bumps DataRefreshNotifier after
/// a successful restore, mirroring the import-archive hotfix flow).
///
/// File home: `lib/settings/data/` next to DataResetController — both are
/// settings-surface orchestrators over the backup primitives (the primitives
/// themselves stay codec-pure in `backup/data/`). DI: manual registration in
/// injection.dart per the 1h/F21 precedent (no build_runner regen).
class LocalSnapshotService {
  LocalSnapshotService({
    required AppDatabase database,
    required LocalSnapshotExporter exporter,
    required ArchiveImporter importer,
    Future<Directory> Function()? supportDirFn,
  })  : _database = database, // ignore: prefer_initializing_formals
        _exporter = exporter, // ignore: prefer_initializing_formals
        _importer = importer, // ignore: prefer_initializing_formals
        _supportDir = supportDirFn ?? getApplicationSupportDirectory;

  /// app_meta key gating the daily run (repairs.dart marker pattern): value
  /// = the UTC date (`yyyy-MM-dd`) of the last automatic snapshot.
  static const markerKey = 'local_snapshot_last_date';

  /// Retention window: keep the newest 7 snapshots, delete older ones.
  static const keepCount = 7;

  /// Whitelist for restore/delete. Only `snapshot-YYYYMMDD-HHMMSS.json`
  /// inside the backups dir is ever addressable — the pattern admits no path
  /// separators, so traversal (`../`, `\..\`) cannot escape the directory.
  static final RegExp _safeName = RegExp(r'^snapshot-\d{8}-\d{6}\.json$');

  /// Windows/POSIX separator set for basename extraction.
  static final RegExp _separators = RegExp(r'[/\\]');

  final AppDatabase _database;
  final LocalSnapshotExporter _exporter;
  final ArchiveImporter _importer;
  final Future<Directory> Function() _supportDir;

  /// Once-per-day automatic snapshot (startup hook, fire-and-forget): if the
  /// marker already holds today's UTC date, this is a no-op; otherwise run a
  /// snapshot and stamp the marker. Silent-failure per the repairs convention
  /// — a failed snapshot must never block app startup; the next launch
  /// retries (marker only written after runNow succeeds).
  Future<void> runDailyIfDue() async {
    try {
      final now = DateTime.now().toUtc();
      final today =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final done = await (_database.select(_database.appMeta)
            ..where((t) => t.key.equals(markerKey)))
          .getSingleOrNull();
      if (done?.value == today) return;
      await runNow();
      await _database.into(_database.appMeta).insert(
            AppMetaCompanion.insert(key: markerKey, value: today),
            mode: InsertMode.insertOrReplace,
          );
    } catch (_) {
      // Intentionally swallowed (repairs convention): startup must not break.
    }
  }

  /// Snapshot right now: export → write file → prune to [keepCount] newest.
  /// Returns the written file so callers can surface success/failure.
  Future<File> runNow() async {
    final bytes = await _exporter.exportAll();
    final dir = await _snapshotDir();
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final file = File(
        '${dir.path}${Platform.pathSeparator}snapshot-$stamp.json');
    await file.writeAsBytes(bytes, flush: true);
    await _prune(dir);
    return file;
  }

  /// All snapshots, newest first (file names embed timestamps, so descending
  /// name order is chronological order).
  Future<List<({String fileName, int sizeBytes, DateTime modified})>>
      listSnapshots() async {
    final dir = await _snapshotDir();
    final out = <({String fileName, int sizeBytes, DateTime modified})>[];
    for (final file in await _snapshotFiles(dir)) {
      final stat = await file.stat();
      out.add((
        fileName: _baseName(file.path),
        sizeBytes: stat.size,
        modified: stat.modified,
      ));
    }
    return out;
  }

  /// Restore the whole local store from a snapshot. Confirmation lives in
  /// the UI layer (overwrite warning); here it is a straight importAll —
  /// purge + full re-insert inside one drift transaction.
  Future<void> restoreFrom(String fileName) async {
    final file = await _resolve(fileName);
    await _importer.importAll(await file.readAsBytes());
  }

  /// Delete one snapshot file. Security: [fileName] must match [_safeName]
  /// (no separators → no traversal out of the backups dir).
  Future<void> deleteSnapshot(String fileName) async {
    final file = await _resolve(fileName);
    if (await file.exists()) await file.delete();
  }

  // ---- internals ----

  Future<Directory> _snapshotDir() async {
    final support = await _supportDir();
    final dir = Directory(
        '${support.path}${Platform.pathSeparator}local_backups');
    await dir.create(recursive: true);
    return dir;
  }

  /// Snapshot files in the dir, newest (lexicographically largest name) first.
  Future<List<File>> _snapshotFiles(Directory dir) async {
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && _safeName.hasMatch(_baseName(entity.path))) {
        files.add(entity);
      }
    }
    files.sort((a, b) => _baseName(b.path).compareTo(_baseName(a.path)));
    return files;
  }

  /// Retention: after a new snapshot, keep only the [keepCount] newest.
  Future<void> _prune(Directory dir) async {
    for (final file in (await _snapshotFiles(dir)).skip(keepCount)) {
      try {
        await file.delete();
      } catch (_) {
        // A stale extra file must not fail the snapshot itself.
      }
    }
  }

  /// Whitelist gate shared by restore/delete: reject anything that is not a
  /// plain `snapshot-*.json` name (path traversal, foreign names), then join
  /// onto the managed dir. Pattern guarantees no separators, so the join is
  /// traversal-safe.
  Future<File> _resolve(String fileName) async {
    if (!_safeName.hasMatch(fileName)) {
      throw const ValidationFailure('快照文件名不合法');
    }
    final dir = await _snapshotDir();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  static String _baseName(String path) =>
      path.split(_separators).last;
}
