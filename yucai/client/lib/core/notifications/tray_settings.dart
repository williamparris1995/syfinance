import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// 窗口关闭按钮行为(F22 FR-2):
/// - hide:关闭=隐藏到托盘(默认,R7 起的原行为);
/// - exit:关闭=退出程序。
enum TrayCloseBehavior { hide, exit }

/// 托盘到期扫描间隔(F22 FR-5,可配):
/// minutes15 / minutes30(默认)/ minutes60,[TrayScanInterval.minutes]
/// 供 Timer.periodic 直接消费。
enum TrayScanInterval {
  minutes15(15),
  minutes30(30),
  minutes60(60);

  const TrayScanInterval(this.minutes);

  /// 间隔分钟数。
  final int minutes;
}

/// 托盘/关闭行为用户偏好(F22),持久化到 OS keychain
/// (镜像 [ThemeSettings] 的 flutter_secure_storage + ValueNotifier 模式)。
///
/// 读路径:关闭按钮等**热路径同步读内存值** —— [load] 在 bootstrap
/// (runApp 前)调用一次后,内存值即持久化真值;此后读不再碰 storage,
/// 只有 set* 写入才落 secure_storage。未存储/非法值回落默认:
/// hide / minutes30 / false / true(第四项=F25 托盘金额默认显示)。
///
/// 响应式:四个 listenable([closeBehaviorListenable] 等)供设置页
/// SegmentedButton 实时高亮与 controller 按新间隔重臂 Timer /
/// 托盘金额开关即时重设菜单。
///
/// 注入的 [_storage] 缝隙供单测 mock secure-storage 后端(见
/// ThemeSettings 测试范式)。
@LazySingleton()
class TraySettings {
  TraySettings(this._storage);

  final FlutterSecureStorage _storage;

  static const _kCloseBehavior = 'tray_close_behavior';
  static const _kScanInterval = 'tray_scan_interval';
  static const _kFirstClosePrompted = 'tray_first_close_prompted';
  static const _kShowTrayAmounts = 'tray_show_amounts';

  final ValueNotifier<TrayCloseBehavior> _closeBehavior =
      ValueNotifier<TrayCloseBehavior>(TrayCloseBehavior.hide);
  final ValueNotifier<TrayScanInterval> _scanInterval =
      ValueNotifier<TrayScanInterval>(TrayScanInterval.minutes30);
  final ValueNotifier<bool> _firstClosePrompted = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _showTrayAmounts = ValueNotifier<bool>(true);
  bool _loaded = false;

  /// 当前关闭行为(同步)。[load] 完成前为 hide。
  TrayCloseBehavior get closeBehavior => _closeBehavior.value;

  /// 关闭行为 listenable;设置页实时刷新用。
  ValueListenable<TrayCloseBehavior> get closeBehaviorListenable =>
      _closeBehavior;

  /// 当前扫描间隔(同步)。[load] 完成前为 minutes30。
  TrayScanInterval get scanInterval => _scanInterval.value;

  /// 扫描间隔 listenable;controller 据此重臂 Timer.periodic。
  ValueListenable<TrayScanInterval> get scanIntervalListenable => _scanInterval;

  /// 是否已弹过首次关闭提示(每安装一次,FR-3)。
  bool get firstClosePrompted => _firstClosePrompted.value;

  /// 首次提示标记 listenable。
  ValueListenable<bool> get firstClosePromptedListenable => _firstClosePrompted;

  /// 托盘菜单是否显示金额(F25 FR-3,默认显示 —— 右键才展开暴露面小,
  /// spec grill「隐私默认值=显示」)。隐藏时数据头两行变「金额已隐藏」。
  bool get showTrayAmounts => _showTrayAmounts.value;

  /// 托盘金额开关 listenable;controller 据此即时重设托盘菜单。
  ValueListenable<bool> get showTrayAmountsListenable => _showTrayAmounts;

  /// 读取持久化的四项偏好。幂等;bootstrap 调用一次。
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    _closeBehavior.value =
        _decodeCloseBehavior(await _storage.read(key: _kCloseBehavior));
    _scanInterval.value =
        _decodeScanInterval(await _storage.read(key: _kScanInterval));
    _firstClosePrompted.value =
        _decodeBool(await _storage.read(key: _kFirstClosePrompted));
    _showTrayAmounts.value =
        _decodeShowAmounts(await _storage.read(key: _kShowTrayAmounts));
  }

  /// 持久化并立即应用关闭行为。
  Future<void> setCloseBehavior(TrayCloseBehavior behavior) async {
    await _storage.write(
      key: _kCloseBehavior,
      value: _encodeCloseBehavior(behavior),
    );
    _closeBehavior.value = behavior;
  }

  /// 持久化并立即应用扫描间隔。
  Future<void> setScanInterval(TrayScanInterval interval) async {
    await _storage.write(
      key: _kScanInterval,
      value: _encodeScanInterval(interval),
    );
    _scanInterval.value = interval;
  }

  /// 持久化并立即应用首次关闭提示标记。
  Future<void> setFirstClosePrompted(bool prompted) async {
    await _storage.write(
      key: _kFirstClosePrompted,
      value: prompted ? 'true' : 'false',
    );
    _firstClosePrompted.value = prompted;
  }

  /// 持久化并立即应用托盘金额开关(F25 FR-3;镜像既有 set* 范式)。
  Future<void> setShowTrayAmounts(bool show) async {
    await _storage.write(
      key: _kShowTrayAmounts,
      value: show ? 'true' : 'false',
    );
    _showTrayAmounts.value = show;
  }

  static String _encodeCloseBehavior(TrayCloseBehavior behavior) =>
      switch (behavior) {
        TrayCloseBehavior.hide => 'hide',
        TrayCloseBehavior.exit => 'exit',
      };

  static TrayCloseBehavior _decodeCloseBehavior(String? raw) =>
      switch (raw) {
        'hide' => TrayCloseBehavior.hide,
        'exit' => TrayCloseBehavior.exit,
        _ => TrayCloseBehavior.hide, // null/空/未知值回落隐藏到托盘
      };

  static String _encodeScanInterval(TrayScanInterval interval) =>
      interval.minutes.toString();

  static TrayScanInterval _decodeScanInterval(String? raw) {
    final minutes = int.tryParse(raw ?? '');
    return switch (minutes) {
      15 => TrayScanInterval.minutes15,
      30 => TrayScanInterval.minutes30,
      60 => TrayScanInterval.minutes60,
      _ => TrayScanInterval.minutes30, // null/空/未知值回落 30 分钟
    };
  }

  static bool _decodeBool(String? raw) =>
      switch (raw) {
        'true' => true,
        _ => false, // null/空/未知值回落未提示
      };

  /// F25:默认值方向与其余三字段相反 —— 未存储/未知回落**显示**(true),
  /// 只有显式 'false' 才隐藏(隐私默认显示,spec grill 定案)。
  static bool _decodeShowAmounts(String? raw) =>
      switch (raw) {
        'false' => false,
        _ => true,
      };
}
