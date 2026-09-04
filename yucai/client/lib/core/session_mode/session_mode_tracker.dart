import 'package:yucai_client/core/connectivity/connectivity_gateway.dart';

/// F10 FR-1 / design ADR-1:三态数据路由。
///
/// 双源 repo(8 个 *_repository_impl)每次读写调用按此枚举分叉,
/// 替换 R6 的单布尔 `_useLocal => isGuest`:
enum DataRoute {
  /// 游客态(未登录 / 跳过登录 / 登出):全部读写走本地 drift,
  /// 与 R6 guest 语义逐位一致(在线路径行为不变硬约束)。
  guestLocal,

  /// 绑定态 + 在线:远端 gRPC 权威(写成功后 fire-and-forget 镜像刷新,
  /// 与 R6 行为逐位一致);写远端遇 NetworkFailure 时由 FR-1b 降级兜底。
  boundRemote,

  /// 绑定态 + 离线(connectivity 掉线,或 OfflineAuthenticated 离线冷启动
  /// FR-2):读写走本地镜像;写落库置 pending(T2 落地),回网由 T3 上行。
  boundOfflineLocal,
}

/// Session-mode source of truth for the dual-source seam (R6 ADR-2).
///
/// Repositories (data layer) must not import the presentation-layer
/// AuthBloc, so the guest/session flag lives here in core: AuthBloc drives
/// it from its `onChange`, data-layer consumers read it per call.
///
/// F10 T1 扩展:单布尔 isGuest 升级为三态路由(见 [DataRoute])——
/// 新增 authOffline(OfflineAuthenticated 离线冷启动旗标)与
/// online(ConnectivityGateway 快照)。
class SessionModeTracker {
  /// 接线决策(tracker 自订阅):构造期快照 `gateway.current` 并订阅
  /// `gateway.online` 增量流。DI 下二者均为 lazySingleton 且 gateway 先注册
  /// —— tracker 首次被解析(AuthBloc 启动期即触发)时按需 resolve gateway,
  /// 无时序问题;构造期快照覆盖「gateway 先被 UI 解析、冷启动已离线」的
  /// 场景,之后的翻转全部走流订阅。不注入 gateway(单测)时 online 恒为
  /// 乐观 true —— 与 ConnectivityGateway 插件失败的现状语义一致,测试
  /// 可直接改字段驱动离线路由。订阅随 app 生命周期存活,无需 dispose。
  SessionModeTracker([ConnectivityGateway? connectivity])
      : online = connectivity?.current ?? true {
    // 订阅随 app 生命周期存活(app 级单例,无需保留引用 / dispose)。
    connectivity?.online.listen((v) => online = v);
  }

  /// Optimistic default BEFORE AppStarted resolves: guest (local) is the
  /// safe side — it matches the no-credentials path and never blocks reads.
  bool isGuest = true;

  /// F10 FR-2:绑定 + 离线冷启动(AppStarted 有凭证但 profile RPC
  /// NetworkFailure → OfflineAuthenticated)时 AuthBloc 置 true —— 数据
  /// 路由落 [DataRoute.boundOfflineLocal](本地镜像读写),修复旧版
  /// 「注释宣称本地读、实际全远端」的潜伏 bug。Authenticated / Guest
  /// 置回 false。
  bool authOffline = false;

  /// ConnectivityGateway 的在线快照(初值乐观 true,流事件更新)。
  /// 公开可写仅为测试驱动离线路由;生产路径由构造订阅维护。
  bool online;

  /// F10 FR-1:三态路由解析(每次读写调用现算,design LLD)。
  /// guest 短路 → guestLocal;绑定且(断网或离线冷启动)→
  /// boundOfflineLocal;否则 boundRemote。
  DataRoute resolveDataRoute() {
    if (isGuest) return DataRoute.guestLocal;
    if (!online || authOffline) return DataRoute.boundOfflineLocal;
    return DataRoute.boundRemote;
  }
}
