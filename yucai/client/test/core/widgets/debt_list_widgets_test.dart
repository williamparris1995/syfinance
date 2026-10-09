// F37 — DebtListCard 到期紧迫度着色的 widget 测试。
// 桌面宽度(>600)走 full 变体(DebtCardMetaKv『到期日』带后缀+色);
// 移动宽度走 compact 变体(『到期 ...』MetaItem 同后缀+色)。
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/widgets/debt_list_widgets.dart';
import 'package:yucai_client/core/widgets/debt_view_semantics.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';

class _MockDebtRepo extends Mock implements DebtRepository {}

Debt _debt(DateTime due,
    {int remaining = 1000,
    DateTime? nextPaymentDate,
    int nextPaymentPeriodNo = 0,
    int nextPaymentAmountCents = 0}) =>
    Debt(
      id: 'd1',
      accountId: 'a1',
      counterparty: '测试债',
      interestRate: 0.05,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2026, 1, 1),
      dueDate: due,
      totalPrincipalCents: 2000,
      remainingPrincipalCents: remaining,
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      subtype: DebtSubtypes.other,
      nextPaymentDate: nextPaymentDate,
      nextPaymentPeriodNo: nextPaymentPeriodNo,
      nextPaymentAmountCents: nextPaymentAmountCents,
    );

Widget _harness(Debt debt, double width) => MediaQuery(
      data: MediaQueryData(size: Size(width, 1000)),
      child: MaterialApp(
        home: Scaffold(
          body: DebtListCard(
            sem: DebtViewSemantics.debt,
            debt: debt,
            preferred: 'CNY',
            badgeFor: (d) => const DebtBadgeStyle(
                label: '测试',
                fg: Color(0xFF111111),
                bg: Color(0xFF222222)),
            avatarColorFor: (d) => const Color(0xFF333333),
          ),
        ),
      ),
    );

void main() {
  testWidgets('F37 desktop:5 天内到期 → 「（5天内）」后缀+negative 色',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_harness(
        _debt(DateTime.now().add(const Duration(days: 5))), 1440));
    await t.pumpAndSettle();
    expect(find.textContaining('（5天内）'), findsOneWidget);
  });

  testWidgets('F37 mobile:5 天内到期 → 后缀可见', (t) async {
    await t.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_harness(
        _debt(DateTime.now().add(const Duration(days: 5))), 500));
    await t.pumpAndSettle();
    expect(find.textContaining('（5天内）'), findsOneWidget);
  });

  testWidgets('F37:20 天后到期 → 无紧迫度后缀', (t) async {
    await t.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_harness(
        _debt(DateTime.now().add(const Duration(days: 20))), 1440));
    await t.pumpAndSettle();
    expect(find.textContaining('天内'), findsNothing);
    expect(find.textContaining('逾期'), findsNothing);
  });

  testWidgets('F37:已结清 → 无紧迫度后缀', (t) async {
    await t.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_harness(
        _debt(DateTime.now().add(const Duration(days: 5)), remaining: 0),
        1440));
    await t.pumpAndSettle();
    expect(find.textContaining('天内'), findsNothing);
  });

  group('F37 扩展:下一期还款日紧迫度(卡片底部 callout)', () {
    testWidgets('下一期 3 天内 → 「（3天内）」着色提示', (t) async {
      await t.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final d = _debt(DateTime(2027, 6, 1),
          nextPaymentDate: DateTime.now().add(const Duration(days: 3)),
          nextPaymentPeriodNo: 4,
          nextPaymentAmountCents: 50000);
      await t.pumpWidget(_harness(d, 1440));
      await t.pumpAndSettle();
      expect(find.textContaining('3天内'), findsOneWidget);
    });

    testWidgets('下一期 20 天后 → 无提示', (t) async {
      await t.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final d = _debt(DateTime(2027, 6, 1),
          nextPaymentDate: DateTime.now().add(const Duration(days: 20)),
          nextPaymentPeriodNo: 4,
          nextPaymentAmountCents: 50000);
      await t.pumpWidget(_harness(d, 1440));
      await t.pumpAndSettle();
      expect(find.textContaining('天内）'), findsNothing);
    });
  });

  // 更多菜单删除二次确认(误触保护):取消不触发删除,确认才 dispatch。
  // 注意:_fullCard(内容宽 ≥560)无操作条,「更多」菜单仅存在于
  // narrow/compact 变体 —— 用移动端宽度渲染紧凑卡才可测。
  group('更多菜单删除确认', () {
    testWidgets('取消 → 不删除;确认 → repo.delete', (t) async {
      await t.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final repo = _MockDebtRepo();
      registerFallbackValue(DebtType.borrowedIn);
      when(() => repo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      when(() => repo.delete(any())).thenAnswer((_) async => const dartz.Right(null));
      final bloc = DebtBloc(repo);
      final d = _debt(DateTime(2027, 6, 1));
      await t.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(500, 1000)),
        child: MaterialApp(
          home: BlocProvider<DebtBloc>(
            create: (_) => bloc,
            child: Scaffold(
              body: DebtListCard(
                sem: DebtViewSemantics.debt,
                debt: d,
                preferred: 'CNY',
                badgeFor: (dd) => const DebtBadgeStyle(
                    label: '测试',
                    fg: Color(0xFF111111),
                    bg: Color(0xFF222222)),
                avatarColorFor: (dd) => const Color(0xFF333333),
              ),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('更多'));

      // 第一轮:打开更多菜单 → 删除债务 → 弹确认 → 取消。
      // (锚定菜单 CompositedTransformFollower:finder 坐标 ≠ 绘制位,以
      // 触发按钮矩形推算 tapAt,详见 receivable_detail_page_test 同注。
      // 列表卡菜单两项:编辑在上(中心 ~24),删除在下(中心 ~56)。)
      await t.tap(find.text('更多'));
      await t.pumpAndSettle();
      // 菜单水平自适应(2026-10-08):按菜单项文本直接点击(列表卡菜单项
      // 是语义标签「删除债务」而非裸「删除」)。
      await t.tap(find.text('删除债务'));
      await t.pumpAndSettle();
      expect(find.textContaining('删除后无法恢复'), findsOneWidget);
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      verifyNever(() => repo.delete(any()));

      // 第二轮:确认 → 删除 dispatch 到 repo。
      await t.tap(find.text('更多'));
      await t.pumpAndSettle();
      await t.tap(find.text('删除债务'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, '删除'));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      verify(() => repo.delete('d1')).called(1);
      // bloc 生命周期由 BlocProvider(create:) 托管:fake-async 下手动
      // await close() 会因事件收尾未推进而永久挂起(teardown 自动关)。
    });
  });
}
