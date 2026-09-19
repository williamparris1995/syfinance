import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/backup/data/archive_codec.dart';
import 'package:yucai_client/backup/data/archive_importer.dart';
import 'package:yucai_client/core/notifications/app_updater.dart';
import 'package:yucai_client/backup/data/local_snapshot_exporter.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' hide Currency;
import 'package:yucai_client/core/notifications/app_exit_port.dart';
import 'package:yucai_client/core/notifications/tray_settings.dart';
import 'package:yucai_client/core/session_mode/bound_marker.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/theme/theme_settings.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/currency/domain/entities/currency_entity.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_event.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/settings/data/data_reset_controller.dart';
import 'package:yucai_client/settings/data/local_snapshot_service.dart';

/// 设置页 —— 偏好货币 + 本位币 + 汇率同步频率。
///
/// 读 [CurrencyBloc] 的 currencies 列表 + 当前 preferred / interval，
/// onChange → [AuthRemoteDataSource.updatePreferences] → 成功 toast +
/// `LoadPreferencesRequested` 刷新。
///
/// 本位币(Task 12 D-currency):读 [CurrencySettings.getBaseCurrency],
/// onChange → [CurrencySettings.setBaseCurrency] 持久化 → toast 提示
/// 「重启或刷新生效」(performance/detail/home 下次进入即用新本位币折算)。
///
/// 御财 token：surface card (`context.yucai.surface` + `AppRadius.lgBorder` +
/// `AppSpacing.md`)；dropdown 选中色 `context.yucai.accent`。
class SettingsPage extends StatelessWidget {
  /// 生产用默认 getIt 实例；测试可注入 mock。
  const SettingsPage({
    super.key,
    AuthRemoteDataSource? authRemote,
    CurrencySettings? currencySettings,
    ThemeSettings? themeSettings,
    TraySettings? traySettings,
    BoundMarker? boundMarker,
    DataResetController? resetController,
    LocalSnapshotService? snapshotService,
  })  : _authRemote = authRemote,
        _currencySettings = currencySettings,
        _themeSettings = themeSettings,
        _traySettings = traySettings, // ignore: prefer_initializing_formals
        // 与上方三行同款形态:命名参数无法用 this._x 初始化私有字段。
        _boundMarker = boundMarker, // ignore: prefer_initializing_formals
        _resetController = // ignore: prefer_initializing_formals
            resetController,
        _snapshotService = // ignore: prefer_initializing_formals
            snapshotService;

  final AuthRemoteDataSource? _authRemote;
  final CurrencySettings? _currencySettings;
  final ThemeSettings? _themeSettings;
  final TraySettings? _traySettings;
  final BoundMarker? _boundMarker;
  final DataResetController? _resetController;
  final LocalSnapshotService? _snapshotService;

