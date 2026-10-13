import 'package:flutter/material.dart';

import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/form_leave_gate.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// 表单页脏态离开守卫(F58 ADR-3,FR-7):包住表单页内容即生效。
///
/// 两条离开路径在此汇合,共用同一确认对话框:
/// - veto 通道:向 getIt 的 [FormLeaveGate] 注册 veto —— 面包屑 page 级
///   onTap(go 非 pop,PopScope 拦不到)经 `gate.mayLeave()` 问询至此;
/// - PopScope 兜底:canPop 动态 = 非 dirty(宿主 setState 重建本守卫时随
///   `isDirty()` 重估);dirty 拦下 pop,确认后才放行。
///
/// [isDirty] 取 `bool Function()`(选简):脏态判定即时求值,宿主表单
/// setState 重建即刷新 canPop。dispose 必须 unregister —— 页面销毁后残留
/// veto 会用死 context 拦截后续导航(FR-2/FR-7 残留类风险)。
///
/// F59 T4:guarded getIt(照 DetailTitleSync 先例)—— stripped 测试 harness
/// 未注册 gate 时守卫退化为「只走 PopScope 兜底、不注册 veto」,页面可
/// 挂载不崩;生产 injection 1k 恒注册,veto 通道恒在。
///
/// 确认框文案中文,照 debt_delete_confirm 的 AlertDialog 先例;本组件
/// 不打日志(零 log 串,无 CJK 入日志风险)。
class FormLeaveGuard extends StatefulWidget {
  const FormLeaveGuard({
    super.key,
    required this.isDirty,
    required this.child,
  });

  /// 脏态判定:用户已编辑未保存 = true(需要离开确认)。
  final bool Function() isDirty;

  final Widget child;

  @override
  State<FormLeaveGuard> createState() => _FormLeaveGuardState();
}

class _FormLeaveGuardState extends State<FormLeaveGuard> {
  late final LeaveVeto _veto;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    // 同一闭包注册/注销:unregister 按引用移除,匿名重建会失配。
    _veto = _onVeto;
    if (getIt.isRegistered<FormLeaveGate>()) {
      getIt<FormLeaveGate>().register(_veto);
    }
  }

  @override
  void dispose() {
    if (getIt.isRegistered<FormLeaveGate>()) {
      getIt<FormLeaveGate>().unregister(_veto);
    }
    super.dispose();
  }

  /// veto 问询(gate.mayLeave 路径):非 dirty 直接放行,dirty 走确认框。
  Future<bool> _onVeto() async {
    if (!widget.isDirty()) return true;
    return _confirmLeave();
  }

  /// 「放弃修改/继续编辑」确认:true = 放弃并离开,false = 留下。
  /// 并发问询(如连按两次返回)由 [_confirming] 合并为一次弹框,重入按
  /// 留下处理(保守:待首问询有结论再走)。
  Future<bool> _confirmLeave() async {
    if (!mounted || _confirming) return false;
    _confirming = true;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('未保存的修改'),
          content: SizedBox(
            width: 420,
            child: Text(
              '当前页面有未保存的修改，离开后将丢失。',
              style: TextStyle(
                fontSize: 13.5,
                color: context.yucai.muted,
                height: 1.6,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('继续编辑'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.yucai.negative,
              ),
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('放弃修改'),
            ),
          ],
        ),
      );
      return ok ?? false;
    } finally {
      _confirming = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop 动态:非 dirty 直放(系统返回零摩擦);dirty 拦下走确认。
      // 宿主表单 setState 重建本守卫时随 isDirty() 重估。
      canPop: !widget.isDirty(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // canPop=false 拦下的 pop:确认后直弹 —— Navigator 在 await 前捕获,
        // pop 不走 canPop 判定,不会被自身再拦;await 后 mounted 复核,防
        // 问询期间程序化导航已改栈时弹掉新栈顶。
        final navigator = Navigator.of(context);
        final leave = await _confirmLeave();
        if (leave && mounted) navigator.pop();
      },
      child: widget.child,
    );
  }
}
