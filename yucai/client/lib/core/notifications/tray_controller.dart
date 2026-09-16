import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yucai_client/core/notifications/app_exit_port.dart'
    show AppExitFn;
import 'package:yucai_client/core/notifications/app_updater.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/tray_settings.dart';

/// 首关对话框抉择的 core 侧表示(F22 FR-3)。core → settings 方向禁止
/// import,故 settings 模块 first_close_dialog 的 FirstCloseDialogResult
/// 由组合根(notifications_bootstrap)映射为本枚举;null 保持「取消」
/// 语义(窗口保留,不消耗一次性标记)。
enum FirstCloseChoice { minimize, quit }

/// 托盘 setup 缝(照 DataResetController.DbFilesFn/WriteBackupFn 先例):
/// 生产默认 = 图标落盘 + 真实 tray_manager 调用(含 dart:io 文件 I/O 与
/// path_provider FFI);测试注入假实现 —— fakeAsync 下真实 I/O 事件不
/// 会完成、且避免向真机 AppData 写文件。返回值 = [TrayController.trayReady]。
typedef TraySetupFn = Future<bool> Function();

/// F25 ADR-1:托盘数据头值对象(cents)。core/notifications 不 import
/// transaction 模块(仓跨模块约束),组合根(notifications_bootstrap)
/// 把本地 DS summary 的 day+month 两次调用映射为本对象注入。
class TrayHeadData {
  const TrayHeadData({
    required this.todayIncomeCents,
    required this.todayExpenseCents,
    required this.monthBalanceCents,
  });

  /// 今日收入合计(分,本地口径)。
  final int todayIncomeCents;

  /// 今日支出合计(分,本地口径)。
  final int todayExpenseCents;

  /// 本月结余 = 本月收入 - 本月支出(分,本地口径)。
  final int monthBalanceCents;
}

/// F25 ADR-1:摘要提供者函数注入 port(与 exitFn/traySetup 缝同构,最小面)。
/// null 返回 = 查询失败/未注入 → 数据头「--」占位(NFR-1 fail-safe)。
typedef TrayHeadProvider = Future<TrayHeadData?> Function();

/// 托盘常驻控制器(FR-3):托盘菜单 + 关闭决策树 + 变更即扫/周期扫描调度
/// + 启动首扫。
///
/// F22 注入化改造(NFR-3:无注入时行为等价改造前):
/// - [settings] null → 内部默认值(hide / 已提示视同 → 直接隐藏);
/// - [changeTriggers] 空 → 无变更即扫触发(FR-4 只在 bootstrap 注入);
/// - [closePrompt]/[contextResolver] null → 无对话框缝,兜底隐藏;
/// - [exitFn] 进程退出缝(照 DataResetController.ExitFn 先例),测试
///   注入假实现避免真杀测试进程。
///
/// 生命周期(user-acceptance 修复):start() 逐步骤容错 —— 任一步失败
/// (典型:打包版资产非磁盘文件)只降级托盘;[trayReady]=false 时窗口
/// 关闭改为**真退出**(绝不隐藏到不存在的托盘里变僵尸)。
class TrayController with TrayListener, WindowListener {
  TrayController({
    required this.scan,
    this.autoRecord,
    this.settings,
    this.changeTriggers = const [],
    this.closePrompt,
    this.contextResolver,
    this.traySetup,
    this.headProvider,
    this.versionProvider,
    this.newTransactionNav,
    AppExitFn? exitFn,
  }) : _exit = exitFn ?? _defaultExit;

  /// 扫描入口(注入到期提醒扫描)。
  final Future<ScanResult> Function() scan;

  /// autoRecord 调度入口(R7-C;null=未接线则跳过)。
  final Future<void> Function()? autoRecord;

  /// 托盘/关闭行为用户偏好(F22 FR-2/3/5;null = 内部默认值,等价改造前)。
  final TraySettings? settings;

  /// 变更即扫触发面(F22 FR-4/ADR-1):drift 表 watch 流;空 = 无变更触发。
  final List<Stream<void>> changeTriggers;

  /// 首关对话框注入缝(F22 FR-3/ADR-4);null = 不弹(走兜底隐藏)。
  final Future<FirstCloseChoice?> Function(BuildContext context)? closePrompt;

  /// 对话框 context 获取缝(F22 ADR-4:GoRouter 根 navigatorKey);
  /// null / 取不到 context = 兜底隐藏(fail-open)。
  final BuildContext? Function()? contextResolver;

  /// 托盘 setup 缝(见 [TraySetupFn]);null = 生产默认实现(图标落盘 +
  /// 托盘注册,任一步失败降级 false)。
  final TraySetupFn? traySetup;

