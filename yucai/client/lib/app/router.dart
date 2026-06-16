import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/pages/account_detail_page.dart';
import 'package:yucai_client/account/presentation/pages/accounts_page.dart';
import 'package:yucai_client/app/widgets/app_shell.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/auth/presentation/pages/home_page.dart';
import 'package:yucai_client/auth/presentation/pages/login_page.dart';
import 'package:yucai_client/auth/presentation/pages/register_page.dart';
import 'package:yucai_client/core/di/injection.dart';

/// Builds the app router. Reads auth state to guard routes.
///
/// 受保护区域用 [StatefulShellRoute.indexedStack] 承载，侧边栏/顶栏
/// ([AppShell]) 在整个会话期间保持挂载，分支切换不重建外壳。
GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    refreshListenable: _AuthBlocListenable(authBloc),
    redirect: (context, state) {
      final auth = authBloc.state;
      final isLoggedIn = auth is Authenticated;
      final isLoading = auth is AuthInitial || auth is AuthLoading;
      final goingToAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final goingProtected = state.matchedLocation == '/home' ||
          state.matchedLocation.startsWith('/accounts');

      if (isLoading) return null;

      if (!isLoggedIn && goingProtected) return '/login';
      if (isLoggedIn && goingToAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => BlocProvider<AccountBloc>(
                  // 仪表盘需要账户聚合（净资产 / 资产分解），独立 bloc 实例。
                  create: (_) => getIt<AccountBloc>(),
                  child: const HomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/accounts',
                builder: (_, __) => BlocProvider<AccountBloc>(
                  // Factory 注册 → 每次进入分支都是全新 bloc；离开分支时释放。
                  create: (_) => getIt<AccountBloc>(),
                  child: const AccountsPage(),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => BlocProvider<AccountBloc>(
                      // 详情页用独立 bloc 实例：列表页 bloc 在跳转时被释放，
                      // 详情页需要自己的实例来发起 GetAccountRequested。
                      create: (_) => getIt<AccountBloc>(),
                      child: AccountDetailPage(
                          id: state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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