  @override
  Widget build(BuildContext context) {
    // 延迟到 build 取 getIt，避免测试构造时未配置 DI 就崩溃；显式注入优先。
    final ds = _authRemote ?? getIt<AuthRemoteDataSource>();
    final settings = _currencySettings ?? getIt<CurrencySettings>();
    final theme = _themeSettings ?? getIt<ThemeSettings>();
    // F22 窗口与提醒:照 ThemeSettings 消费方式(getIt 直取,build 期解析)。
    final tray = _traySettings ?? getIt<TraySettings>();
    // F21 清空重置:绑定态判定入口(build 期需要,FutureBuilder 用)。
    final marker = _boundMarker ?? getIt<BoundMarker>();
    // F22 页底退出:AppExitPort 生产注册在 T4(bootstrap 手工单例)。照
    // app_shell 的 isRegistered 守卫先例 —— 只探注册不构造,未注册(测试
    // 挂页无 DI 图 / T4 合入前)不 resolve,按钮隐藏而非 build 即炸。
    final exitPort =
        getIt.isRegistered<AppExitPort>() ? getIt<AppExitPort>() : null;
    // F39 本地快照:同款 isRegistered 守卫(测试挂页无 DI 图时整个
    // section 隐藏);显式注入优先,供 widget 测试用假服务。
    final snapshots = _snapshotService ??
        (getIt.isRegistered<LocalSnapshotService>()
            ? getIt<LocalSnapshotService>()
            : null);
    return Scaffold(
      backgroundColor: context.yucai.bg,
      // 无 AppBar:shell branch 8,topbar 已显面包屑「系统 › 设置」;sidebar 切换
      // (不 pop,原 BackButton pop 在 branch 内栈空 → 黑屏)。
      body: BlocBuilder<CurrencyBloc, CurrencyState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('偏好设置',
                        style: TextStyle(
                            color: context.yucai.fg,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            fontFamily: AppTypography.displayFamily,
                            fontFamilyFallback: AppTypography.displayFallback)),
                    const SizedBox(height: AppSpacing.md),
                    // Guest-only binding entry (R6 FR-3): login lives in
                    // settings so the app opens straight into offline mode.
                    // After a successful login with local data, route into the
                    // binding wizard (R6 G).
                    BlocListener<AuthBloc, AuthState>(
                      listener: (context, authState) async {
                        // Persistent bound marker (R6 H FR-3): bound devices
                        // skip the wizard on every future login.
                        if (authState is Authenticated &&
                            !await getIt<BoundMarker>().isBound()) {
                          final accounts =
                              await getIt<AppDatabase>().accountDao.getAllAccounts();
                          final txns = await getIt<AppDatabase>()
                              .transactionDao
                              .getAllTransactions();
                          if (accounts.isNotEmpty || txns.isNotEmpty) {
                            context.push('/binding');
                          }
                        }
                      },
                      child: BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, authState) {
                        if (authState is! Guest) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _SettingsCard(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => context.push('/login'),
                              child: const _PreferenceRow(
                                label: '登录账号',
                                description: '绑定后可同步数据到服务器',
                                control: const Icon(LucideIcons.chevronRight),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    ),
                    // 外观(R8 F1):主题模式 跟随系统/亮/暗,持久化 ThemeSettings,
                    // ValueListenableBuilder 让选中态随 theme.listenable 实时刷新。
                    _SettingsCard(
                      child: ValueListenableBuilder<ThemeMode>(
                        valueListenable: theme.listenable,
                        builder: (context, mode, _) => _PreferenceRow(
                          label: '主题模式',
                          description: '亮色=晨白 · 暗色=墨鎏金 · 即时生效',
                          control: SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                  value: ThemeMode.system,
                                  label: Text('跟随系统')),
                              ButtonSegment(
                                  value: ThemeMode.light,
                                  label: Text('亮色')),
                              ButtonSegment(
                                  value: ThemeMode.dark,
                                  label: Text('暗色')),
                            ],
                            selected: {mode},
                            showSelectedIcon: false,
                            onSelectionChanged: (selection) =>
                                theme.setThemeMode(selection.first),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Archive export/import (R6 J) — full interaction.
                    _SettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _showExportArchive(context),
                            child: const _PreferenceRow(
                              label: '导出存档',
                              description: '加密备份到任意位置（U盘/云盘）',
                              control: Icon(LucideIcons.fileDown),
                            ),
                          ),
                          Divider(height: 1, color: context.yucai.border),
                          const SizedBox(height: AppSpacing.md),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _showImportArchive(context),
                            child: const _PreferenceRow(
                              label: '导入存档',
                              description: '从存档文件恢复（覆盖本地数据）',
                              control: Icon(LucideIcons.fileUp),
                            ),
                          ),
                          // F21 清空数据重新开始:仅 guest 本地模式(未绑定)
                          // 显示 —— 绑定态的数据主体在服务端,本机清空语义不同
                          // (server 侧清空另议,spec FR-6),故整行隐藏;判定源
                          // 是持久化的 BoundMarker(与登录卡片同源)。
                          FutureBuilder<bool>(
                            future: marker.isBound(),
                            builder: (context, snap) {
                              if (!snap.hasData || snap.data!) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Divider(
                                      height: 1, color: context.yucai.border),
                                  const SizedBox(height: AppSpacing.md),
                                  _NavRow(
                                    icon: LucideIcons.trash2,
                                    danger: true,
                                    label: '清空数据重新开始',
                                    description: '删库前自动加密备份，可通过导入存档找回',
                                    onTap: () => _showResetData(context),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // F39 本地快照(与导出/导入存档并列,独立卡片):仅
                    // guest 本地模式显示 —— 判定源与登录/清空卡片同为
                    // BoundMarker;绑定态数据主体在服务端,本机快照恢复会
                    // 覆盖镜像,语义不同,故绑定态整卡隐藏。
                    if (snapshots != null)
                      FutureBuilder<bool>(
                        future: marker.isBound(),
                        builder: (context, snap) {
                          if (!snap.hasData || snap.data!) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding:
                                const EdgeInsets.only(top: AppSpacing.md),
                            child: _LocalSnapshotCard(service: snapshots),
                          );
                        },
                      ),
                    const SizedBox(height: AppSpacing.md),
                    // F22 窗口与提醒(置于「数据」区之后,原型
                    // ui/settings-window-reminders.html):关闭按钮行为 +
                    // 提醒检查频率,持久化 TraySettings(T1);SegmentedButton
                    // 行与「外观·主题模式」同款(setting-row-seg),选中态经
                    // listenable 实时刷新,setX 异步 fire-and-forget(广播即可)。
                    _SettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('窗口与提醒',
                              style: TextStyle(
                                  color: context.yucai.fg,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: AppSpacing.sm),
                          ValueListenableBuilder<TrayCloseBehavior>(
                            valueListenable: tray.closeBehaviorListenable,
                            builder: (context, behavior, _) => _PreferenceRow(
                              label: '关闭按钮行为',
                              description:
                                  '点窗口 ✕ 时:隐藏到托盘继续运行,或直接退出',
                              control: SegmentedButton<TrayCloseBehavior>(
                                segments: const [
                                  ButtonSegment(
                                      value: TrayCloseBehavior.hide,
                                      label: Text('隐藏到托盘')),
                                  ButtonSegment(
                                      value: TrayCloseBehavior.exit,
                                      label: Text('退出程序')),
                                ],
                                selected: {behavior},
                                showSelectedIcon: false,
                                onSelectionChanged: (selection) => tray
                                    .setCloseBehavior(selection.first),
                              ),
                            ),
                          ),
                          Divider(height: 1, color: context.yucai.border),
                          const SizedBox(height: AppSpacing.md),
                          ValueListenableBuilder<TrayScanInterval>(
                            valueListenable: tray.scanIntervalListenable,
                            builder: (context, interval, _) => _PreferenceRow(
                              label: '提醒检查频率',
                              description:
                                  '到期提醒与自动记账的定时扫描间隔;数据变更时总会即时检查',
                              control: SegmentedButton<TrayScanInterval>(
                                segments: const [
                                  ButtonSegment(
                                      value: TrayScanInterval.minutes15,
                                      label: Text('15 分钟')),
                                  ButtonSegment(
                                      value: TrayScanInterval.minutes30,
                                      label: Text('30 分钟')),
                                  ButtonSegment(
                                      value: TrayScanInterval.minutes60,
                                      label: Text('60 分钟')),
                                ],
                                selected: {interval},
                                showSelectedIcon: false,
                                onSelectionChanged: (selection) =>
                                    tray.setScanInterval(selection.first),
                              ),
                            ),
                          ),
                          Divider(height: 1, color: context.yucai.border),
                          const SizedBox(height: AppSpacing.md),
                          // F25 托盘显示金额(FR-3 隐私开关):金额在托盘是
                          // 肩窥隐私面,默认显示,关闭即数据头变「金额已隐藏」;
                          // Switch 行照 backup_settings_page._SwitchRow 同款
                          // (activeThumbColor 语义色,禁裸 hex),选中态经
                          // listenable 实时刷新,切换即时驱动托盘菜单重设。
                          ValueListenableBuilder<bool>(
                            valueListenable: tray.showTrayAmountsListenable,
                            builder: (context, showAmounts, _) =>
                                _PreferenceRow(
                              label: '托盘显示金额',
                              description: '托盘菜单顶部的今日收支与本月结余',
                              control: Switch(
                                value: showAmounts,
                                onChanged: (v) =>
                                    tray.setShowTrayAmounts(v),
                                activeThumbColor: context.yucai.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PreferenceRow(
                            label: '偏好货币',
                            description: '用于余额汇总与报表展示',
                            control: _CurrencyDropdown(
                              state: state,
                              onChanged: (code) => _onCurrencyChanged(
                                  context, ds, code, state.intervalHours),
                            ),
                          ),
                          Divider(
                              height: 1, color: context.yucai.border),
                          const SizedBox(height: AppSpacing.md),
                          _PreferenceRow(
                            label: '本位币',
                            description: '持仓收益折算币种（净资产 / 收益统计）',
                            control: _BaseCurrencyDropdown(
                              currencies: state.currencies,
                              settings: settings,
                              onChanged: (code) =>
                                  _onBaseCurrencyChanged(context, code),
                            ),
                          ),
                          Divider(
                              height: 1, color: context.yucai.border),
                          const SizedBox(height: AppSpacing.md),
                          _PreferenceRow(
                            label: '汇率同步频率',
                            description: '多久从汇率源拉取一次最新汇率',
                            control: _IntervalDropdown(
                              value: state.intervalHours,
                              onChanged: (hours) => _onIntervalChanged(
                                  context, ds, state.preferred, hours),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SettingsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NavRow(
                            icon: LucideIcons.databaseBackup,
                            label: '本地备份',
                            description: '导出 / 恢复数据备份文件',
                            onTap: () => context.push('/settings/backup'),
                          ),
                          Divider(
                              height: 1, color: context.yucai.border),
                          const SizedBox(height: AppSpacing.md),
                          _NavRow(
                            icon: LucideIcons.timer,
                            label: '自动备份',
                            description: '配置服务端定时备份（开关 + 频率）',
                            onTap: () => context.push('/settings/backup/auto'),
                          ),
                          Divider(
                              height: 1, color: context.yucai.border),
                          const SizedBox(height: AppSpacing.md),
                          _NavRow(
                            icon: LucideIcons.tag,
                            label: '标签管理',
                            description: '管理交易标签(名称/颜色)',
                            onTap: () => context.push('/settings/tags'),
                          ),
                          Divider(
                              height: 1, color: context.yucai.border),
                          const SizedBox(height: AppSpacing.md),
                          _NavRow(
                            icon: LucideIcons.calendarClock,
                            label: '周期模板',
                            description: '管理周期交易模板',
                            onTap: () => context.push('/settings/templates'),
                          ),
                        ],
                      ),
                    ),
                    // 「关于与更新」卡(验收补充 2026-09-16):版本号展示 +
                    // 检查更新入口 —— 托盘菜单不可达时(如本次右键 bug 的
                    // 鸡生蛋场景)的更新逃生口;调用 F24 的 AppUpdater。
                    _AboutUpdateCard(),
                    // F22 页底「退出御财」:所有 card 之后、页面 padding 内。
                    // AppExitPort 未注册时隐藏(见 build 顶部 isRegistered
                    // 守卫注释;T4 bootstrap 注册后生产恒显示)。
                    if (exitPort != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _ExitFooterButton(
                          onPressed: () => exitPort.exitApp()),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 本位币切换(Task 12 D-currency):持久化到 CurrencySettings.setBaseCurrency
  /// → notifier 通知所有打开页面(home / performance / detail)立即用新值重取
  /// → toast 提示「已更新」。
  Future<void> _onBaseCurrencyChanged(
    BuildContext context,
    String code,
  ) async {
    final settings = _currencySettings ?? getIt<CurrencySettings>();
    try {
      await settings.setBaseCurrency(code);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本位币已更新')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败：$e')),
      );
    }
  }

  Future<void> _onCurrencyChanged(
    BuildContext context,
    AuthRemoteDataSource ds,
    String preferred,
    int interval,
  ) async {
    try {
      await ds.updatePreferences(preferred, interval);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('偏好货币已更新')),
      );
      context.read<CurrencyBloc>().add(const LoadPreferencesRequested());
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败：$e')),
      );
    }
  }

  Future<void> _onIntervalChanged(
    BuildContext context,
    AuthRemoteDataSource ds,
    String preferred,
    int interval,
  ) async {
    try {
      await ds.updatePreferences(preferred, interval);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('同步频率已更新')),
      );
      context.read<CurrencyBloc>().add(const LoadPreferencesRequested());
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败：$e')),
      );
    }
  }

