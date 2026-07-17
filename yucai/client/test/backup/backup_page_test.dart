import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/backup/presentation/bloc/backup_bloc.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_event.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_state.dart';
import 'package:yucai_client/backup/presentation/pages/backup_page.dart';

class MockBackupBloc extends Mock implements BackupBloc {}

void main() {
  testWidgets('create encrypted backup flow dispatches CreateBackupRequested',
      (tester) async {
    final bloc = MockBackupBloc();
    when(() => bloc.state).thenReturn(BackupsLoaded([]));
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      BlocProvider<BackupBloc>.value(
        value: bloc,
        child: const MaterialApp(home: BackupPage()),
      ),
    );
    await tester.pump();

    // 立即备份 → 三选 dialog → 加密
    await tester.tap(find.text('立即备份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加密'));
    await tester.pumpAndSettle();

    // 输入密码 → 确认
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    verify(() => bloc.add(const CreateBackupRequested(true, 'secret'))).called(1);
  });
}
