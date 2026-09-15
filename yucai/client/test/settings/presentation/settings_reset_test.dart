// F21-T1 — 设置页「清空数据重新开始」三步确认流 widget 测试。
//
// 覆盖 spec FR-1/2/3/6:
// - FR-1 入口:未绑定(guest 本地模式)渲染,negative 警示行;
// - FR-6 绑定态隐藏:BoundMarker.isBound()==true → 整行不可见;
// - FR-2 三步流:「我已了解风险」→ 密码框 → 确认清空 → reset(备份路径+密码)
//   + 成功提示;
// - FR-3 fail-closed:步②保存位置取消(FilePicker 返回 null)→ 直接中止,
//   清空执行零调用。
//
// 缝:DataResetController 整体注入 mocktail mock;FilePicker 经
// FilePickerPlatform.instance 注入假实现(file_picker 11 未公开导出平台
// 接口,设 instance 是社区标准测试缝)。
import 'package:file_picker/file_picker.dart';
// ignore: implementation_imports — file_picker 11 不公开导出平台接口,
// 测试设置 FilePickerPlatform.instance 是该包的既有惯例缝。
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/core/notifications/tray_settings.dart';
import 'package:yucai_client/core/session_mode/bound_marker.dart';
import 'package:yucai_client/core/theme/theme_settings.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/currency/domain/entities/currency_entity.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/settings/data/data_reset_controller.dart';
import 'package:yucai_client/settings/presentation/settings_page.dart';

class _MockAuthRemote extends Mock implements AuthRemoteDataSource {}

class _MockDataResetController extends Mock implements DataResetController {}

/// 假 BoundMarker:isBound 可配置(FR-6 绑定态隐藏判定输入)。
class _FakeBoundMarker extends Fake implements BoundMarker {
  _FakeBoundMarker(this._bound);
  final bool _bound;

  @override
  Future<bool> isBound() async => _bound;
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
/// 解析与 SegmentedButton 的 listenable 读取(默认 hide/minutes30)。
class _FakeTraySettings extends Fake implements TraySettings {
  final ValueNotifier<TrayCloseBehavior> _close =
      ValueNotifier<TrayCloseBehavior>(TrayCloseBehavior.hide);
  final ValueNotifier<TrayScanInterval> _scan =
      ValueNotifier<TrayScanInterval>(TrayScanInterval.minutes30);

  @override
  ValueListenable<TrayCloseBehavior> get closeBehaviorListenable => _close;

  @override
  ValueListenable<TrayScanInterval> get scanIntervalListenable => _scan;
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

/// 假 FilePicker 平台:saveFile 返回固定路径(null = 用户取消),
/// 记录请求的默认文件名(断言 ycb 命名契约)。
class _FakeFilePickerPlatform extends FilePickerPlatform {
  _FakeFilePickerPlatform(this.resultPath);
  String? resultPath; // null = 用户取消保存
  String? lastFileName;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    lastFileName = fileName;
    return resultPath;
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

const _backupPath = r'C:\backups\yucai-reset-backup-20260914-0930.ycb';

void main() {
  late _MockAuthRemote authRemote;
  late _MockDataResetController resetController;
  late _FakeFilePickerPlatform picker;

  setUp(() {
    authRemote = _MockAuthRemote();
    resetController = _MockDataResetController();
    when(() => resetController.stats())
        .thenAnswer((_) async => (accounts: 2, transactions: 5));
    when(() => resetController.reset(
            backupPath: any(named: 'backupPath'),
            password: any(named: 'password')))
        .thenAnswer((_) async {});
    picker = _FakeFilePickerPlatform(_backupPath);
    final previous = FilePickerPlatform.instance;
    FilePickerPlatform.instance = picker;
    addTearDown(() => FilePickerPlatform.instance = previous);
    registerFallbackValue(''); // any(named:) 的 String 回退值
    // SettingsPage reads TraySettings from getIt (F22 窗口与提醒;其余依赖
    // 经构造注入,此件照 ThemeSettings 先例 getIt 直取)。
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<TraySettings>()) {
      getIt.registerSingleton<TraySettings>(_FakeTraySettings());
    }
  });

