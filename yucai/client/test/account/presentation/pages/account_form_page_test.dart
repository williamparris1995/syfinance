import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/get_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/pages/account_form_page.dart';

class _MockList extends Mock implements ListAccountsUseCase {}
class _MockCreate extends Mock implements CreateAccountUseCase {}
class _MockDelete extends Mock implements DeleteAccountUseCase {}
class _MockGet extends Mock implements GetAccountUseCase {}
class _MockUpdate extends Mock implements UpdateAccountUseCase {}

AccountBloc _bloc() {
  registerFallbackValue(const CreateAccountParams(
    name: '',
    accountType: AccountType.asset,
    category: AccountCategory.savings,
    currencyCode: 'CNY',
    initialBalanceCents: 0,
    ownership: Ownership.personal,
  ));
  return AccountBloc(
    _MockList(),
    _MockCreate(),
    _MockDelete(),
    _MockGet(),
    _MockUpdate(),
  );
}

void main() {
  testWidgets('cat-hint banner + notes + badge render(创建模式 savings)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<AccountBloc>(
        create: (_) => _bloc(),
        child: const AccountFormPage(),
      ),
    ));
    await tester.pump();

    // ① cat-hint banner:含 description + "示例:" + example
    expect(find.textContaining('示例:'), findsOneWidget);
    expect(find.textContaining(AccountCategory.savings.example), findsOneWidget);

    // ② notes TextFormField(备注 section,placeholder 含"补充说明")
    expect(find.textContaining('补充说明'), findsOneWidget);

    // ③ dynTitle badge:savings → 资产
    expect(find.text('资产'), findsOneWidget);
  });

  testWidgets('切换 category → cat-hint example + badge 更新', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<AccountBloc>(
        create: (_) => _bloc(),
        child: const AccountFormPage(),
      ),
    ));
    await tester.pump();

    // 点投资 tab
    await tester.tap(find.text('投资'));
    await tester.pump();

    expect(find.textContaining(AccountCategory.investment.example), findsOneWidget);
    expect(find.text('资产'), findsOneWidget); // 投资 → 资产
  });

  testWidgets('编辑模式预填 notes', (tester) async {
    const existing = Account(
      id: 'a1',
      name: '测试',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      notes: '我的备注内容',
    );
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<AccountBloc>(
        create: (_) => _bloc(),
        child: const AccountFormPage(existing: existing),
      ),
    ));
    await tester.pump();

    expect(find.text('我的备注内容'), findsOneWidget);
  });
}
