import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/backup/domain/entities/backup_settings_entity.dart';
import 'package:yucai_client/backup/domain/repositories/backup_repository.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_settings_bloc.dart';
import 'package:yucai_client/backup/presentation/pages/backup_settings_page.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockRepo extends Mock implements BackupRepository {}

class _SettingsFake extends Fake implements BackupSettings {}

const _disabled = BackupSettings(autoBackup: false, intervalHours: 24);
const _enabled24 = BackupSettings(autoBackup: true, intervalHours: 24);

Widget _harness(BackupRepository repo) => MaterialApp(
      home: BlocProvider<BackupSettingsBloc>(
        create: (_) => BackupSettingsBloc(repo),
        child: const BackupSettingsPage(),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_SettingsFake());
  });

  testWidgets('renders title + switch off; interval picker hidden when off',
      (t) async {
    final repo = _MockRepo();
    when(() => repo.getCloudSettings())
        .thenAnswer((_) async => const Right(_disabled));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    expect(find.text('自动备份'), findsWidgets); // topbar + section 标题
    final sw = t.widget<Switch>(find.byType(Switch));
    expect(sw.value, false); // autoBackup=false
    // picker 仅在 switch on 时渲染 —— off 时不应找到频率 dropdown 文本
    expect(find.text('备份频率'), findsNothing);
  });

  testWidgets('shows error state when load fails', (t) async {
    final repo = _MockRepo();
    when(() => repo.getCloudSettings())
        .thenAnswer((_) async => const Left(ServerFailure('boom')));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('load enabled → switch on + picker 显示 24h', (t) async {
    final repo = _MockRepo();
    when(() => repo.getCloudSettings())
        .thenAnswer((_) async => const Right(_enabled24));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    expect(t.widget<Switch>(find.byType(Switch)).value, true);
    expect(find.text('备份频率'), findsOneWidget);
    expect(find.text('24h'), findsOneWidget);
  });

  testWidgets(
      'toggling switch off→on + save dispatches SaveSettingsRequested(true, 24)',
      (t) async {
    final repo = _MockRepo();
    when(() => repo.getCloudSettings())
        .thenAnswer((_) async => const Right(_disabled));
    when(() => repo.saveCloudSettings(any()))
        .thenAnswer((_) async => const Right(null));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle(); // load 完成

    await t.tap(find.byType(Switch));
    await t.pump();
    expect(t.widget<Switch>(find.byType(Switch)).value, true);
    // 现在频率 picker 出现，默认 24h
    expect(find.text('24h'), findsOneWidget);

    await t.tap(find.text('保存'));
    await t.pumpAndSettle(); // save → Saved

    final captured =
        verify(() => repo.saveCloudSettings(captureAny())).captured;
    final s = captured.single as BackupSettings;
    expect(s.autoBackup, true);
    expect(s.intervalHours, 24);

    expect(find.text('自动备份设置已保存'), findsOneWidget); // SnackBar
  });

  testWidgets('interval picker 24h → 48h changes saved intervalHours', (t) async {
    final repo = _MockRepo();
    when(() => repo.getCloudSettings())
        .thenAnswer((_) async => const Right(_enabled24));
    when(() => repo.saveCloudSettings(any()))
        .thenAnswer((_) async => const Right(null));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    await t.tap(find.text('24h')); // 打开 dropdown
    await t.pumpAndSettle();
    await t.tap(find.text('48h').last); // 选 48h（overlay 列表里）
    await t.pump();

    await t.tap(find.text('保存'));
    await t.pumpAndSettle();

    final captured =
        verify(() => repo.saveCloudSettings(captureAny())).captured;
    expect((captured.single as BackupSettings).intervalHours, 48);
  });

  testWidgets('save failure shows SnackBar with error message', (t) async {
    final repo = _MockRepo();
    when(() => repo.getCloudSettings())
        .thenAnswer((_) async => const Right(_disabled));
    when(() => repo.saveCloudSettings(any()))
        .thenAnswer((_) async => const Left(ServerFailure('保存失败')));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    await t.tap(find.byType(Switch));
    await t.pump();
    await t.tap(find.text('保存'));
    await t.pumpAndSettle();

    expect(find.text('保存失败'), findsOneWidget);
  });
}
