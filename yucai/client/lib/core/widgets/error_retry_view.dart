// F63 FR-1:错误态重试共享组件(蓝本=transactions_page _ErrorView /
// budget_list _errorState,审计 ANTI⑧ 抽共享)。九处纯文案错误态的统一
// 替换件;compact 供 home 面板等内嵌场景(小尺寸图标+单行布局)。
//
// 语义:展示错误文案 + 重试钮(onRetry 必填 —— 无重试动作的纯文案错误态
// 正是本组件要消灭的 ANTI);不承载空态(空/错分治,见审计 F 维)。
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';

class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    super.key,
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  /// 错误文案(如「加载失败」;原因句由调用方拼入)。
  final String message;

  /// 重试动作(重新触发加载)。必填 —— 错误态必须可恢复(规范 F)。
  final VoidCallback onRetry;

  /// 紧凑形态:面板内嵌(小图标+单行)。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(LucideIcons.circleAlert, size: 16, color: t.negative),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: TextStyle(fontSize: 12.5, color: t.muted)),
            ),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.rotateCcw, size: 14),
              label: const Text('重试', style: TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleAlert, size: 36, color: t.negative),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: t.muted)),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.rotateCcw, size: 16),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
