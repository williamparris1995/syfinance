import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/tag/presentation/bloc/tag_bloc.dart';
import 'package:yucai_client/tag/presentation/pages/tag_page.dart';

class _MockRepo extends Mock implements TagRepository {}

const _sample = Tag(id: 't1', name: '日常', color: '#b08d57', version: 1);

Widget _harness(TagRepository repo) => MaterialApp(
      home: BlocProvider<TagBloc>(create: (_) => TagBloc(repo), child: const TagPage()),
    );

void main() {
  testWidgets('renders tag name when list non-empty', (t) async {
    final repo = _MockRepo();
    when(() => repo.list()).thenAnswer((_) async => const Right([_sample]));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();
    expect(find.text('日常'), findsOneWidget);
    expect(find.text('标签管理'), findsOneWidget);
  });

  testWidgets('renders empty state when no tags', (t) async {
    final repo = _MockRepo();
    when(() => repo.list()).thenAnswer((_) async => const Right([]));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();
    expect(find.textContaining('暂无标签'), findsOneWidget);
  });

  testWidgets('renders error state when load fails', (t) async {
    final repo = _MockRepo();
    when(() => repo.list()).thenAnswer((_) async => const Left(ServerFailure('boom')));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
  });
}
