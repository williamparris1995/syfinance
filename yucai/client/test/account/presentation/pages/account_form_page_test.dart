import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/form_leave_gate.dart';
import 'package:yucai_client/core/shell_detail_title.dart';

import 'package:yucai_client/account/domain/account_presets.dart';
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

/// F52 T2:预填通道测试 harness —— 以可选 preset/preselectCreditCard 包裹表单。
Widget wrapFormPage({AccountPreset? preset, bool preselectCreditCard = false}) =>
    MaterialApp(
      home: BlocProvider<AccountBloc>(
        create: (_) => _bloc(),
        child: AccountFormPage(
          preset: preset,
          preselectCreditCard: preselectCreditCard,
        ),
      ),
    );

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

  // —— F52 T2(FR-3/ADR-3):预设预填通道 ——
  // 构造参数 AccountFormPage({preset, preselectCreditCard}) → initState 回填
  // (类别=creditCard;name/institution;biling/repayment 当非 null);预填态
  // 头部 muted chip「预设 · 可修改」;日期空 + hint;全字段可编辑;无参零 diff。
  group('F52 预设预填通道', () {
    testWidgets('花呗预填:creditCard/名称/机构/账单日1/还款日9 全量,额度空,全可改', (tester) async {
      await tester.pumpWidget(wrapFormPage(preset: accountPresets.first));
      await tester.pump();

      // 角标:头部 muted chip「预设 · 可修改」
      expect(find.text('预设 · 可修改'), findsOneWidget);
      // 类别=creditCard(分组标题 + cat-hint 切信用卡口径)
      expect(find.text('信用卡信息'), findsOneWidget);
      expect(find.textContaining(AccountCategory.creditCard.example),
          findsOneWidget);
      // 名称/机构预填
      expect(find.text('花呗'), findsOneWidget);
      expect(find.text('蚂蚁消费金融'), findsOneWidget);
      // 账单日 1 / 还款日 9 预填(下拉回显)
      expect(find.text('1日'), findsOneWidget);
      expect(find.text('9日'), findsOneWidget);
      // 额度留空(信用额度控制器为空,待用户补)
      final limitField = tester.widget<TextFormField>(
        find
            .ancestor(
                of: find.text('信用额度'), matching: find.byType(TextFormField))
            .first,
      );
      expect(limitField.controller!.text, '');
      // 花呗日期固定(hint 空)→ 无提示行
      expect(find.text('账单日按激活日,建后可改'), findsNothing);

      // 全字段可编辑:名称改值
      await tester.enterText(
          find
              .ancestor(
                  of: find.text('花呗'), matching: find.byType(TextFormField))
              .first,
          '花呗备用');
      expect(find.text('花呗备用'), findsOneWidget);

      // 全字段可编辑:账单日 1日 → 5日
      await tester.ensureVisible(find.text('1日'));
      await tester.tap(find.text('1日'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5日').last);
      await tester.pumpAndSettle();
      expect(find.text('5日'), findsOneWidget);
      expect(find.text('1日'), findsNothing);

      // 切类别 = 弃预设态(角标随 clearAll 消失)
      await tester.ensureVisible(find.text('储蓄'));
      await tester.tap(find.text('储蓄'));
      await tester.pump();
      expect(find.text('预设 · 可修改'), findsNothing);
    });

    testWidgets('白条类预填:名称/机构预填,日期空 + hint', (tester) async {
      await tester.pumpWidget(wrapFormPage(preset: accountPresets[1]));
      await tester.pump();

      expect(find.text('预设 · 可修改'), findsOneWidget);
      expect(find.text('京东白条'), findsOneWidget);
      expect(find.text('京东'), findsOneWidget);
      // 日期未预填(无回显)
      expect(find.text('1日'), findsNothing);
      expect(find.text('9日'), findsNothing);
      // 日期空 + preset → hint 提示行
      expect(find.text('账单日按激活日,建后可改'), findsOneWidget);
    });

    testWidgets('普通信用卡:仅类别预选,其余空,无角标无 hint', (tester) async {
      await tester.pumpWidget(wrapFormPage(preselectCreditCard: true));
      await tester.pump();

      expect(find.text('信用卡信息'), findsOneWidget);
      expect(find.textContaining(AccountCategory.creditCard.example),
          findsOneWidget);
      // 名称空
      final nameField = tester.widget<TextFormField>(
        find
            .ancestor(
                of: find.text('账户名称'), matching: find.byType(TextFormField))
            .first,
      );
      expect(nameField.controller!.text, '');
      // 机构空
      final instField = tester.widget<TextFormField>(
        find
            .ancestor(
                of: find.text('发卡机构'), matching: find.byType(TextFormField))
            .first,
      );
      expect(instField.controller!.text, '');
      // 非预设来源 → 无角标/无 hint
      expect(find.text('预设 · 可修改'), findsNothing);
      expect(find.text('账单日按激活日,建后可改'), findsNothing);
    });

    testWidgets('无参现状零 diff:默认储蓄,无角标无 hint', (tester) async {
      await tester.pumpWidget(wrapFormPage());
      await tester.pump();

      expect(find.text('储蓄信息'), findsOneWidget);
      expect(find.text('信用卡信息'), findsNothing);
      expect(find.text('预设 · 可修改'), findsNothing);
      expect(find.text('账单日按激活日,建后可改'), findsNothing);
    });
  });

  // ── F59 FR-5(ADR-3):表单页接线 —— AppBar 退役 + 三级注入 + 离开守卫 ──
  group('F59 FR-5 表单页接线', () {
    // 本文件其余组不使用 GetIt;组内两 port 用后复位,不外泄。
    tearDown(() async {
      await GetIt.instance.reset();
    });

    const existingSeed = Account(
      id: 'a1',
      name: '测试',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

    /// 推入式 harness(form 页 push 于宿主页上,系统返回断言锚点)+ 两 port。
    Future<void> pumpPushed(WidgetTester t, {Account? existing}) async {
      if (!GetIt.instance.isRegistered<ShellDetailTitle>()) {
        GetIt.instance
            .registerLazySingleton<ShellDetailTitle>(ShellDetailTitle.new);
      }
      if (!GetIt.instance.isRegistered<FormLeaveGate>()) {
        GetIt.instance.registerLazySingleton<FormLeaveGate>(FormLeaveGate.new);
      }
      // BlocProvider 须在 MaterialApp 之上:pushed 路由不在 home 子树内,
      // provider 在 home 下则表单页 context.read 找不到。
      await t.pumpWidget(BlocProvider<AccountBloc>(
        create: (_) => _bloc(),
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).push(
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              AccountFormPage(existing: existing))),
                  child: const Text('__host__'),
                ),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('__host__'));
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 50)); // DetailTitleSync 帧回调
    }

    testWidgets('AppBar 零残留 + 注入串两态(新建账户 / 编辑 · 账户名)', (t) async {
      await pumpPushed(t);
      expect(find.byType(AppBar), findsNothing, reason: '自带 AppBar 导航退役');
      expect(GetIt.instance<ShellDetailTitle>().value, '新建账户');
      await t.binding.handlePopRoute(); // 净态退栈后再推编辑态
      await t.pumpAndSettle();

      await pumpPushed(t, existing: existingSeed);
      expect(find.byType(AppBar), findsNothing);
      expect(GetIt.instance<ShellDetailTitle>().value, '编辑 · 测试');
    });

    testWidgets('净态:系统返回直放零弹框', (t) async {
      await pumpPushed(t);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing, reason: '净态零摩擦');
      expect(find.text('__host__'), findsOneWidget);
    });

    testWidgets('F-1:首改(币种下拉)后系统返回弹确认', (t) async {
      await pumpPushed(t);
      // 不触碰 name 字段 —— 隔离 F-1 缺口(下拉无 controller 写入)。
      await t.tap(find.text('币种').first);
      await t.pumpAndSettle();
      final usd = find.text('USD').last;
      if (usd.evaluate().isNotEmpty) {
        await t.tap(usd);
        await t.pumpAndSettle();
        await t.binding.handlePopRoute();
        await t.pump();
        expect(find.text('未保存的修改'), findsOneWidget,
            reason: '币种下拉须置脏(F-1)');
        await t.tap(find.text('继续编辑'));
        await t.pumpAndSettle();
      }
    });

    testWidgets('脏态:首改(账户名)后系统返回弹确认,放弃后净放', (t) async {
      await pumpPushed(t);
      await t.enterText(
          find.widgetWithText(TextFormField, '账户名称'), '招商储蓄');
      await t.pumpAndSettle();

      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.text('未保存的修改'), findsOneWidget);
      await t.tap(find.text('继续编辑'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '账户名称'), findsOneWidget);

      await t.binding.handlePopRoute();
      await t.pump();
      await t.tap(find.text('放弃修改'));
      await t.pumpAndSettle();
      expect(find.text('__host__'), findsOneWidget, reason: '「放弃修改」放行离开');
    });

    testWidgets('脏态:面包屑 page 级 veto(gate.mayLeave)同弹确认;dispose 清注入',
        (t) async {
      await pumpPushed(t);
      expect(await GetIt.instance<FormLeaveGate>().mayLeave(), isTrue,
          reason: '净态直放');
      await t.enterText(
          find.widgetWithText(TextFormField, '账户名称'), '招商储蓄');
      await t.pumpAndSettle();
      final leave = GetIt.instance<FormLeaveGate>().mayLeave();
      await t.pump();
      expect(find.text('未保存的修改'), findsOneWidget, reason: '面包屑路径同守卫');
      await t.tap(find.text('放弃修改'));
      await t.pumpAndSettle();
      expect(await leave, isTrue);
      expect(GetIt.instance<ShellDetailTitle>().value, '新建账户');

      // mayLeave 只问询不复净:退栈仍走确认(canPop=false)→ 放弃后 dispose
      // 清注入 + veto 注销。
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.text('未保存的修改'), findsOneWidget);
      await t.tap(find.text('放弃修改'));
      await t.pumpAndSettle();
      expect(GetIt.instance<ShellDetailTitle>().value, isNull);
      expect(await GetIt.instance<FormLeaveGate>().mayLeave(), isTrue);
    });
  });
}
