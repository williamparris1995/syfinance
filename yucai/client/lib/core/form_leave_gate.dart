/// 脏表单离开 veto 签名(F58 ADR-3):返回 true = 允许离开,false = 拦下。
typedef LeaveVeto = Future<bool> Function();

/// 离开问询 port(F58 ADR-3,FR-7):表单页脏态(已编辑未保存)导航离开的
/// 统一确认闸门。
///
/// 两条离开路径共用本闸门:
/// 1. 面包屑 page 级 onTap(go 非 pop,PopScope 拦不到)—— 先
///    `await mayLeave()` 再 `context.go(rootPath)`;
/// 2. 系统返回/pop —— FormLeaveGuard 的 PopScope 兜底。
/// 表单页侧由 FormLeaveGuard widget 注册 veto;本类只管注册表与问询,
/// 不含 UI(面包屑在 shell,确认框在 guard,各自就位)。
///
/// getIt lazySingleton 注册(照 DataRefreshNotifier 先例)。
class FormLeaveGate {
  final List<LeaveVeto> _vetoes = [];

  /// 注册一个离开 veto(FormLeaveGuard 于 initState 调用)。
  void register(LeaveVeto veto) => _vetoes.add(veto);

  /// 注销 veto(FormLeaveGuard 于 dispose 调用,防残留注册拦死后续导航)。
  void unregister(LeaveVeto veto) => _vetoes.remove(veto);

  /// 逐个问询已注册 veto:任一 false 即整体 false(短路,后续不再问);
  /// 全 true / 无注册 → true(干净态零摩擦)。
  ///
  /// 迭代快照:容忍 veto 内部副作用改注册表(unregister 自身等)。
  Future<bool> mayLeave() async {
    for (final veto in List<LeaveVeto>.of(_vetoes)) {
      if (!await veto()) return false;
    }
    return true;
  }
}
