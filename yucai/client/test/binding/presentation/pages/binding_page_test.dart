// F19-T1(2026-09-11,spec FR-1/FR-5,design ADR-4):BindingPage widget 测试 ——
// 向导 UI 面:
// - readyToMerge 卡:服务端摘要(账户 N/交易 N/持仓 N)+ 合并语义说明 +
//   「合并上传」按钮 + 确认 dialog(不可自动撤销 + 建议先本地备份[纯文案]);
// - readyToUpload 卡:「上传」文案(内部同链);
// - uploading:批进度文本(「第 i/N 批·已上行 N 条」);
// - success:上行/冲突摘要(冲突 >0 提示进冲突面板);
// - failed:可重试。
//
// bloc 用 mocktail Mock + whenListen(状态手控);主题 AppTheme.light()
// (context.yucai 令牌真注入,R8)。
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/binding/presentation/bloc/binding_bloc.dart';
import 'package:yucai_client/binding/presentation/pages/binding_page.dart';
import 'package:yucai_client/core/theme/app_theme.dart';

class _MockBindingBloc extends Mock implements BindingBloc {}

Widget _harness(BindingBloc bloc) => MaterialApp(
      theme: AppTheme.light(),
      home: BlocProvider<BindingBloc>.value(
        value: bloc,
        child: const BindingPage(),
      ),
    );

void main() {
  late _MockBindingBloc bloc;

  setUpAll(() {
    registerFallbackValue(BindingMergeConfirmed());
    registerFallbackValue(BindingUploadConfirmed());
    registerFallbackValue(BindingRetryRequested());
  });

  setUp(() {
    bloc = _MockBindingBloc();
  });

  void stubState(BindingState state) {
    whenListen(bloc, const Stream<BindingState>.empty(), initialState: state);
  }

  testWidgets('readyToMerge 卡:摘要 + 合并语义 + 「合并上传」按钮',
      (tester) async {
    stubState(const BindingState(
      status: BindingStatus.readyToMerge,
      serverSummary: BindingServerSummary(
          accountCount: 2, transactionCount: 3, holdingCount: 1),
    ));

    await tester.pumpWidget(_harness(bloc));

    expect(find.textContaining('账户 2'), findsOneWidget);
    expect(find.textContaining('交易 3'), findsOneWidget);
    expect(find.textContaining('持仓 1'), findsOneWidget);
    expect(find.textContaining('合并'), findsWidgets);
    expect(find.widgetWithText(FilledButton, '合并上传'), findsOneWidget);
    verifyNever(() => bloc.add(any(that: isA<BindingMergeConfirmed>())));
  });

  testWidgets('合并确认 dialog:不可自动撤销 + 建议先本地备份;取消不发事件',
      (tester) async {
    stubState(const BindingState(
      status: BindingStatus.readyToMerge,
      serverSummary: BindingServerSummary(
          accountCount: 1, transactionCount: 0, holdingCount: 0),
    ));

    await tester.pumpWidget(_harness(bloc));
    await tester.tap(find.text('合并上传'));
    await tester.pumpAndSettle();

    expect(find.textContaining('不可自动撤销'), findsOneWidget);
    expect(find.textContaining('备份'), findsOneWidget);

    // dialog 内的「取消」(页面卡片同名按钮用 descendant 收窄)。
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('取消')));
    await tester.pumpAndSettle();
    verifyNever(() => bloc.add(any(that: isA<BindingMergeConfirmed>())));
  });

  testWidgets('dialog「确认合并上传」→ BindingMergeConfirmed', (tester) async {
    stubState(const BindingState(
      status: BindingStatus.readyToMerge,
      serverSummary: BindingServerSummary(
          accountCount: 1, transactionCount: 0, holdingCount: 0),
    ));

    await tester.pumpWidget(_harness(bloc));
    await tester.tap(find.text('合并上传'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认合并上传'));
    await tester.pumpAndSettle();

    verify(() => bloc.add(any(that: isA<BindingMergeConfirmed>()))).called(1);
  });

  testWidgets('readyToUpload 卡:上传文案 + 确认后 BindingUploadConfirmed',
      (tester) async {
    stubState(const BindingState(status: BindingStatus.readyToUpload));

    await tester.pumpWidget(_harness(bloc));

    expect(find.widgetWithText(FilledButton, '上传'), findsOneWidget);
    expect(find.textContaining('为空'), findsWidgets);

    await tester.tap(find.text('上传'));
    await tester.pumpAndSettle();
    // 确认 dialog(空账号沿用简化版)。
    await tester.tap(find.text('确认上传'));
    await tester.pumpAndSettle();

    verify(
        () => bloc.add(any(that: isA<BindingUploadConfirmed>()))).called(1);
  });

  testWidgets('uploading:批进度文本「第 i/N 批·已上行 N 条」', (tester) async {
    stubState(const BindingState(
      status: BindingStatus.uploading,
      progress: BindingProgress(
          batchIndex: 2, totalBatches: 5, uploadedChanges: 400),
    ));

    await tester.pumpWidget(_harness(bloc));

    expect(find.text('第 2/5 批·已上行 400 条'), findsOneWidget);
  });

  testWidgets('uploading 无进度:通用文案兜底', (tester) async {
    stubState(const BindingState(status: BindingStatus.uploading));

    await tester.pumpWidget(_harness(bloc));

    expect(find.textContaining('正在上传'), findsOneWidget);
  });

  testWidgets('success:上行摘要 + 冲突 >0 提示冲突面板', (tester) async {
    stubState(const BindingState(
        status: BindingStatus.success,
        uploadedEntities: 12,
        conflictCount: 2));

    await tester.pumpWidget(_harness(bloc));

    expect(find.textContaining('上行 12 条'), findsOneWidget);
    expect(find.textContaining('冲突 2'), findsOneWidget);
    expect(find.textContaining('冲突面板'), findsOneWidget);
  });

  testWidgets('success:零冲突不渲染冲突提示', (tester) async {
    stubState(const BindingState(
        status: BindingStatus.success, uploadedEntities: 5, conflictCount: 0));

    await tester.pumpWidget(_harness(bloc));

    expect(find.textContaining('上行 5 条'), findsOneWidget);
    expect(find.textContaining('冲突面板'), findsNothing);
  });

  testWidgets('failed(链内失败 canResume):「重试续传」→ BindingRetryRequested',
      (tester) async {
    stubState(const BindingState(
        status: BindingStatus.failed,
        failureMessage: '网络中断',
        canResume: true));

    await tester.pumpWidget(_harness(bloc));

    expect(find.textContaining('网络中断'), findsOneWidget);
    expect(find.textContaining('已上传部分保留'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '重试续传'), findsOneWidget);
    await tester.tap(find.text('重试续传'));
    await tester.pump();

    verify(() => bloc.add(any(that: isA<BindingRetryRequested>()))).called(1);
  });

  testWidgets('failed(守卫失败):「重新检查」→ BindingRetryRequested',
      (tester) async {
    stubState(const BindingState(
        status: BindingStatus.failed, failureMessage: '无法确认账号状态'));

    await tester.pumpWidget(_harness(bloc));

    expect(find.textContaining('可重新检查'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '重新检查'), findsOneWidget);
    await tester.tap(find.text('重新检查'));
    await tester.pump();

    verify(() => bloc.add(any(that: isA<BindingRetryRequested>()))).called(1);
  });
}
