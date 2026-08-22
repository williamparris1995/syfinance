import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yucai_client/app/router.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/theme/app_theme.dart';

class YuCaiApp extends StatelessWidget {
  const YuCaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authBloc = getIt<AuthBloc>()..add(AppStarted());
    final router = buildRouter(authBloc);
    // Startup self-check (R6 F): async, non-blocking, banner-only on issues.
    () async {
      try {
        final (ok, detail) = await getIt<AppDatabase>().integrityCheck();
        if (!ok) getIt<ValueNotifier<String?>>().value = detail;
      } catch (_) {
        // Self-check must never block startup.
      }
    }();

    return BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: MaterialApp.router(
        title: '御财 YuCai',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
  }
}