  Future<void> _showExportArchive(BuildContext context) async {
    final password = await _askArchivePassword(context, confirm: true);
    if (password == null || password.isEmpty) return;
    try {
      final envelope = await getIt<LocalSnapshotExporter>().exportAll();
      final sealed = ArchiveCodec.encrypt(envelope, password);
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final stamp =
          '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
      final path = await FilePicker.saveFile(
        dialogTitle: '导出存档',
        fileName: 'yucai-backup-$stamp.ycb',
        bytes: sealed,
      );
      if (path == null) return; // cancelled
      if (!kIsWeb && !File(path).existsSync()) {
        await File(path).writeAsBytes(sealed);
      }
      if (!context.mounted) return;
      _toast(context, '存档已导出');
    } on Exception catch (e) {
      if (!context.mounted) return;
      _toast(context, '导出失败：$e');
    }
  }

  Future<void> _showImportArchive(BuildContext context) async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: '选择存档文件',
      type: FileType.custom,
      allowedExtensions: const ['ycb'],
      withData: true,
    );
    if (picked == null ||
        picked.files.isEmpty ||
        picked.files.single.bytes == null) {
      return;
    }
    final password = await _askArchivePassword(context, confirm: false);
    if (password == null) return;
    try {
      final envelope =
          ArchiveCodec.decrypt(picked.files.single.bytes!, password);
      final confirmed = await _confirmReplace(context);
      if (confirmed != true) return;
      await getIt<ArchiveImporter>().importAll(envelope);
      // Hotfix(导入存档后 dashboard 全零):importAll 已整批替换本地库,但
      // 首页等页面驻留在 IndexedStack 分支里(一次性 initState 加载,切回不
      // 重建),零通知会让启动空态永续 —— 这里 bump 通知长期驻留的页面级
      // 缓存重拉。绑定/镜像路径不走此通知器(各有自己的刷新语义)。
      getIt<DataRefreshNotifier>().bump();
      if (!context.mounted) return;
      _toast(context, '存档已导入（本地数据已替换）');
    } on NotArchiveError {
      if (!context.mounted) return;
      _toast(context, '不是有效的御财存档文件');
    } on WrongPasswordError {
      if (!context.mounted) return;
      _toast(context, '密码错误');
    } on ArchiveFormatError {
      if (!context.mounted) return;
      _toast(context, '存档格式无法读取（可能已损坏）');
    } on ValidationFailure catch (e) {
      if (!context.mounted) return;
      _toast(context, e.message);
    } on Exception catch (e) {
      if (!context.mounted) return;
      _toast(context, '导入失败：$e');
    }
  }

  Future<String?> _askArchivePassword(BuildContext context,
      {required bool confirm}) async {
    final controller = TextEditingController();
    final controller2 = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(confirm ? '设置存档密码' : '输入存档密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(hintText: '请输入密码'),
            ),
            if (confirm)
              TextField(
                controller: controller2,
                obscureText: true,
                decoration: const InputDecoration(hintText: '请再次输入密码'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isEmpty) return;
              if (confirm && controller.text != controller2.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('两次输入不一致')));
                return;
              }
              Navigator.of(ctx).pop(controller.text);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// F21 清空数据重新开始 —— 三步确认流(警示 → 密码+位置 → 最终确认)，
  /// 执行面是 [DataResetController](注入缝,widget 测试 mock)。
  ///
  /// FR-3 备份先行 fail-closed:步②密码取消 / 保存位置取消或失败 → 直接
  /// return 整体中止;执行段备份写失败 → error dialog 后中止(库原样保留,
  /// 执行顺序与论证见 DataResetController 类注释)。
  Future<void> _showResetData(BuildContext context) async {
    final controller = _resetController ?? getIt<DataResetController>();

    // 步① 警示:数据规模 + 三重警示,必须点「我已了解风险」才继续。
    final stats = await controller.stats();
    if (!context.mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空数据重新开始'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前本机数据:${stats.accounts} 个账户 · ${stats.transactions} 笔交易'),
            const SizedBox(height: AppSpacing.sm),
            const Text('· 本机全部账户、交易、资产等数据将被删除;'),
            const Text('· 删除前会生成加密备份(需设定密码),忘记密码将无法找回;'),
            const Text('· 完成后应用自动退出,重启后从空库开始。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          _dangerButton(
              ctx, '我已了解风险', () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;

    // 步② 密码 + 备份位置:密码 dialog(照 _askArchivePassword 形态)→
    // FilePicker.saveFile 默认名 yucai-reset-backup-yyyyMMdd-HHmm.ycb;
    // 任一取消/失败 → 直接 return(FR-3,不清空)。
    final password = await _askResetPassword(context);
    if (password == null || password.isEmpty) return;
    if (!context.mounted) return;
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}';
    final path = await FilePicker.saveFile(
      dialogTitle: '保存清空备份',
      fileName: 'yucai-reset-backup-$stamp.ycb',
    );
    if (path == null) return; // 用户取消保存 → 中止(FR-3)
    if (!context.mounted) return;

    // 步③ 最终确认:备份路径摘要 + 找回提示 + 红色「确认清空」。
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('备份将保存到:'),
            const SizedBox(height: AppSpacing.xs),
            Text(path),
            const SizedBox(height: AppSpacing.sm),
            const Text('该密码用于日后找回:设置 → 导入存档 + 该密码即可恢复数据。'),
            const SizedBox(height: AppSpacing.sm),
            const Text('确认后本机数据将被清空,应用随即退出。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          _dangerButton(ctx, '确认清空', () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // 执行:备份先行(控制器内部 fail-closed —— 任一步失败抛出,关库/删库
    // 一行不执行);此处捕获后中止并提示,数据原样保留。
    try {
      await controller.reset(backupPath: path, password: password);
    } on Exception catch (e) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('备份失败,已中止清空'),
          content: Text('备份未写入成功,本机数据未做任何改动。\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }
    if (!context.mounted) return;

    // 成功提示(FR-5:路径明示,找回 = 既有导入存档零新开发)→ 经 exit 缝
    // 退出进程(进程重启论证见 DataResetController 类注释)。
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('已清空'),
        content: Text(
          '数据已清空并备份到:\n$path\n\n'
          '如需找回：设置 → 导入存档 + 备份密码。\n应用即将退出。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    controller.exitApp();
  }

  /// 步② 密码 dialog:照导出存档的密码 dialog 形态(两次输入一致校验),
  /// 标题/提示换成清空备份语义。
  Future<String?> _askResetPassword(BuildContext context) async {
    final controller = TextEditingController();
    final controller2 = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置清空备份密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('清空前会生成加密备份;该密码是日后经「导入存档」找回的唯一凭证,请牢记。'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(hintText: '请输入密码'),
            ),
            TextField(
              controller: controller2,
              obscureText: true,
              decoration: const InputDecoration(hintText: '请再次输入密码'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isEmpty) return;
              if (controller.text != controller2.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('两次输入不一致')));
                return;
              }
              Navigator.of(ctx).pop(controller.text);
            },
            child: const Text('选择保存位置'),
          ),
        ],
      ),
    );
  }

  /// 红色危险按钮(R8 语义令牌:negative 底 + 白字),供清空流两处确认用。
  Widget _dangerButton(
      BuildContext context, String label, VoidCallback onPressed) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: context.yucai.negative,
        // F27 FR-1② 豁免:危险按钮底为 negative 状态身份彩底 —— 固定白
        // 双板可辨识(非 accent 面,不走 onAccent)。
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  Future<bool?> _confirmReplace(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('覆盖本地数据？'),
          content: const Text(
              '导入将替换本设备上的全部本地数据（账户、交易、资产等）。此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('覆盖导入'),
            ),
          ],
        ),
      );

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 「关于与更新」卡(验收补充 2026-09-16):版本号(PackageInfo=pubspec 单源)
/// + 「检查更新」(AppUpdater 引擎 UI,失败静默降级)。纯展示+入口,无状态。
class _AboutUpdateCard extends StatefulWidget {
  const _AboutUpdateCard();

