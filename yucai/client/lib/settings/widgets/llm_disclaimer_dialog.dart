import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 弹出「启用 AI 分析师」免责对话框(F46 FR-1;prototype v9 settings.html
/// #llmDlg,照 F22 [showFirstCloseDialog] 范式)。
///
/// 纯展示 + 返回:**不写任何设置标记** —— disclaimerAck + enabled 的持久化
/// 由消费方(设置卡)在返回 true 时负责,本组件无副作用、无业务依赖。
/// barrierDismissible=true:barrier 点击 / Esc = 取消(false,开关回弹)。
Future<bool> showLlmDisclaimerDialog(BuildContext context) async {
  final t = context.yucai;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: true, // barrier 点击 = 取消(不启用)
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (dctx) => Dialog(
          backgroundColor: t.surface,
          elevation: Theme.of(dctx).brightness == Brightness.dark ? 0 : 4,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lgBorder, // 16(dialog 规格)
            side: BorderSide(color: t.border),
          ),
          child: SizedBox(
            width: 400, // 卡宽 400(first_close_dialog 同款桌面态)
            child: _DisclaimerCard(t: t),
          ),
        ),
      ) ??
      false; // barrier/Esc 等 pop(null) 路径统一折叠为 false。
}

/// 卡内布局:标题 / 四行免责(v9 逐字,圆点行)/ 右对齐 [取消][我已知悉并启用]。
class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard({required this.t});

  final YucaiTheme t;

  /// v9 #llmDlg 四行免责文案逐字(标点宽度原样:ASCII 括号/分号/逗号)。
  static const _lines = [
    '数据将以脱敏汇总形式(类别构成与金额区间)发送至你配置的服务端点;',
    '不会发送账户名、交易明细或身份信息;',
    'AI 输出仅供参考,不构成投资建议;',
    'API Key 仅保存在本机。',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      // v9 .dlg padding:22 24。
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '启用 AI 分析师',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: t.fg,
            ),
          ),
          const SizedBox(height: 12),
          for (final line in _lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // v9 .d-line::before:accent 圆点。
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 8, right: 9),
                    decoration:
                        BoxDecoration(color: t.accent, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(
                          fontSize: 12.5, color: t.muted, height: 1.7),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16), // v9 .dlg-btns margin-top
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: ButtonStyle(
                  foregroundColor: WidgetStatePropertyAll(t.muted),
                  textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                child: const Text('取消'),
              ),
              const SizedBox(width: 10),
              FilledButton(
                autofocus: true, // Enter = 确认(first_close_dialog 主钮语义)
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.onAccent,
                  minimumSize: const Size(64, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: const Text('我已知悉并启用'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
