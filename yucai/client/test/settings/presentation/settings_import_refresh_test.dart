// Hotfix(导入存档后 dashboard 全零)— 设置页导入存档成功路径的刷新通知
// 集成测试。
//
// 修复契约:SettingsPage._showImportArchive 在 ArchiveImporter.importAll
// 成功后调 getIt<DataRefreshNotifier>().bump()(ValueNotifier 自增),让长期
// 驻留在 IndexedStack 分支里的 HomePage 等页面重拉本地缓存;失败/取消路径
// 不 bump(数据未变,不触发无谓重载)。
//
// 注入形态照 settings_reset_test:
// - FilePicker 经 FilePickerPlatform.instance 注入假实现(pickFiles 返回
//   内存字节,file_picker 11 未公开导出平台接口,设 instance 是社区标准缝);
// - 存档字节用真 ArchiveCodec.encrypt 产(minimal envelope),保证 decrypt
//   成功走到 importAll;ArchiveImporter 注册 fake(仅计数,不动真库)。
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
// ignore: implementation_imports — file_picker 11 不公开导出平台接口,
// 测试设置 FilePickerPlatform.instance 是该包的既有惯例缝。
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/backup/data/archive_codec.dart';
import 'package:yucai_client/backup/data/archive_importer.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/notifications/tray_settings.dart';
import 'package:yucai_client/core/session_mode/bound_marker.dart';
import 'package:yucai_client/core/theme/theme_settings.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/currency/domain/entities/currency_entity.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/settings/presentation/settings_page.dart';

class _MockAuthRemote extends Mock implements AuthRemoteDataSource {}

/// 假 ArchiveImporter:仅记录 importAll 调用(不动真库;导入编排已有各自
/// 测试,此处只验证「成功后 bump」契约)。
class _FakeArchiveImporter extends Fake implements ArchiveImporter {
  int importCalls = 0;

  @override
  Future<void> importAll(Uint8List envelopeJson) async {
    importCalls++;
  }
}

class _FakeBoundMarker extends Fake implements BoundMarker {
  @override
  Future<bool> isBound() async => false;
}

class _FakeThemeSettings extends Fake implements ThemeSettings {
  final ValueNotifier<ThemeMode> _notifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);
  @override
  ValueListenable<ThemeMode> get listenable => _notifier;
  @override
  ThemeMode get value => ThemeMode.system;
  @override
  Future<void> load() async {}
  @override
  Future<void> setThemeMode(ThemeMode mode) async {}
}

/// Fake TraySettings(F22 窗口与提醒)— 满足 SettingsPage build 期 getIt
/// 解析与 SegmentedButton/Switch 的 listenable 读取(默认 hide/minutes30/
/// 显示金额)。
class _FakeTraySettings extends Fake implements TraySettings {
  final ValueNotifier<TrayCloseBehavior> _close =
      ValueNotifier<TrayCloseBehavior>(TrayCloseBehavior.hide);
  final ValueNotifier<TrayScanInterval> _scan =
      ValueNotifier<TrayScanInterval>(TrayScanInterval.minutes30);
  final ValueNotifier<bool> _amounts = ValueNotifier<bool>(true);

  @override
  ValueListenable<TrayCloseBehavior> get closeBehaviorListenable => _close;

  @override
  ValueListenable<TrayScanInterval> get scanIntervalListenable => _scan;

  @override
  ValueListenable<bool> get showTrayAmountsListenable => _amounts;
}

class _FakeCurrencySettings extends Fake implements CurrencySettings {
  _FakeCurrencySettings(this._base) : _notifier = ValueNotifier<String>(_base);
  final String _base;
  final ValueNotifier<String> _notifier;

  @override
  ValueListenable<String> get listenable => _notifier;
  @override
  String get value => _base;
  @override
  Future<String> getBaseCurrency() async => _base;
  @override
  Future<void> setBaseCurrency(String code) async {}
}

class _StubCurrencyBloc extends Fake implements CurrencyBloc {
  _StubCurrencyBloc(this._state);
  final CurrencyState _state;

  @override
  CurrencyState get state => _state;

  @override
  Stream<CurrencyState> get stream => Stream.value(_state);
}

class _StubAuthBloc extends Fake implements AuthBloc {
  _StubAuthBloc(this._state);
  final AuthState _state;

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => Stream.value(_state);
}

