import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/auth/presentation/pages/home_page.dart';
import 'package:yucai_client/auth/presentation/pages/login_page.dart';
import 'package:yucai_client/auth/presentation/pages/register_page.dart';

/// Builds the app router. Reads auth state to guard routes.
GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    refreshListenable: _AuthBlocListenable(authBloc),
    redirect: (context, state) {
      final auth = authBloc.state;
      final isLoggedIn = auth is Authenticated;
      final isLoading = auth is AuthInitial || auth is AuthLoading;
      final goingToAuth =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final goingHome = state.matchedLocation == '/home';

      if (isLoading) return null;

      if (!isLoggedIn && goingHome) return '/login';
      if (isLoggedIn && goingToAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/home', builder: (_, __) => const HomePage()),
    ],
    initialLocation: '/home',
  );
}

/// Bridges Bloc stream → ChangeNotifier so GoRouter re-evaluates redirect on auth changes.
class _AuthBlocListenable extends ChangeNotifier {
  _AuthBlocListenable(AuthBloc bloc) {
    _sub = bloc.stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
