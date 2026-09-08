import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/binding/presentation/bloc/sync_coordinator_bloc.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// F12 T2(spec FR-1,design ADR-1/ADR-4):顶栏同步状态指示,挂载于 app_shell
/// `_TopBar` 的 [OfflineBadge] 旁(离线/同步语义并置)。四态:
/// - `syncing` → spinner +「同步中」;
/// - `failed` → negative 色调 chip(原因截断),点击 = 手动重试
///   ([SyncRetryRequested];防重入由 bloc 的 in-flight 幂等兜底,ADR-4);
/// - 其余态 `pendingCount > 0` → muted chip「待同步 N」(无交互);
/// - clean(非 syncing/failed 且 N==0)→ 隐藏(在线零感知)。
///
/// F18-T3(spec FR-5,design ADR-5)插入第五态(四态语义零破坏,仅扩展
/// 其余态分支):`conflictCount > 0`(且非 syncing/failed)→ warn(amber)
/// chip「冲突 N」,onTap 进冲突面板 `/settings/conflicts`。渲染优先级:
/// **syncing > failed > 冲突 > 待同步 > 隐藏** —— 冲突比待同步计数更强
/// (需要用户裁决的显式信号),但仍让位于 syncing/failed(在途/失败是
/// 此刻唯一可行动信号,与 T1 消化观察 (b) 同一论证);冲突计数仍由
/// `state.conflictCount` 权威携带,面板解决后经 ListConflicts 重取收敛。
///
/// 渲染优先级(T1 review 观察 (b) 的消化):syncing/failed 优先于计数文本 ——
/// failed 且 N>0 时**只显失败态,计数不叠加**:失败原因+重试入口是此刻唯一
/// 可行动信号,叠加数字徒增噪音;计数仍由 `state.pendingCount` 权威携带,
/// 重试成功后自然收敛为 clean / 待同步。
///
/// 仅绑定态渲染(spec「guest 隐藏」):经 [SessionModeTracker] 判定而非 bloc
/// 态 —— guest 期 bloc 恒 idle 且计数恒 0,badge 无渲染语义;用 tracker 可在
/// guest 下完全不进 BlocBuilder(guest 链路零依赖)。tracker 取值照库内
/// widget 取 app 级单例的惯例([OfflineBadge]/IntegrityBanner):build 内
/// guarded getIt —— 生产恒注册,无 DI 图的测试挂载静默不渲染。guest↔bound
/// 翻转随 AuthBloc 发射驱动 AppShell 重建(tracker 由 AuthBloc 处理器同步
/// 先置位)而自然重新判定,无需 tracker 自带通知流。
///
/// bloc 实例由 AppShell 顶层 `BlocProvider.value` 提供 —— 仅绑定会话注入
/// (guest 会话不 resolve 不构造,恢复 T1「构造即 bound」前提;这是 F10
/// 注册 lazySingleton 以来的首个生产 resolve 点,构造期补扫随首个绑定帧
/// 发生,详见 app_shell.dart 挂载注释);此处用标准 BlocBuilder 经 context
/// 定位。
///
/// 样式对齐 [OfflineBadge] 规格:字号 11 / 圆角 999 / padding(8,3)/
/// 左距 AppSpacing.md;颜色一律 `context.yucai` 语义令牌(R8,禁 v1 硬编码)。
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final tracker = getIt.isRegistered<SessionModeTracker>()
        ? getIt<SessionModeTracker>()
        : null;
    if (tracker == null || tracker.isGuest) return const SizedBox.shrink();

    return BlocBuilder<SyncCoordinatorBloc, SyncCoordinatorState>(
      builder: (context, state) {
        // 优先级钉死(F18-T3 插入冲突分支):syncing > failed > 冲突 >
        // 待同步计数;全空 → 隐藏。
        final Widget? chip = switch (state.status) {
          SyncStatus.syncing => _syncingChip(context),
          SyncStatus.failed => _failedChip(context, state.failureReason),
          _ => state.conflictCount > 0
              ? _conflictChip(context, state.conflictCount)
              : state.pendingCount > 0
                  ? _pendingChip(context, state.pendingCount)
                  : null,
        };
        if (chip == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: chip,
        );
      },
    );
  }

  /// F18-T3:冲突 N(非 syncing/failed 且 conflictCount>0)—— warn(amber)
  /// chip,onTap 进冲突面板(唯一带导航的计数态:冲突需要用户裁决)。
  Widget _conflictChip(BuildContext context, int count) {
    final t = context.yucai;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/settings/conflicts'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: t.warn.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.triangleAlert, size: 13, color: t.warn),
            const SizedBox(width: 4),
            Text('冲突 $count', style: TextStyle(fontSize: 11, color: t.warn)),
          ]),
        ),
      ),
    );
  }

  /// syncing:spinner(小)+「同步中」。muted 色调与 OfflineBadge 同视觉语言。
  Widget _syncingChip(BuildContext context) {
    final t = context.yucai;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.muted.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: t.muted,
          ),
        ),
        const SizedBox(width: 4),
        Text('同步中', style: TextStyle(fontSize: 11, color: t.muted)),
      ]),
    );
  }

  /// 待同步 N(其余态且 N>0):muted chip,无 onTap(非可行动信号)。
  Widget _pendingChip(BuildContext context, int count) {
    final t = context.yucai;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.muted.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.cloudUpload, size: 13, color: t.muted),
        const SizedBox(width: 4),
        Text('待同步 $count', style: TextStyle(fontSize: 11, color: t.muted)),
      ]),
    );
  }

  /// failed:negative chip + 原因截断 + onTap 手动重试(FR-4)。
  /// 原因空缺时兜底文案「同步失败」(不拼接空原因)。
  Widget _failedChip(BuildContext context, String? reason) {
    final t = context.yucai;
    final label = (reason == null || reason.isEmpty) ? '同步失败' : '同步失败:$reason';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            context.read<SyncCoordinatorBloc>().add(SyncRetryRequested()),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: t.negative.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          // 原因截断:maxWidth 约束 + ellipsis,长原因不挤压 topbar 布局。
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.refreshCw, size: 13, color: t.negative),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: t.negative),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
