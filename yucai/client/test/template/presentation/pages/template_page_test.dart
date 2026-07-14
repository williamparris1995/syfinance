import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/template/domain/repositories/template_repository.dart';
import 'package:yucai_client/template/presentation/bloc/template_bloc.dart';
import 'package:yucai_client/template/presentation/pages/template_page.dart';

class _MockRepo extends Mock implements TemplateRepository {}

final _sample = Template(
  id: 'tpl1',
  name: '房租',
  description: '月租',
  amountCents: 300000,
  direction: TemplateDirection.expense,
  sourceAccountId: 'acc1',
  destinationAccountId: null,
  cycle: TemplateCycle.monthly,
  cycleDays: 0,
  billingDay: 5,
  nextDate: '2026-08-05',
  startDate: '2026-01-01',
  endDate: null,
  autoRecord: true,
  paused: false,
  lastTransactionId: null,
  category: '居住',
  version: 1,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Widget _harness(TemplateRepository repo) => MaterialApp(
      home: BlocProvider<TemplateBloc>(
        create: (_) => TemplateBloc(repo),
        child: const TemplatePage(),
      ),
    );

void main() {
  testWidgets('renders template name when list non-empty', (t) async {
    final repo = _MockRepo();
    when(() => repo.list()).thenAnswer((_) async => Right([_sample]));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();
    expect(find.text('房租'), findsOneWidget);
    expect(find.text('周期模板'), findsOneWidget);
  });

  testWidgets('renders empty state when no templates', (t) async {
    final repo = _MockRepo();
    when(() => repo.list()).thenAnswer((_) async => const Right([]));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();
    expect(find.textContaining('暂无周期模板'), findsOneWidget);
  });

  testWidgets('renders error state when load fails', (t) async {
    final repo = _MockRepo();
    when(() => repo.list())
        .thenAnswer((_) async => const Left(ServerFailure('boom')));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
  });
}