/// 假 FilePicker 平台:pickFiles 返回固定内存字节(null = 用户取消)。
class _FakeImportPickerPlatform extends FilePickerPlatform {
  _FakeImportPickerPlatform(this.bytes);
  Uint8List? bytes; // null = 用户取消选择

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    if (bytes == null) return null;
    return FilePickerResult([
      PlatformFile(name: 'backup.ycb', size: bytes!.length, bytes: bytes),
    ]);
  }
}

const _currencies = <Currency>[
  Currency(
      code: 'CNY',
      name: 'Chinese Yuan',
      symbol: '¥',
      exchangeRate: 7.8,
      isActive: true),
];

const _state = CurrencyState(
  currencies: _currencies,
  preferred: 'CNY',
  intervalHours: 24,
  status: CurrencyStatus.loaded,
);

void main() {
  final getIt = GetIt.instance;
  late _MockAuthRemote authRemote;
  late _FakeArchiveImporter importer;
  late DataRefreshNotifier notifier;

  setUp(() {
    authRemote = _MockAuthRemote();
    importer = _FakeArchiveImporter();
    notifier = DataRefreshNotifier();
    getIt.reset();
    getIt.registerSingleton<ArchiveImporter>(importer);
    getIt.registerSingleton<DataRefreshNotifier>(notifier);
    // SettingsPage reads TraySettings from getIt (F22 窗口与提醒)。
    getIt.registerSingleton<TraySettings>(_FakeTraySettings());
    registerFallbackValue('');
  });

  tearDown(() {
    getIt.reset();
  });

  Widget harness() => MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<CurrencyBloc>.value(value: _StubCurrencyBloc(_state)),
            BlocProvider<AuthBloc>.value(value: _StubAuthBloc(Guest())),
          ],
          child: SettingsPage(
            authRemote: authRemote,
            currencySettings: _FakeCurrencySettings('CNY'),
            themeSettings: _FakeThemeSettings(),
            boundMarker: _FakeBoundMarker(),
          ),
        ),
      );

  testWidgets('导入成功 → importAll 落库 + DataRefreshNotifier 自增 + 成功 toast',
      (t) async {
    // 真加密的 minimal 存档(version=1, modules 空)—— decrypt 成功才能走到
    // importAll(与生产同一 ArchiveCodec)。
    final sealed = ArchiveCodec.encrypt(
        Uint8List.fromList(utf8.encode('{"version":1,"modules":{}}')), 'pw-123');
    final picker = _FakeImportPickerPlatform(sealed);
    final previous = FilePickerPlatform.instance;
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = previous);

    await t.pumpWidget(harness());
    await t.pumpAndSettle();

    // 导入存档 → 选文件(假 picker)→ 密码 → 确认覆盖。
    await t.tap(find.text('导入存档'));
    await t.pump();
    await t.pump();
    await t.enterText(find.byType(TextField), 'pw-123');
    await t.tap(find.text('确定'));
    await t.pump();
    await t.pump();
    await t.tap(find.text('覆盖导入'));
    await t.pump();
    await t.pump();

    // importAll 恰好一次;刷新通知恰好自增一次(HomePage 等驻留页重拉输入)。
    expect(importer.importCalls, 1);
    expect(notifier.value, 1);
    expect(find.textContaining('存档已导入'), findsOneWidget);
  });

  testWidgets('密码错误 → 不 importAll、不 bump(数据未变)', (t) async {
    // 用 pw-right 加密,测试里输错密码 → WrongPasswordError 分支。
    final sealed = ArchiveCodec.encrypt(
        Uint8List.fromList(utf8.encode('{"version":1,"modules":{}}')),
        'pw-right');
    final picker = _FakeImportPickerPlatform(sealed);
    final previous = FilePickerPlatform.instance;
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = previous);

    await t.pumpWidget(harness());
    await t.pumpAndSettle();

    await t.tap(find.text('导入存档'));
    await t.pump();
    await t.pump();
    await t.enterText(find.byType(TextField), 'pw-wrong');
    await t.tap(find.text('确定'));
    await t.pump();
    await t.pump();

    // 失败分支:零导入、零 bump(仅 toast 错误提示)。
    expect(importer.importCalls, 0);
    expect(notifier.value, 0);
    expect(find.text('密码错误'), findsOneWidget);
  });
}
