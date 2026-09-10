import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/binding/presentation/bloc/binding_bloc.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// F19-T1 绑定向导页(spec FR-1/FR-5,design ADR-4):守卫摘要
/// → readyToMerge(合并确认)/ readyToUpload(上传确认)→ 批进度 → 结果。
/// 空/非空仅文案区分,内部同走合并 push 链(ADR-1);R8 语义令牌。
class BindingPage extends StatelessWidget {
  const BindingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      appBar: AppBar(
        backgroundColor: context.yucai.surface,
        title: const Text('绑定账号并同步'),
      ),
      body: BlocConsumer<BindingBloc, BindingState>(
        listener: (context, state) {
          if (state.status == BindingStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('同步完成，已切换为在线模式')),
            );
          }
        },
        builder: (context, state) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _body(context, state),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, BindingState state) {
    switch (state.status) {
      case BindingStatus.guarding:
      case BindingStatus.idle:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text('正在检查账号状态…'),
          ],
        );
      case BindingStatus.readyToMerge:
        return _mergeCard(context, state);
      case BindingStatus.readyToUpload:
        return _uploadCard(context, state);
      case BindingStatus.uploading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(state.progress == null
                ? '正在上传本地数据…'
                : '第 ${state.progress!.batchIndex}/${state.progress!.totalBatches} 批'
                    '·已上行 ${state.progress!.uploadedChanges} 条'),
          ],
        );
      case BindingStatus.success:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle, size: 48, color: Colors.green),
            const SizedBox(height: AppSpacing.md),
            Text('同步完成（上行 ${state.uploadedEntities} 条'
                '${state.conflictCount > 0 ? '·冲突 ${state.conflictCount} 项' : ''}）',
                textAlign: TextAlign.center),
            if (state.conflictCount > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                  '有 ${state.conflictCount} 项内容与服务端不同，已进入冲突面板，可稍后在同步状态中裁决。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.yucai.muted)),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('完成'),
            ),
          ],
        );
      case BindingStatus.failed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: AppSpacing.md),
            Text(
                '上传失败：${state.failureMessage ?? '网络错误'}\n'
                '本地数据未受影响，${state.canResume ? '已上传部分保留，可续传。' : '可重新检查账号状态。'}',
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () =>
                  context.read<BindingBloc>().add(BindingRetryRequested()),
              child: Text(state.canResume ? '重试续传' : '重新检查'),
            ),
          ],
        );
    }
  }

  /// readyToMerge 卡(服务端已有数据,FR-1):摘要 + 合并语义说明 + 确认链。
  Widget _mergeCard(BuildContext context, BindingState state) {
    final summary = state.serverSummary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.cloud_sync, size: 48, color: context.yucai.accent),
        const SizedBox(height: AppSpacing.md),
        Text(
          '该账号已有服务端数据：'
          '账户 ${summary?.accountCount ?? 0} / 交易 ${summary?.transactionCount ?? 0} / '
          '持仓 ${summary?.holdingCount ?? 0}。\n\n'
          '可将本地数据与服务端合并：新增项自动追加；同 id 且内容不同的项会进入'
          '冲突面板，由你裁决保留哪一份。合并完成后两端数据一致（并集）。',
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => _confirmMerge(context),
          child: const Text('合并上传'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }

  /// readyToUpload 卡(服务端为空,ADR-1):「上传」文案 —— 内部与合并同链,
  /// 空账号下合并 = 纯上传,语义等价。
  Widget _uploadCard(BuildContext context, BindingState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.cloud_upload, size: 48, color: context.yucai.accent),
        const SizedBox(height: AppSpacing.md),
        const Text(
          '将本地数据上传到该账号？\n\n'
          '此账号当前为空。本地全部数据（账户/交易/资产等）将上传到服务端，'
          '完成后即完成绑定并切换为在线模式；本地数据保留。',
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => _confirmUpload(context),
          child: const Text('上传'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('暂不绑定'),
        ),
      ],
    );
  }

  /// 合并确认 dialog(FR-5):强调不可自动撤销 + 建议先本地备份(纯文案提示,
  /// 不跳转);确认 → [BindingMergeConfirmed],取消关闭。
  Future<void> _confirmMerge(BuildContext context) async {
    final bloc = context.read<BindingBloc>();
    final summary =
        bloc.state.serverSummary ?? const BindingServerSummary();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('合并上传到该账号？'),
        content: Text(
          '服务端已有数据（账户 ${summary.accountCount} / 交易 '
          '${summary.transactionCount} / 持仓 ${summary.holdingCount}）。\n\n'
          '本地数据将与之合并：新增项追加，同 id 且内容不同的项进入冲突面板'
          '待你裁决。\n\n'
          '此操作不可自动撤销，建议先在「设置 → 备份与恢复」完成一次本地备份。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认合并上传'),
          ),
        ],
      ),
    );
    if (confirmed == true) bloc.add(BindingMergeConfirmed());
  }

  /// 上传确认 dialog(空账号,简化沿用):确认 → [BindingUploadConfirmed]。
  Future<void> _confirmUpload(BuildContext context) async {
    final bloc = context.read<BindingBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('上传到该账号？'),
        content: const Text(
          '本地全部数据（账户/交易/资产等）将上传到该账号。'
          '完成后即绑定并切换为在线模式；本地数据保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认上传'),
          ),
        ],
      ),
    );
    if (confirmed == true) bloc.add(BindingUploadConfirmed());
  }
}