  /// 托盘数据头摘要提供者(F25 FR-1/ADR-1);null = 未注入 → 数据头
  /// 恒「--」占位(等价改造前无数据头能力,其余菜单项不受影响)。
  final TrayHeadProvider? headProvider;

  /// 版本提供者(F24 FR-6/ADR-5;组合根注入 PackageInfo.version,即
  /// pubspec 单源派生 NFR-2);null = 未注入 → 版本项降级纯「御财」。
  /// 只在首次菜单刷新时取一次并缓存(见 [_refreshMenu])。
  final Future<String?> Function()? versionProvider;

  /// 「记一笔」导航闭包(F25 FR-2/ADR-4,组合根注入 GoRouter push);
  /// null / 抛错 = 降级仅 show/focus 窗口(不炸,NFR-1)。
  final Future<void> Function()? newTransactionNav;

  final AppExitFn _exit;

  static Never _defaultExit() => exit(0);

  /// 托盘是否成功就绪。窗口关闭行为据此分支:
  /// true → 走关闭决策树;false → 真退出。
  bool trayReady = false;

  Timer? _tick;
  Timer? _firstScan;
  Timer? _debounce;
  final List<StreamSubscription<void>> _changeSubs = [];

  /// 关闭动作进行中守卫:④ 首关对话框 await 期间重入忽略;② exit 路径
  /// 快速双 X 并发双 stop/destroy 忽略(进程随即 exit,守卫不复位 ——
  /// 防御性,当前生产 stop 后必 exit 不可达)。
  bool _closeInProgress = false;

  static const _kShow = 'show';
  static const _kQuit = 'quit';
  static const _kNewTxn = 'new_transaction';
  static const _kHeadToday = 'head_today';
  static const _kHeadMonth = 'head_month';
  static const _kHead = 'head';
  static const _kCheckUpdate = 'check_update';
  static const _kVersion = 'version';

  // F24 FR-6:版本号取一次缓存(运行期不变);未取/失败/未注入 → null
  // → 版本项降级纯「御财」(NFR-1 附属降级)。
  String? _version;
  bool _versionLoaded = false;

  // settings null 容错:所有读走内部 getter(null-safe 默认)。
  TrayCloseBehavior get _closeBehavior =>
      settings?.closeBehavior ?? TrayCloseBehavior.hide;

  /// F25 FR-3:托盘金额开关;settings 未注入 → 默认显示(等价新装机默认)。
  bool get _showTrayAmounts => settings?.showTrayAmounts ?? true;

  /// settings 未注入时视同已提示:等价改造前「点 X 直接隐藏」,且无
  /// 持久化面时弹一次无法标记,宁可不再弹。
  bool get _firstClosePrompted => settings?.firstClosePrompted ?? true;

  TrayScanInterval get _scanInterval =>
      settings?.scanInterval ?? TrayScanInterval.minutes30;

  /// 标记「已提示」;写失败吞掉(fail-open:最坏下次关闭再弹一次,
  /// 不影响本次关闭动作的执行)。
  Future<void> _markFirstClosePrompted() async {
    try {
      await settings?.setFirstClosePrompted(true);
    } catch (_) {}
  }