  @override
  State<_AboutUpdateCard> createState() => _AboutUpdateCardState();
}

class _AboutUpdateCardState extends State<_AboutUpdateCard> {
  String? _version;

  @override
  void initState() {
    super.initState();
    // 版本取 PackageInfo(pubspec 单源派生,与托盘菜单版本行同源);
    // 失败/未达 → null(行右侧显示 '--')。
    PackageInfo.fromPlatform()
        .then((i) => mounted ? setState(() => _version = i.version) : null)
        .catchError((Object _) => null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('关于与更新',
              style: TextStyle(
                  color: t.fg, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          _PreferenceRow(
            label: '版本',
            description: '当前安装的御财版本',
            control: Text(
              _version == null ? '--' : '御财 v$_version',
              style: TextStyle(color: t.muted, fontSize: 13),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _NavRow(
            icon: LucideIcons.refreshCw,
            label: '检查更新',
            description: '手动检查新版本(每天也会自动检查)',
            onTap: () => AppUpdater.checkForUpdates(),
          ),
        ],
      ),
    );
  }
}

/// F22 页底「退出御财」按钮(btn-exit-footer):全宽高 40、圆角 12、soft
/// destructive —— negativeSoft 底 + negative 描边/文字、hover 加深、含
/// log-out 图标;非实底红,防误触(警示强度与 F21 清空行同级)。
///
/// negativeSoft 令牌 YucaiTheme 暂缺(T2 禁区:不改令牌定义),soft 底由
/// negative 令牌 + 低透明度派生(照 debt_detail_widgets 的 soft 派生先例,
/// 禁裸 hex);亮暗主题各自随本主题 negative 取值。
class _ExitFooterButton extends StatelessWidget {
  const _ExitFooterButton({required this.onPressed});

  /// 点击即退出(经 AppExitPort,即时无确认)。
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final neg = context.yucai.negative;
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(LucideIcons.logOut, size: 18),
        label: const Text('退出御财'),
        style: ButtonStyle(
          // negSoft 底(默认 ~8% negative);hover 加深(~16%)。
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => neg.withValues(
                alpha: states.contains(WidgetState.hovered) ? 0.16 : 0.08),
          ),
          foregroundColor: WidgetStatePropertyAll(neg),
          side: WidgetStatePropertyAll(BorderSide(color: neg)),
          shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: AppRadius.smBorder)),
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(40)),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: AppSpacing.md)),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

