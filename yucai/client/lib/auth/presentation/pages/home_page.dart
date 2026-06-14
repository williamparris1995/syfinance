import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_event.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _content(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 64),
              const SizedBox(height: 16),
              Text('欢迎回来', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push('/accounts'),
                icon: const Icon(Icons.list_alt),
                label: const Text('管理账户'),
              ),
            ],
          ),
        ),
      );

  Widget _navItem(IconData icon, String label, VoidCallback onTap) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: onTap,
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
                      const SizedBox(height: 24),
                      _navItem(Icons.account_balance_wallet, '账户', () => context.push('/accounts')),
                      const Spacer(),
                      _navItem(Icons.logout, '退出登录',
                          () => context.read<AuthBloc>().add(LogoutRequested())),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Expanded(child: _content(context)),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('御财')),
          body: _content(context),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: '首页'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: '账户'),
              NavigationDestination(icon: Icon(Icons.logout), label: '退出'),
            ],
            onDestinationSelected: (i) {
              if (i == 1) context.push('/accounts');
              if (i == 2) context.read<AuthBloc>().add(LogoutRequested());
            },
          ),
        );
      },
    );
  }
}
