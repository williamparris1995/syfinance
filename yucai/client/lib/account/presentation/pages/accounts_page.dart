import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/bloc/account_state.dart';
import 'package:yucai_client/account/presentation/pages/account_form_page.dart';

/// Lists the tenant's accounts with create/delete actions.
/// Expects an [AccountBloc] from the ancestor [BlocProvider].
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  @override
  void initState() {
    super.initState();
    // Load on first build.
    context.read<AccountBloc>().add(LoadAccountsRequested());
  }

  String _formatCents(int cents) {
    // Manual currency formatting (¥ with 2 decimals) to avoid adding intl dep.
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    return '$sign¥$yuan.$fen';
  }

  Future<void> _confirmDelete(Account account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除账户'),
        content: Text('确定删除「${account.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<AccountBloc>().add(DeleteAccountRequested(account.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账户')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<AccountBloc>(),
                child: const AccountFormPage(),
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: BlocConsumer<AccountBloc, AccountState>(
        listener: (context, state) {
          if (state is AccountError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is AccountLoading && state is! AccountsLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final accounts = state is AccountsLoaded
              ? state.accounts
              : (state is AccountError ? state.accounts : (state is AccountFormSubmitting ? state.accounts : const []));
          if (accounts.isEmpty && state is! AccountFormSubmitting) {
            return RefreshIndicator(
              onRefresh: () async =>
                  context.read<AccountBloc>().add(LoadAccountsRequested()),
              child: ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('还没有账户，点 + 新建')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                context.read<AccountBloc>().add(LoadAccountsRequested()),
            child: ListView.separated(
              itemCount: accounts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final a = accounts[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(a.icon.isEmpty ? a.name.characters.first : a.icon)),
                  title: Text(a.name),
                  subtitle: Text('${a.accountType.label} · ${a.currencyCode}'),
                  trailing: Text(_formatCents(a.currentBalanceCents),
                      style: Theme.of(context).textTheme.titleSmall),
                  onLongPress: () => _confirmDelete(a),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
