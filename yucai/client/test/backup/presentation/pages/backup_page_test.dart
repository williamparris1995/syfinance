import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/backup/domain/entities/backup_entity.dart';
import 'package:yucai_client/backup/domain/repositories/backup_repository.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_bloc.dart';
import 'package:yucai_client/backup/presentation/pages/backup_page.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockRepo extends Mock implements BackupRepository {}

const _sample = Backup(
  id: 'b1',
  filename: 'a.zip',
  sizeBytes: 1024,
  checksum: 'ck',
  encrypted: false,
  auto: false,
  createdAt: null,
);

Widget _harness(BackupRepository repo) => MaterialApp(
      home: BlocProvider<BackupBloc>(
        create: (_) => BackupBloc(repo),
        child: const BackupPage(),
      ),
    );

void main() {
  testWidgets('renders backup filename when list non-empty', (t) async {
    final repo = _MockRepo();
    when(() => repo.list()).thenAnswer((_) async => const Right([_sample]));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();
    expect(find.text('a.zip'), findsOneWidget);
    expect(find.text('本地备份'), findsOneWidget);
  });

  testWidgets('renders empty state when no backups', (t) async {
    final repo = _MockRepo();
    when(() => repo.list()).thenAnswer((_) async => const Right([]));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();
    expect(find.textContaining('暂无备份'), findsOneWidget);
  });

  testWidgets('renders error state when load fails', (t) async {
    final repo = _MockRepo();
    when(() => repo.list())
        .thenAnswer((_) async => const Left(ServerFailure('boom')));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();
    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('create dialog dispatches CreateBackupRequested(encrypted)',
      (t) async {
    final repo = _MockRepo();
    when(() => repo.list()).thenAnswer((_) async => const Right([_sample]));
    when(() => repo.create(encrypted: true))
        .thenAnswer((_) async => const Right(_sample));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle(); // 列表加载完成

    await t.tap(find.text('立即备份'));
    await t.pumpAndSettle(); // encrypted dialog 弹出
    expect(find.text('是否加密备份文件？'), findsOneWidget);

    await t.tap(find.widgetWithText(FilledButton, '加密'));
    await t.pumpAndSettle(); // create → refresh

    verify(() => repo.create(encrypted: true)).called(1);
  });
}
