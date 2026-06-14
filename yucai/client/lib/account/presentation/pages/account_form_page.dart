import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/bloc/account_state.dart';

/// Create-account form. Reads the [AccountBloc] from context (provided by the
/// accounts list page) so a successful create refreshes the list.
class AccountFormPage extends StatefulWidget {
  const AccountFormPage({super.key});

  @override
  State<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends State<AccountFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'CNY');
  final _balanceCtrl = TextEditingController(text: '0');
  AccountType _type = AccountType.asset;
  Ownership _ownership = Ownership.personal;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currencyCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final balanceYuan = double.tryParse(_balanceCtrl.text) ?? 0;
    context.read<AccountBloc>().add(CreateAccountRequested(CreateAccountParams(
          name: _nameCtrl.text.trim(),
          accountType: _type,
          currencyCode: _currencyCtrl.text.trim().toUpperCase(),
          initialBalanceCents: (balanceYuan * 100).round(),
          ownership: _ownership,
        )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新建账户')),
      body: BlocListener<AccountBloc, AccountState>(
        // Create success → bloc transitions to AccountsLoaded (via internal reload).
        // Pop back to the list once that happens.
        listenWhen: (prev, curr) =>
            prev is AccountFormSubmitting && curr is AccountsLoaded,
        listener: (context, state) => Navigator.of(context).pop(true),
        child: BlocBuilder<AccountBloc, AccountState>(
          builder: (context, state) {
            return AbsorbPointer(
              absorbing: state is AccountFormSubmitting,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: '账户名称'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入名称' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AccountType>(
                      decoration: const InputDecoration(labelText: '账户类型'),
                      value: _type,
                      items: AccountType.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                          .toList(),
                      onChanged: (v) => setState(() => _type = v ?? AccountType.asset),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _currencyCtrl,
                      decoration: const InputDecoration(labelText: '币种代码', hintText: 'CNY'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入币种' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _balanceCtrl,
                      decoration: const InputDecoration(labelText: '初始余额（元）'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return n == null ? '请输入有效金额' : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Ownership>(
                      decoration: const InputDecoration(labelText: '归属'),
                      value: _ownership,
                      items: Ownership.values
                          .map((o) => DropdownMenuItem(value: o, child: Text(o.label)))
                          .toList(),
                      onChanged: (v) => setState(() => _ownership = v ?? Ownership.personal),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: state is AccountFormSubmitting ? null : _submit,
                      child: state is AccountFormSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('创建'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