/// 御财 surface card：`context.yucai.surface` + `AppRadius.lgBorder` + 内边距
/// `AppSpacing.md`。
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: context.yucai.border),
      ),
      child: child,
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.label,
    required this.description,
    required this.control,
  });

  final String label;
  final String description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: context.yucai.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(description,
                  style: TextStyle(
                      color: context.yucai.muted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        control,
      ],
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({required this.state, required this.onChanged});

  final CurrencyState state;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = state.currencies
        .map((c) => DropdownMenuItem<String>(
              value: c.code,
              child: Text('${c.code} · ${c.name}',
                  style: const TextStyle(fontSize: 14)),
            ))
        .toList();
    // preferred 可能不在 currencies 列表（服务端返回的 code 未在 currency 表），
    // 此时 DropdownButton.value 必须是 items 之一，否则断言；回退到首个。
    final value = state.currencies.any((c) => c.code == state.preferred)
        ? state.preferred
        : (state.currencies.isEmpty ? null : state.currencies.first.code);
    return SizedBox(
      width: 200,
      child: DropdownButton<String>(
        value: value,
        items: items,
        isExpanded: true,
        underline: const SizedBox(),
        // 御财金强调选中态：通过 dropdownColor + iconColor 表达。
        dropdownColor: context.yucai.surface,
        icon: Icon(LucideIcons.chevronDown,
            color: context.yucai.accent, size: 20),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// 本位币 dropdown(Task 12 D-currency)。当前值从 CurrencySettings 异步读
/// (FutureBuilder);选项来自 [currencies](currency 模块 ListCurrencies 结果,
/// 经 CurrencyBloc.state.currencies 注入)。onChange → 持久化(CurrencySettings
/// .setBaseCurrency)+ 调用方刷新触发。
///
/// currencies 为空(加载失败)→ fallback 硬编码列表(CNY/USD/EUR/JPY/GBP/HKD),
/// 保证用户始终可切换(对齐 brief「CNY/USD/EUR/...」)。当前 base 不在选项内
/// → 回退到列表首个(DropdownButton value 必须是 items 之一,否则断言)。
class _BaseCurrencyDropdown extends StatelessWidget {
  const _BaseCurrencyDropdown({
    required this.currencies,
    required this.settings,
    required this.onChanged,
  });

  final List<Currency> currencies;
  final CurrencySettings settings;
  final ValueChanged<String> onChanged;

  static const _fallbackCodes = ['CNY', 'USD', 'EUR', 'JPY', 'GBP', 'HKD'];

  @override
  Widget build(BuildContext context) {
    // currencies 空时用硬编码 fallback(仅 code,无 name/symbol);非空时用
    // 服务端返回的完整列表(code + name)。
    final codes = currencies.isEmpty
        ? _fallbackCodes
        : currencies.map((c) => c.code).toList();
    final items = currencies.isEmpty
        ? _fallbackCodes
            .map((code) => DropdownMenuItem<String>(
                  value: code,
                  child: Text(code, style: const TextStyle(fontSize: 14)),
                ))
            .toList()
        : currencies
            .map((c) => DropdownMenuItem<String>(
                  value: c.code,
                  child: Text('${c.code} · ${c.name}',
                      style: const TextStyle(fontSize: 14)),
                ))
            .toList();

    return ValueListenableBuilder<String>(
      valueListenable: settings.listenable,
      builder: (context, base, _) {
        // base 不在选项内 → 回退到首个(DropdownButton.value 必须是 items 之一)。
        final value = codes.contains(base) ? base : codes.first;
        return SizedBox(
          width: 200,
          child: DropdownButton<String>(
            value: value,
            items: items,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: context.yucai.surface,
            icon: Icon(LucideIcons.chevronDown,
                color: context.yucai.accent, size: 20),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        );
      },
    );
  }
}

class _IntervalDropdown extends StatelessWidget {
  const _IntervalDropdown({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _options = <int>[1, 8, 12, 24];

  @override
  Widget build(BuildContext context) {
    final items = _options
        .map((h) => DropdownMenuItem<int>(
              value: h,
              child: Text('${h}h',
                  style: const TextStyle(fontSize: 14)),
            ))
        .toList();
    final v = _options.contains(value) ? value : 24;
    return SizedBox(
      width: 120,
      child: DropdownButton<int>(
        value: v,
        items: items,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: context.yucai.surface,
        icon: Icon(LucideIcons.chevronDown,
            color: context.yucai.accent, size: 20),
        onChanged: (h) {
          if (h != null) onChanged(h);
        },
      ),
    );
  }
}

/// 导航型设置行：整行可点 → push 子页（settings 页内第一个导航 tile，
/// 确立「卡片 tile → 子页」范式）。对齐 _PreferenceRow 视觉，但 control
/// 为 chevron right + 整行 onTap。
///
/// [danger] = true 时为危险行(F21 清空数据):icon/label 用 negative
/// 语义色警示(R8 令牌),其余视觉不变。
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tone = danger ? context.yucai.negative : context.yucai.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smBorder,
      child: Row(
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: danger ? context.yucai.negative : context.yucai.fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(color: context.yucai.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight,
              color: context.yucai.muted, size: 20),
        ],
      ),
    );
  }
}

/// F39 「本地快照」卡(guest):快照列表(文件名+大小+修改时间)+
/// 「立即快照」+ 每行「恢复」「删除」。恢复必经确认对话框(覆盖当前全部
/// 数据,不可逆),成功后 DataRefreshNotifier.bump()(照导入存档 hotfix
/// 模式,让 IndexedStack 驻留页重拉缓存)+ toast。数据面全在
/// [LocalSnapshotService],本卡只做编排与确认。
class _LocalSnapshotCard extends StatefulWidget {
  const _LocalSnapshotCard({required this.service});

  final LocalSnapshotService service;

  @override
  State<_LocalSnapshotCard> createState() => _LocalSnapshotCardState();
}

class _LocalSnapshotCardState extends State<_LocalSnapshotCard> {
  /// null = 首次加载中;空列表 = 暂无快照。
  List<({String fileName, int sizeBytes, DateTime modified})>? _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final items = await widget.service.listSnapshots();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _runNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.service.runNow();
      await _reload();
      if (mounted) _toast(context, '已生成本地快照');
    } catch (e) {
      if (mounted) _toast(context, '快照失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复此快照？'),
        content: const Text('恢复将覆盖当前所有数据（账户、交易、资产等），'
            '并回到该快照的状态。此操作不可逆。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('覆盖恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.service.restoreFrom(fileName);
      // Hotfix 模式(同导入存档):整批替换本地库后广播刷新,IndexedStack
      // 驻留页(首页等)重拉缓存,否则展示停留在恢复前的旧数据。
      getIt<DataRefreshNotifier>().bump();
      await _reload();
      if (mounted) _toast(context, '快照已恢复');
    } on ValidationFailure catch (e) {
      if (mounted) _toast(context, e.message);
    } catch (e) {
      if (mounted) _toast(context, '恢复失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除此快照？'),
        content: const Text('删除后无法找回。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.yucai.negative,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.service.deleteSnapshot(fileName);
      await _reload();
      if (mounted) _toast(context, '快照已删除');
    } catch (e) {
      if (mounted) _toast(context, '删除失败：$e');
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  static String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('本地快照',
                        style: TextStyle(
                            color: context.yucai.fg,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '本机数据每日自动快照，保留最近 '
                          '${LocalSnapshotService.keepCount} 份',
                      style: TextStyle(
                          color: context.yucai.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              TextButton.icon(
                onPressed: _busy ? null : _runNow,
                icon: const Icon(LucideIcons.camera, size: 16),
                label: const Text('立即快照'),
              ),
            ],
          ),
          if (items == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text('加载中…',
                  style: TextStyle(color: context.yucai.muted, fontSize: 12)),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text('暂无快照，点击「立即快照」生成第一份',
                  style: TextStyle(color: context.yucai.muted, fontSize: 12)),
            )
          else
            for (final item in items) ...[
              Divider(height: 1, color: context.yucai.border),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.fileName,
                              style: TextStyle(
                                  color: context.yucai.fg, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            '${_fmtSize(item.sizeBytes)} · '
                            '${_fmtTime(item.modified)}',
                            style: TextStyle(
                                color: context.yucai.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed:
                          _busy ? null : () => _restore(item.fileName),
                      child: const Text('恢复'),
                    ),
                    IconButton(
                      tooltip: '删除',
                      onPressed:
                          _busy ? null : () => _delete(item.fileName),
                      icon: Icon(LucideIcons.trash2,
                          size: 18, color: context.yucai.negative),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}
