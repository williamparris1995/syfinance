import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/binding/presentation/bloc/binding_bloc.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// Three-step binding wizard (R6 feature G): guard result → upload confirm
/// (explicit one-way overwrite wording) → progress/result.
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
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _body(context, state),
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
      case BindingStatus.blocked:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 48, color: context.yucai.muted),
            const SizedBox(height: AppSpacing.md),
            Text(state.blockedReason ?? '账号非空，已阻止上传',
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      case BindingStatus.readyToUpload:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.cloud_upload, size: 48, color: context.yucai.accent),
            const SizedBox(height: AppSpacing.md),
            const Text(
              '将本地数据上传到该账号？\n\n上传为单向覆盖：本地全部数据（账户/交易/资产等）会替换到服务端该账号。此账号当前为空，上传后即完成绑定并切换为在线模式；本地数据保留。',
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => context
                  .read<BindingBloc>()
                  .add(BindingUploadConfirmed()),
              child: const Text('确认上传'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('暂不绑定'),
            ),
          ],
        );
      case BindingStatus.uploading:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text('正在上传本地数据…'),
          ],
        );
      case BindingStatus.success:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 48, color: Colors.green),
            const SizedBox(height: AppSpacing.md),
            Text('同步完成（本地 ${state.uploadedEntities} 个账户，'
                '服务端校验 ${state.verifiedRemoteCount} 个）'),
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
            Text('上传失败：${state.failureMessage ?? '网络错误'}\n本地数据未受影响，可重试。',
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () =>
                  context.read<BindingBloc>().add(BindingRetryRequested()),
              child: const Text('重试'),
            ),
          ],
        );
    }
  }
}
