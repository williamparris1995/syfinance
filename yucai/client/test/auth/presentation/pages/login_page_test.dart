// Task 12 — widget tests for the OIDC LoginPage.
//
// LoginPage renders a single hard-coded "使用 Google 登录" FilledButton.icon
// (lucide logIn). Tapping it must dispatch `OIDCLoginRequested('google')` on
// the AuthBloc. While AuthLoading, the button is disabled and shows a spinner
// (prevents double-tap racing a second dispatch). On AuthError a SnackBar
// surfaces the message.
//
// We mock AuthBloc (not its dependencies) — the widget only reads bloc state +
// dispatches events; the OIDC flow itself is covered by oidc_authenticator_test
// + auth_bloc_test. Pattern mirrors backup_page_test (Mock implements Bloc,
// stub state + stream, verify bloc.add).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/auth/presentation/pages/login_page.dart';

class _MockAuthBloc extends Mock implements AuthBloc {}

final _user = User(
  id: 'u1',
  tenantId: 't1',
  email: 'a@b.com',
  displayName: 'A',
  avatarUrl: '',
  createdAt: DateTime(2026),
);

/// The skip-login button navigates to /home (R6 FR-3), so the harness needs
/// a minimal GoRouter around the page; every other test only reads state.
GoRouter _testRouter(AuthBloc bloc) => GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => BlocProvider<AuthBloc>.value(
            value: bloc,
            child: const LoginPage(),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Center(child: Text('home'))),
        ),
      ],
    );

Widget _harness({required AuthState state, required AuthBloc bloc}) =>
    MaterialApp.router(routerConfig: _testRouter(bloc));

void main() {
  late _MockAuthBloc bloc;

  setUp(() {
    bloc = _MockAuthBloc();
    // Stub the two getters BlocBuilder/BlocListener read. State starts at
    // AuthInitial for the rendering + dispatch test; individual tests override.
    when(() => bloc.state).thenReturn(AuthInitial());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    // mocktail needs a fallback for the AuthEvent base class when verifying
    // any .add call generically; OIDCLoginRequested is a concrete subtype so
    // this isn't strictly required, but it's cheap insurance against the
    // "No fallback value for AuthEvent" trap if we ever broaden the verify.
    registerFallbackValue(const OIDCLoginRequested('google'));
    registerFallbackValue(SkipLoginRequested());
  });

  testWidgets('renders title + single Google login button', (t) async {
    await t.pumpWidget(_harness(state: AuthInitial(), bloc: bloc));
    await t.pump();

    // Branding.
    expect(find.text('御财'), findsOneWidget);
    expect(find.text('登录以继续'), findsOneWidget);
    // Single provider button — not driven by getOIDCConfig, hard-coded google.
    expect(find.text('使用 Google 登录'), findsOneWidget);
    // Offline-first skip entry (R6 FR-3).
    expect(find.text('先不登录，离线使用'), findsOneWidget);
    // Lucide logIn icon (per login_page source).
    expect(find.byIcon(LucideIcons.logIn), findsOneWidget);
  });

  testWidgets('skip-login dispatches SkipLoginRequested and lands on /home',
      (t) async {
    final router = _testRouter(bloc);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pump();

    await t.tap(find.text('先不登录，离线使用'));
    await t.pumpAndSettle();

    verify(() => bloc.add(SkipLoginRequested())).called(1);
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/home');
  });

  testWidgets('tap button dispatches OIDCLoginRequested(google)', (t) async {
    await t.pumpWidget(_harness(state: AuthInitial(), bloc: bloc));
    await t.pump();

    await t.tap(find.text('使用 Google 登录'));
    await t.pump();

    // Concrete event equality — verifies provider name propagated exactly.
    verify(() => bloc.add(const OIDCLoginRequested('google'))).called(1);
  });

  testWidgets('AuthLoading disables button + shows spinner (no double dispatch)',
      (t) async {
    when(() => bloc.state).thenReturn(AuthLoading());
    await t.pumpWidget(_harness(state: AuthLoading(), bloc: bloc));
    await t.pump();

    // FilledButton.icon onPressed null while loading → disabled.
    final button = t.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    // Inline spinner replaces the lucide icon while loading.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(LucideIcons.logIn), findsNothing);

    // Tapping the disabled button must not dispatch — verifies no double-tap
    // race (e.g. user impatient while browser opens).
    await t.tap(find.byType(FilledButton), warnIfMissed: false);
    await t.pump();
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('AuthError surfaces SnackBar with the message', (t) async {
    // BlocListener fires on state change; we emit AuthError via the stream.
    final controller = StreamController<AuthState>.broadcast();
    when(() => bloc.state).thenReturn(AuthInitial());
    when(() => bloc.stream).thenAnswer((_) => controller.stream);

    await t.pumpWidget(_harness(state: AuthInitial(), bloc: bloc));
    await t.pump();

    // Emit error after first frame so the listener sees the transition.
    controller.add(const AuthError('provider 暂不可用'));
    await t.pumpAndSettle();

    expect(find.text('provider 暂不可用'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);

    await controller.close();
  });

  testWidgets('Authenticated state: button still renders (router redirects)',
      (t) async {
    // LoginPage itself does not navigate on Authenticated — the router
    // redirect does (out of scope for this widget test). Here we only assert
    // the page doesn't crash on Authenticated and the button remains tappable
    // (so a user who somehow lands back on /login can retry).
    when(() => bloc.state).thenReturn(Authenticated(_user));
    await t.pumpWidget(_harness(state: Authenticated(_user), bloc: bloc));
    await t.pump();

    expect(find.text('使用 Google 登录'), findsOneWidget);
    final button = t.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });
}
