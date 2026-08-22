// CurrencyLocalDataSource + guest-branch tests: static seed on first read,
// idempotent re-seed, and the CurrencyBloc guest path (no preference RPCs).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/currency/data/currency_repository_impl.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/currency/domain/repositories/currency_repository.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_event.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';

class _MockRepo extends Mock implements CurrencyRepository {}

class _MockAuthRemote extends Mock implements AuthRemoteDataSource {}

class _StubSettings extends Fake implements CurrencySettings {
  @override
  String get value => 'CNY';
}

void main() {
  late db.AppDatabase database;

  setUp(() => database = db.AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('seeds the static ISO subset on first (empty) read, idempotent',
      () async {
    final ds = CurrencyLocalDataSource(database);
    final first = await ds.list();
    expect(first.map((c) => c.code), containsAll(['CNY', 'USD', 'EUR']));
    expect(first.firstWhere((c) => c.code == 'CNY').name, '人民币');
    final second = await ds.list();
    expect(second, hasLength(first.length)); // no duplicate seeding
  });

  test('guest branch: preferences come from local settings, no RPCs',
      () async {
    final repo = _MockRepo();
    final authRemote = _MockAuthRemote();
    final tracker = SessionModeTracker()..isGuest = true;
    final bloc = CurrencyBloc(repo, authRemote, tracker, _StubSettings());

    final states = <CurrencyState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(const LoadPreferencesRequested());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();

    expect(states.last.status, CurrencyStatus.loaded);
    expect(states.last.preferred, 'CNY');
    expect(states.last.intervalHours, 24);
    verifyNever(() => authRemote.getPreferredCurrency());
    verifyNever(() => authRemote.getRateSyncIntervalHours());
  });
}
