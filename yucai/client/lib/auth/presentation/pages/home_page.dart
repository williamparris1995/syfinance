import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _content() => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 64),
              SizedBox(height: 16),
              Text('功能开发中', style: TextStyle(fontSize: 20)),
              SizedBox(height: 8),
              Text('已登录 — 后续功能模块将在此展示', textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    final userName = state is Authenticated ? state.user.displayName : '';

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Scaffold(
            body: Row(
              children: [
                Container(
                  width: 240,
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Text('御财', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 24),
                      Text(userName, style: Theme.of(context).textTheme.bodyMedium),
                      const Spacer(),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('退出登录'),
                        onTap: () => context.read<AuthBloc>().add(LogoutRequested()),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Expanded(child: _content()),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('御财')),
          body: _content(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: '首页'),
              NavigationDestination(icon: Icon(Icons.account_circle), label: '我的'),
            ],
            onDestinationSelected: (i) {
              if (i == 1) context.read<AuthBloc>().add(LogoutRequested());
            },
          ),
        );
      },
    );
  }
}