  Widget harness({required bool bound}) => MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<CurrencyBloc>.value(value: _StubCurrencyBloc(_state)),
            BlocProvider<AuthBloc>.value(value: _StubAuthBloc(Guest())),
          ],
          child: SettingsPage(
            authRemote: authRemote,
            currencySettings: _FakeCurrencySettings('CNY'),
            themeSettings: _FakeThemeSettings(),
            boundMarker: _FakeBoundMarker(bound),
            resetController: resetController,
          ),
        ),
      );

  testWidgets('FR-1 未绑定(guest)渲染「清空数据重新开始」入口', (t) async {
    await t.pumpWidget(harness(bound: false));
    await t.pumpAndSettle();
    expect(find.text('清空数据重新开始'), findsOneWidget);
  });

  testWidgets('FR-6 绑定态整行隐藏(BoundMarker.isBound == true)', (t) async {
    await t.pumpWidget(harness(bound: true));
    await t.pumpAndSettle();
    expect(find.text('清空数据重新开始'), findsNothing);
  });

  testWidgets('FR-2 三步流:警示 → 密码 → 确认清空 → reset + 成功提示', (t) async {
    await t.pumpWidget(harness(bound: false));
    await t.pumpAndSettle();

    // 步① 警示:数据规模(mock stats)+「我已了解风险」进入下一步。
    await t.tap(find.text('清空数据重新开始'));
    await t.pump();
    await t.pump();
    expect(find.textContaining('2 个账户'), findsOneWidget);
    expect(find.textContaining('5 笔交易'), findsOneWidget);
    await t.tap(find.text('我已了解风险'));
    await t.pump();
    await t.pump();

    // 步② 密码 + 保存位置:两次输入一致 → FilePicker.saveFile(默认 ycb 名)。
    expect(find.text('设置清空备份密码'), findsOneWidget);
    await t.enterText(find.byType(TextField).at(0), 'pw-123');
    await t.enterText(find.byType(TextField).at(1), 'pw-123');
    await t.tap(find.text('选择保存位置'));
    await t.pump();
    await t.pump();
    expect(picker.lastFileName, startsWith('yucai-reset-backup-'));
    expect(picker.lastFileName, endsWith('.ycb'));

    // 步③ 最终确认:展示备份路径,红色「确认清空」执行(dialog 标题同文案,
    // 精确点 FilledButton)。
    expect(find.textContaining(_backupPath), findsOneWidget);
    expect(find.textContaining('该密码用于日后找回'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, '确认清空'));
    await t.pump();
    await t.pump();

    // 执行:reset(备份路径+密码)恰好一次,并给出成功提示(含找回指引;
    // 「导入存档 + 备份密码」只出现在成功 dialog,页面常态行是「导入存档」)。
    verify(() => resetController.reset(
        backupPath: _backupPath, password: 'pw-123')).called(1);
    expect(find.text('已清空'), findsOneWidget); // 成功 dialog 标题
    expect(find.textContaining('导入存档 + 备份密码'), findsOneWidget);
  });

  testWidgets('FR-3 步②取消保存位置 → 直接中止,不触清空', (t) async {
    picker.resultPath = null; // 模拟用户在保存对话框点了取消
    await t.pumpWidget(harness(bound: false));
    await t.pumpAndSettle();

    // 走到步② 后取消保存位置(FilePicker 返回 null)。
    await t.tap(find.text('清空数据重新开始'));
    await t.pump();
    await t.pump();
    await t.tap(find.text('我已了解风险'));
    await t.pump();
    await t.pump();
    await t.enterText(find.byType(TextField).at(0), 'pw-123');
    await t.enterText(find.byType(TextField).at(1), 'pw-123');
    await t.tap(find.text('选择保存位置'));
    await t.pump();
    await t.pump();

    // 中止:无最终确认 dialog,清空执行零调用(fail-closed)。
    expect(find.text('确认清空'), findsNothing);
    verifyNever(() => resetController.reset(
        backupPath: any(named: 'backupPath'),
        password: any(named: 'password')));
  });
}
