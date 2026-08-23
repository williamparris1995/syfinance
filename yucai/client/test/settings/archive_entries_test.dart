
// Feature J — settings archive entries existence (lightweight widget test).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';

import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/settings/presentation/settings_page.dart';

class _MockAuthRemote extends Mock implements AuthRemoteDataSource {}

class _StubCurrencyBloc extends Fake implements CurrencyBloc {
  @override
  CurrencyState get state => const CurrencyState();

  @override
  Stream<CurrencyState> get stream => const Stream.empty();
}
class _StubAuthBloc extends Fake implements AuthBloc {
  @override
  AuthState get state => Guest();

  @override
  Stream<AuthState> get stream => const Stream.empty();
}

void main() {
  testWidgets('settings shows archive export/import entries', (t) async {
    final authRemote = _MockAuthRemote();
    final settings = _FakeCurrencySettings();
    final gi = GetIt.instance;
    if (!gi.isRegistered<CurrencySettings>()) {
      gi.registerSingleton<CurrencySettings>(settings);
    }
    if (!gi.isRegistered<AuthRemoteDataSource>()) {
      gi.registerSingleton<AuthRemoteDataSource>(authRemote);
    }
    addTearDown(gi.reset);

    await t.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _StubAuthBloc()),
          BlocProvider<CurrencyBloc>.value(value: _StubCurrencyBloc()),
        ],
        child: SettingsPage(authRemote: authRemote),
      ),
    ));
    await t.pump();

    expect(find.text('导出存档'), findsOneWidget);
    expect(find.text('导入存档'), findsOneWidget);
  });
}

class _FakeCurrencySettings extends Fake implements CurrencySettings {
  final ValueNotifier<String> _notifier = ValueNotifier<String>('CNY');
  @override
  ValueListenable<String> get listenable => _notifier;
  @override
  String get value => 'CNY';
}
