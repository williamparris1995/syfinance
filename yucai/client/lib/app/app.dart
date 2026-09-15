import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yucai_client/app/router.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/core/theme/theme_settings.dart';
import 'package:yucai_client/core/widgets/app_title_bar.dart';

class YuCaiApp extends StatelessWidget {
  const YuCaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authBloc = getIt<AuthBloc>()..add(AppStarted());
    final router = buildRouter(authBloc);
    // 主题模式(R8 F1):ThemeSettings.listenable 驱动 light/dark 实时切换;
    // 持久化值已在 bootstrap(injection.dart load)同步。
    final themeSettings = getIt<ThemeSettings>();
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
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeSettings.listenable,
        builder: (context, mode, _) => MaterialApp.router(
          title: '御财 YuCai',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          routerConfig: router,
          // F29 自定义标题栏(ADR-2 取舍:builder 层统一挂,而非 app_shell):
          // 登录前(guest)无 shell 的窗口同样要有标题栏,shell 层挂会漏登录页;
          // builder 包住整个 Navigator,所有路由(含窄屏底导形态)顶部一致,
          // chrome 全断点不缺席(FR-5),亦不与 app_shell 布局叠加(无双标题栏)。
          // 仅 Windows 桌面非 web(移动/web 无原生窗口概念,系统标题栏保留)。
          builder: (context, child) {
            if (kIsWeb || !Platform.isWindows) {
              return child ?? const SizedBox.shrink();
            }
            return Column(
              children: [
                const AppTitleBar(),
                Expanded(child: child ?? const SizedBox.shrink()),
              ],
            );
          },
        ),
      ),
    );
  }
}
