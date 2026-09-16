import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// 窗口几何状态值对象(F30 S1):x/y/w/h(logical 坐标,与
/// window_manager getBounds/setBounds 同口径)+ 最大化旗标。
///
/// 编解码即校验(「非法值回落默认」收敛在 [decode] 单点):
/// - null / 空 / 非 json / 非 map / 缺字段 / 类型错 / 非有限值 → null;
/// - w/h 低于 [_minW]×[_minH](400×300)→ null(S2 最小尺寸钳制,
///   语义=钳制到最小值后恢复(保留 x/y;review 修正:丢弃会致小窗口用户
///   「每次启动复位」循环)——出屏回退另行兜底(runner 默认=10,10 左上)。
class WindowState {
  const WindowState({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.maximized,
  });

  /// 最小可恢复尺寸(S2):低于此值钳制到该值(x/y 保留,review 修正语义)。
  static const double _minW = 400;
  static const double _minH = 300;

  final double x;
  final double y;
  final double w;
  final double h;
  final bool maximized;

  /// window_manager 口径的窗口矩形(logical 坐标)。
  Rect get rect => Rect.fromLTWH(x, y, w, h);

  /// json 编码(secure_storage `window_state` 键下的字符串值)。
  String encode() => jsonEncode({
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'maximized': maximized,
      });

  /// 解码 + 全量校验;任何非法输入回落 null(= 默认窗口)。
  static WindowState? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final x = _asFiniteDouble(decoded['x']);
    final y = _asFiniteDouble(decoded['y']);
    final w = _asFiniteDouble(decoded['w']);
    final h = _asFiniteDouble(decoded['h']);
    final maximized = decoded['maximized'];
    if (x == null || y == null || w == null || h == null ||
        maximized is! bool) {
      return null;
    }
    // review(S2 Important):钳制而非丢弃——全仓无窗口级 setMinimumSize,
    // 用户可合法缩到 400×300 以下;丢弃会造成「每次启动复位」循环
    // (几何事件不再触发重存,陈旧小尺寸长期留存)。保留 x/y 只钳尺寸。
    final cw = w >= _minW ? w : _minW;
    final ch = h >= _minH ? h : _minH;
    return WindowState(x: x, y: y, w: cw, h: ch, maximized: maximized);
  }

  static double? _asFiniteDouble(Object? v) =>
      v is num && v.isFinite ? v.toDouble() : null;

  /// S2 出屏检测:bounds 与任一屏幕区域有**正面积**交集即可恢复
  /// (仅边缘相接 = 不可见 → 丢弃)。屏幕列表由调用方注入(控制器
  /// 缝),空列表 fail-safe 回默认。
  bool visibleOnAnyScreen(List<Rect> screens) =>
      screens.any(rect.overlaps);
}

/// 屏幕区域提供者缝(F30 S2):返回 logical 坐标的屏幕矩形列表。
/// 生产默认 [WindowStateController.defaultScreenRanges](screen_retriever
/// 派生,理由见其注释);测试注入固定列表断言出屏回退。
typedef ScreenRangesFn = Future<List<Rect>> Function();

/// F30 窗口状态记忆控制器:启动恢复 + 几何变更防抖落盘。
///
/// 持久化家法 = TraySettings/ThemeSettings 同款 flutter_secure_storage
/// (OS keychain)单键 `window_state` 存 [WindowState.encode] json;
/// 区别于偏好四键的是本控制器带窗口事件副作用,故同时照 TrayController
/// 的 start/stop 监听生命周期范式。
///
/// **保存时机**(S1):onWindowMove / onWindowResize /
/// onWindowEvent(maximize/unmaximize)→ 防抖 500ms 合流落盘(照 F22
/// tray watch 防抖先例)。不依赖关闭路径:F22「关闭=hide 到托盘」与
/// 真 exit 均被覆盖 —— 几何每次变更后 500ms 内即持久化,关闭时无需
/// 再保存。最大化语义:flush 时若窗口处于最大化,只翻旗标**保留既有
/// 常规 bounds**(不拿最大化帧几何覆盖),恢复后 unmaximize 才能回到
/// 用户原尺寸;无既有 bounds(首启即最大化)退而捕获当前几何,宁可
/// 几何粗略也不丢最大化偏好。
///
/// **恢复时机**(S1,排序依据):main.dart waitUntilReadyToShow 回调内
/// 先 setBounds 后(若 maximized)maximize()。次序约束两重:
/// 1. 回调内恢复晚于插件启动副作用 —— window_manager 0.5.2
///    lib/src/window_manager.dart `waitUntilReadyToShow` 源码:
///    `if (await isMaximized()) await unmaximize();` 等副作用全部
///    await 决议**之后**才 `callback()`,故回调里的 maximize() 不会被
///    启动期 unmaximize 覆盖(AppTitleBar.initState P1 暗桩注释所指
///    「F30 恢复最大化须在 isMaximized?unmaximize 副作用决议后恢复」
///    即落位于此回调);
/// 2. setBounds 先于 maximize —— 反序时 setBounds 会把已最大化窗口
///    改回常规几何,最大化态丢失。
///
/// 恢复前置校验(S2,任一不过=丢弃回默认、不 setBounds,走 runner
/// 默认居中):[WindowState.decode] 已滤非法值/过小尺寸;再检保存
/// bounds 与当前屏幕区域交集 —— 显示器已拔时无交集 → 回默认。
///
/// 注入化(照 TrayController traySetup 缝先例):[_storage] mock 自不
/// 待言;[ScreenRangesFn] 缝让出屏检测可离屏单测。手工构造于组合根
/// (main.dart,不进 injectable 图 —— 恢复须早于 configureDependencies
/// 完成,时序上拿不到 getIt 实例;load 以 memo future 兜竞态)。
class WindowStateController with WindowListener {
  WindowStateController(this._storage, {ScreenRangesFn? screenRanges})
      : _screenRanges = screenRanges ?? defaultScreenRanges;