  Future<void> start() async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true); // 关闭 → onWindowClose 分支
    trayReady = await (traySetup ?? _defaultTraySetup)();
    // F25 LLD 首启顺序:托盘注册成功后即刷首次数据头(先注册后填充;
    // 摘要查询异步,不阻塞托盘就绪;失败静默保持占位菜单)。
    unawaited(_refreshMenu());

    _armScanTick();
    // 间隔变更即时重臂(FR-5):cancel 旧 Timer + 按新间隔重建。
    settings?.scanIntervalListenable.addListener(_rearmScanTick);
    // F25 FR-3/ADR-2④:隐私开关切换即时重设菜单(切换即时生效)。
    settings?.showTrayAmountsListenable.addListener(_refreshMenu);
    // 变更即扫(FR-4/ADR-1):每条 watch 流订阅 → 防抖 500ms 合流。
    // onError 吞错(评审 R1):drift watch 吐错(DB 损坏等)若不接管 →
    // 未捕获 zone 异常 + 订阅静默死亡。取舍:该流后续失效,但周期 tick
    // 与启动首扫兜底(幂等重扫,变更即扫重启前缺额由 tick 补齐)。
    for (final trigger in changeTriggers) {
      _changeSubs.add(trigger.listen(
        (_) => _scheduleDebouncedScan(),
        onError: (Object _) {},
      ));
    }
    // 启动延迟首扫(design ADR-5:不阻塞 runApp 首帧)。
    _firstScan = Timer(const Duration(seconds: 10), _scanAndMark);
  }

  Future<void> stop() async {
    _tick?.cancel();
    _firstScan?.cancel();
    _debounce?.cancel();
    for (final sub in _changeSubs) {
      sub.cancel();
    }
    _changeSubs.clear();
    settings?.scanIntervalListenable.removeListener(_rearmScanTick);
    settings?.showTrayAmountsListenable.removeListener(_refreshMenu);
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    if (trayReady) await trayManager.destroy();
    // 复位就绪旗标(评审 R2,防御性):stop 后再 onWindowClose 不得
    // hide 进已销毁托盘 —— 当前生产路径 stop 后必 exit,此行为不可达。
    trayReady = false;
  }

  /// 退出进程(F22 FR-1):清理托盘后 exit(0)。供 AppExitPort 与
  /// 关闭决策树的 quit 路径复用。
  Future<void> quit() async {
    await stop();
    _exit();
  }

  void _armScanTick() {
    _tick?.cancel();
    // 无条件重扫(FR-5:撤跨日门槛 —— 该门槛是工作量优化非通知策略,
    // scanner 按条目按档当日幂等,重扫安全)。
    _tick = Timer.periodic(
      Duration(minutes: _scanInterval.minutes),
      (_) => _scanAndMark(),
    );
  }

  void _rearmScanTick() => _armScanTick();

  void _scheduleDebouncedScan() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _scanAndMark);
  }

  Future<void> _scanAndMark() async {
    // autoRecord 与到期提醒独立容错:一方失败不影响另一方(R7-C FR-3)。
    final auto = autoRecord;
    if (auto != null) {
      try {
        await auto();
      } catch (_) {}
    }
    try {
      await scan();
    } catch (_) {
      // 扫描失败不冒泡(Timer 回调里会变未捕获异步异常);幂等重扫安全,
      // 下次 tick/watch 触发自然重试(FR-5 无条件重扫取代跨日门槛)。
    }
    // F25 ADR-2①②:变更即扫防抖路径与周期 tick 的尾部统一刷托盘菜单
    // (同一入口 → 先扫后刷;重设失败静默保持旧菜单,NFR-1)。
    unawaited(_refreshMenu());
  }

  /// F25 ADR-2:托盘菜单重设入口 —— provider 查数 → 组菜单 →
  /// `setContextMenu`。三触发合一(watch 防抖尾 / tick 尾 / 窗口 show
  /// 事件)+ 开关 listenable,全部汇入本方法;查询失败 → 「--」占位,
  /// 重设失败 → 保持旧菜单(附属功能降级不炸)。
  Future<void> _refreshMenu() async {
    if (!trayReady) return; // 托盘未就绪/已停:重设无处落,直接跳过。
    TrayHeadData? head;
    final provider = headProvider;
    if (provider != null) {
      try {
        head = await provider();
      } catch (_) {
        head = null; // NFR-1:摘要查询失败 → 「--」占位,不阻断其余菜单项
      }
    }
    // F24 FR-6/ADR-5:版本异步取一次并入本刷新数据流(刷新触发复用 F25
    // 三触发合一机制);查询失败 → null 缓存,label 降级「御财」不炸。
    if (!_versionLoaded) {
      _versionLoaded = true;
      final versionProvider = this.versionProvider;
      if (versionProvider != null) {
        try {
          _version = await versionProvider();
        } catch (_) {
          _version = null; // NFR-1:版本查询失败不阻断菜单其余项
        }
      }
    }
    try {
      await trayManager.setContextMenu(Menu(
          items: buildContextMenu(
              head: head,
              showAmounts: _showTrayAmounts,
              version: _version)));
    } catch (_) {
      // NFR-1:菜单重设失败 → 菜单保持旧内容(fail-safe 降级)。
    }
  }

  // ---- window_manager:关闭决策树(spec FR-2/3 + NFR-1,design LLD) ----
  @override
  void onWindowClose() async {
    // ① 托盘不可用:隐藏=用户无法找回的僵尸窗口,直接真退出(NFR-1,
    //    历史用户验收修复优先于一切偏好)。_exit 返回 Never,后续分支
    //    静态不可达。
    if (!trayReady) {
      _exit();
    } else if (_closeBehavior == TrayCloseBehavior.exit) {
      // ② 用户偏好「关闭=退出」(FR-2):与设置页退出按钮同路径。守卫
      // 复用 _closeInProgress:快速双 X 不得并发双 stop/destroy(评审 R3,
      // 防御性 —— 进程随即 exit,守卫不复位)。
      if (_closeInProgress) return;
      _closeInProgress = true;
      await quit();
    } else if (_firstClosePrompted) {
      // ③ 已弹过首次关闭提示(FR-3):直接隐藏,此后点 X 不再打扰。
      await windowManager.hide();
    } else {
      // ④ 首次关闭:一次性对话框。重入守卫:await 对话框期间再点 X 忽略。
      if (_closeInProgress) return;
      final prompt = closePrompt;
      final context = contextResolver?.call();
      if (prompt == null || context == null) {
        // 兜底:fail-open 到既有行为(隐藏到托盘),不因缺 context/对话框缝
        // 阻塞关闭(ADR-4:极端时序如路由切换中取不到 context)。
        await windowManager.hide();
        return;
      }
      _closeInProgress = true;
      try {
        final choice = await prompt(context);
        if (choice == FirstCloseChoice.minimize) {
          await _markFirstClosePrompted();
          await windowManager.hide();
        } else if (choice == FirstCloseChoice.quit) {
          await _markFirstClosePrompted();
          await quit();
        }
        // null(×/Esc 取消):窗口保留,不 hide 不标记 —— 未完成的选择
        // 不算被告知过,不消耗一次性标记(FR-3)。
      } finally {
        _closeInProgress = false;
      }
    }
  }

  // F25 ADR-2③:窗口 show 事件(native WM_SHOWWINDOW 经 onWindowEvent
  // 全事件回调透传 —— 本版 WindowListener 无专用 onWindowShow 钩子)
  // → 重设菜单;从托盘回窗口的用户最可能刚在别处记了账/跨了日。
  @override
  void onWindowEvent(String eventName) {
    if (eventName == 'show') unawaited(_refreshMenu());
  }

  // ---- tray_manager ----
  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case _kNewTxn:
        // F25 FR-2:显示并聚焦窗口,再跳转记账表单;导航闭包缺失/抛错
        // (典型:极端时序取不到 context)→ 降级仅 show/focus,不炸。
        await windowManager.show();
        await windowManager.focus();
        final nav = newTransactionNav;
        if (nav != null) {
          try {
            await nav();
          } catch (_) {}
        }
      case _kCheckUpdate:
        // F24 FR-5/6:手动检查 → auto_updater 引擎检查 UI(WinSparkle,
        // 英文弹窗决策在案)。引擎抛错(bootstrap 降级后未初始化/平台
        // 缺失)→ 吞掉降级:手动检查项恒可点、恒不炸(NFR-1)。
        try {
          await AppUpdater.checkForUpdates();
        } catch (_) {}
      case _kShow:
        await windowManager.show();
        await windowManager.focus();
      case _kQuit:
        // 真正退出:dispose 托盘后结束进程(spec NFR:不留僵尸)。
        await quit();
    }
  }

  @override
  void onTrayIconRightMouseDown() async {
    // 验收热修(2026-09-16 D-5):tray_manager 0.5.3 原生侧 WM_RBUTTONUP 只发
    // 事件**不弹菜单**(windows/tray_manager_plugin.cpp:204 仅 InvokeMethod),
    // 必须由 Dart 侧主动弹——自 R7 起右键从未真正工作,真机验收暴露。
    if (!trayReady) return;
    try {
      await trayManager.popUpContextMenu();
    } catch (_) {
      // 弹出失败静默(附属功能降级;图标/事件不受影响)。
    }
  }

  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// 托盘菜单项(FR-6 + F25 + F24):数据头区(FR-1,动态禁用项)→ 分隔线 →
  /// 检查更新(F24 FR-5,enabled)→ 御财 vX.Y.Z(F24 FR-6,disabled)→
  /// 记一笔(FR-2)→ 显示御财 → 退出。「立即检查」已撤 —— 变更即扫
  /// (FR-4)+ 可配间隔(FR-5)治本取代手动逃生口,_kCheck 与其 case 退役。
  ///
  /// F25 参数化(design LLD):
  /// - [head] 非空且 [showAmounts] → 今日/本月两行 disabled;
  /// - [showAmounts]=false → 「金额已隐藏」单行(不出两行空壳);
  /// - [head]=null(查询失败/未注入)→ 「--」单行占位,不阻断其余项;
  /// - [version](F24,PackageInfo 派生)非空 → 「御财 vX.Y.Z」,否则
  ///   降级纯「御财」(见 [formatVersionLabel])。
  @visibleForTesting
  static List<MenuItem> buildContextMenu({
    TrayHeadData? head,
    bool showAmounts = true,
    String? version,
  }) {
    final headItems = !showAmounts
        ? [MenuItem(key: _kHead, label: '金额已隐藏', disabled: true)]
        : (head == null
            ? [MenuItem(key: _kHead, label: '--', disabled: true)]
            : [
                MenuItem(
                  key: _kHeadToday,
                  label:
                      '今日 收 ${formatTrayAmount(head.todayIncomeCents)} · 支 ${formatTrayAmount(head.todayExpenseCents)}',
                  disabled: true,
                ),
                MenuItem(
                  key: _kHeadMonth,
                  label: '本月结余 ${formatTrayBalance(head.monthBalanceCents)}',
                  disabled: true,
                ),
              ]);
    return [
      ...headItems,
      MenuItem.separator(),
      MenuItem(key: _kCheckUpdate, label: '检查更新'),
      MenuItem(
          key: _kVersion, label: formatVersionLabel(version), disabled: true),
      MenuItem(key: _kNewTxn, label: '记一笔'),
      MenuItem(key: _kShow, label: '显示御财'),
      MenuItem(key: _kQuit, label: '退出'),
    ];
  }

  /// F24 FR-6:「御财 vX.Y.Z」label 组装(X.Y.Z 取 PackageInfo.version,
  /// 即 pubspec 单源派生 NFR-2);版本未知(未注入/查询失败/空)→ 降级
  /// 纯「御财」,不阻断菜单(NFR-1)。
  @visibleForTesting
  static String formatVersionLabel(String? version) =>
      (version == null || version.isEmpty) ? '御财' : '御财 v$version';

  /// F25 金额格式(今日收/支):¥ + 千分位整元(分截断;菜单纯文本项
  /// 紧凑优先,对齐 GoldAmount showFen:false 表单先例的分组算法)。
  @visibleForTesting
  static String formatTrayAmount(int cents) {
    final neg = cents < 0;
    final yuan = cents.abs() ~/ 100;
    final s = yuan.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    // 符号在货币符号前(design LLD:-¥123 / +¥123)。
    return '${neg ? '-' : ''}¥$buf';
  }

  /// F25 结余格式(design LLD):正 +¥ / 负 -¥ / 零 ¥0(不带符号)。
  @visibleForTesting
  static String formatTrayBalance(int cents) =>
      cents == 0 ? formatTrayAmount(0) : '${cents > 0 ? '+' : ''}${formatTrayAmount(cents)}';

  /// 托盘图标是否需要(重)落盘:目标不存在或内容与资产不一致(升级换图标)。
  /// 抽为可测纯判定(F23 P1);逐字节比对,图标仅数百字节成本可忽略。
  @visibleForTesting
  static Future<bool> trayIconNeedsWrite(
      File target, List<int> assetBytes) async {
    if (!await target.exists()) return true;
    final existing = await target.readAsBytes();
    if (existing.length != assetBytes.length) return true;
    for (var i = 0; i < existing.length; i++) {
      if (existing[i] != assetBytes[i]) return true;
    }
    return false;
  }

  /// 生产默认托盘 setup([TraySetupFn] 的缺省实例实现):图标落盘 + 菜单/
  /// tooltip/图标注册。任一步失败(典型:打包版资产非磁盘文件)只降级
  /// 返回 false —— 窗口关闭回退真退出,绝不隐藏成僵尸(user-acceptance
  /// 修复:setPreventClose 已生效时失败必须可见地降级)。
  Future<bool> _defaultTraySetup() async {
    try {
      trayManager.addListener(this);
      // 打包版内 'assets/...' 不是磁盘文件 → 先落盘再设图标
      // (user-acceptance 修复:release 直接 setIcon 相对路径会抛错,
      //  此时 setPreventClose 已生效 → 隐形窗口僵尸)。
      final dir = await getApplicationSupportDirectory();
      final iconFile = File('${dir.path}${Platform.pathSeparator}tray_icon.ico');
      final data = await rootBundle.load('assets/tray_icon.ico');
      final assetBytes = data.buffer.asUint8List();
      // 内容不一致即覆盖(F23 P1):仅判存在会让升级用户永远滞留旧图标。
      if (await trayIconNeedsWrite(iconFile, assetBytes)) {
        await iconFile.writeAsBytes(assetBytes, flush: true);
      }
      await trayManager.setIcon(iconFile.path);
      await trayManager.setToolTip('御财');
      await trayManager.setContextMenu(Menu(items: buildContextMenu()));
      return true;
    } catch (_) {
      // 托盘失败:窗口关闭回退真退出,绝不隐藏成僵尸。
      return false;
    }
  }
}
