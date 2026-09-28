/// F46 T2「分析师解读」小节(FR-4/ADR-5;prototype v9 financial-report
/// .html .ch7-llm)。
///
/// 挂诊断章节尾:三态(loading/done/error)+「由 {model} 生成」chip(仅
/// done)+ 免责脚注恒显 + 重新解读;done 文本 [SelectableText](ADR-5)。
/// 纯展示:状态由页面旁挂 [_AnalystState] 驱动(照 F45 导出 page-handler
/// 哲学不新 bloc),重新解读/重试共用 [onRegenerate] 缝。
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 解读小节旁挂状态(页面 State 持有):idle = 小节自隐(入口 = 页头
/// 「AI 解读」按钮);期变更/重新生成回 idle(ADR-1)。
class AnalystNoteState {
  const AnalystNoteState._(this._status, this.text, this.model, this.message);

  const AnalystNoteState.idle() : this._(AnalystNoteStatus.idle, null, null, null);
  const AnalystNoteState.loading()
      : this._(AnalystNoteStatus.loading, null, null, null);
  const AnalystNoteState.done(String text, String model)
      : this._(AnalystNoteStatus.done, text, model, null);
  const AnalystNoteState.error(String message)
      : this._(AnalystNoteStatus.error, null, null, message);

  final AnalystNoteStatus _status;

  /// done 态解读文本。
  final String? text;

  /// done 态生成模型名(chip「由 {model} 生成」)。
  final String? model;

  /// error 态已脱敏消息(NarrationFailure.message)。
  final String? message;

  bool get isIdle => _status == AnalystNoteStatus.idle;
}

enum AnalystNoteStatus { idle, loading, done, error }

/// 分析师解读小节(state = 旁挂三态;onRegenerate = 重新解读/重试共用缝)。
class AnalystNote extends StatelessWidget {
  const AnalystNote({super.key, required this.state, required this.onRegenerate});

  final AnalystNoteState state;

  /// 重新解读(done 态脚注钮)/ 重试(error 态)→ 页面重触发 narrate。
  final VoidCallback onRegenerate;

  /// 免责脚注(v9 逐字;三态恒显)。
  static const _footNote =
      '以上解读由 AI 基于脱敏汇总数据生成,仅供参考,不构成投资建议;数字以报告为准。';

  @override
  Widget build(BuildContext context) {
    if (state.isIdle) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // v9 .llm-head:标题左、chip 右两端对齐(评审 R3)。
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('分析师解读',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.yucai.fg)),
            if (state.model != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: context.yucai.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '由 ${state.model} 生成',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.yucai.accentDeep,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.yucai.surface,
            borderRadius: AppRadius.lgBorder,
            border: Border.all(color: context.yucai.border),
          ),
          child: _body(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                _footNote,
                style: TextStyle(
                    fontSize: 11.5, height: 1.6, color: context.yucai.muted),
              ),
            ),
            TextButton(
              key: const ValueKey('analystRegenerateButton'),
              onPressed: onRegenerate,
              style: TextButton.styleFrom(
                foregroundColor: context.yucai.accent,
                textStyle: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('重新解读'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final text = state.text;
    final message = state.message;
    if (text != null) {
      // ADR-5:done 文本 SelectableText(可复制;响应不可信 → 免责脚注恒显)。
      return SelectableText(
        text,
        style: TextStyle(fontSize: 13, height: 1.8, color: context.yucai.fg),
      );
    }
    if (message != null) {
      return Row(
        children: [
          Icon(LucideIcons.circleAlert,
              size: 16, color: context.yucai.negative),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('解读失败:$message',
                style:
                    TextStyle(fontSize: 13, color: context.yucai.negative)),
          ),
          TextButton(
            key: const ValueKey('analystRetryButton'),
            onPressed: onRegenerate,
            style: TextButton.styleFrom(
              foregroundColor: context.yucai.accent,
              textStyle: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('重试'),
          ),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: context.yucai.accent),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('解读生成中…',
            style: TextStyle(fontSize: 13, color: context.yucai.muted)),
      ],
    );
  }
}