  static const _kWindowState = 'window_state';

  /// 防抖窗口(ms):照 F22 tray watch 防抖 500ms 先例。
  static const _debounceMs = 500;

  final FlutterSecureStorage _storage;
  final ScreenRangesFn _screenRanges;

  WindowState? _state;
  Future<void>? _loadFuture;
  Timer? _debounce;

  /// 生产默认屏幕区域:screen_retriever `getAllDisplays`(logical 全局
  /// 坐标,含多屏负坐标原点)→ Rect(visiblePosition/visibleSize,缺省
  /// 回落 size 全屏)。选型:本 Flutter 版 dart:ui 的 FlutterView/
  /// Display 均不暴露显示器全局位置(仅 physicalSize),而
  /// screen_retriever 本就是 window_manager 0.5.2 的既有传递依赖
  /// (同作者配套,logical 口径与 getBounds 一致),提升直接依赖零新增
  /// 解析。查询失败 → 空列表(fail-safe:交集恒假 → 丢弃恢复回默认,
  /// 宁可不恢复不出僵尸窗口几何)。
  static Future<List<Rect>> defaultScreenRanges() async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      return displays
          .map((d) => Rect.fromLTWH(
                (d.visiblePosition ?? Offset.zero).dx,
                (d.visiblePosition ?? Offset.zero).dy,
                (d.visibleSize ?? d.size).width,
                (d.visibleSize ?? d.size).height,
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 读取持久化状态;memo 化 —— [restore] 与显式 [load] 竞态时同等
  /// 等待同一 future(不重复读)。读失败(keychain 异常)吞掉等价
  /// 「无存储」→ 默认窗口(NFR 附属功能降级)。
  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    String? raw;
    try {
      raw = await _storage.read(key: _kWindowState);
    } catch (_) {
      raw = null;
    }
    _state = WindowState.decode(raw);
  }

  /// 恢复持久化几何(S1)。main.dart waitUntilReadyToShow 回调内调用,
  /// 排序依据见类注释;任何异常静默降级(保持 runner 默认窗口)。
  Future<void> restore() async {
    await load();
    final state = _state;
    if (state == null) return;
    // S2 出屏检测:await 屏幕矩形(注入缝/生产 screen_retriever)。
    if (!state.visibleOnAnyScreen(await _screenRanges())) return;
    try {
      // 先几何后最大化(次序不可倒,见类注释排序依据 2)。
      await windowManager.setBounds(state.rect);
      if (state.maximized) await windowManager.maximize();
    } catch (_) {
      // 附属功能降级:不恢复即回默认,绝不阻断启动回调。
    }
  }

  /// 挂保存监听(组合根接线:main.dart configureDependencies 后)。
  /// 插件单例监听器,进程级生命周期;stop 仅供测试清理防跨测残留
  /// (照 AppTitleBar/TrayController 卸载注释同款约束)。
  void start() {
    windowManager.addListener(this);
  }

  /// 撤监听 + 取消在途防抖(测试用;生产进程存续期不调)。
  void stop() {
    _debounce?.cancel();
    windowManager.removeListener(this);
  }

  // ---- 保存触发面(S1):几何/最大化变更 → 防抖合流落盘 ----

  @override
  void onWindowMove() => _scheduleSave();

  @override
  void onWindowResize() => _scheduleSave();

  @override
  void onWindowEvent(String eventName) {
    // 只认最大化态翻转;move/resize 走上方专用钩子(此处即便再来一次
    // 也会被防抖合流,不产生重复落盘)。
    if (eventName == kWindowEventMaximize ||
        eventName == kWindowEventUnmaximize) {
      _scheduleSave();
    }
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), _flushSave);
  }

  Future<void> _flushSave() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (!maximized) {
        // 非最大化:捕获现行几何为常规 bounds。
        await _persist(await windowManager.getBounds(), false);
        return;
      }
      // 最大化:保留既有常规 bounds 只翻旗标(见类注释「最大化语义」);
      // 无既有 bounds(首启即最大化)退而捕获当前几何,不丢最大化偏好。
      final prev = _state;
      final bounds = prev?.rect ?? await windowManager.getBounds();
      await _persist(bounds, true);
    } catch (_) {
      // 附属功能降级:本次不落盘,下次事件自然重试(幂等全量覆写)。
    }
  }

  Future<void> _persist(Rect bounds, bool maximized) async {
    final state = WindowState(
      x: bounds.left,
      y: bounds.top,
      w: bounds.width,
      h: bounds.height,
      maximized: maximized,
    );
    await _storage.write(key: _kWindowState, value: state.encode());
    _state = state; // 内存真值先行(后续 maximize flush 的 bounds 保留源)
  }
}
