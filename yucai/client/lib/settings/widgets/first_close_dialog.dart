import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 首次关闭对话框的用户抉择(F22 FR-3)。
/// - [minimize]:隐藏窗口到系统托盘(主按钮);
/// - [quit]:退出程序(次按钮);
/// - null(barrier 点击 / Esc / 右上 ×):取消本次关闭,窗口保留。
enum FirstCloseDialogResult { minimize, quit }

/// 弹出「首次关闭一次性对话框」(dialog-first-close,原型
/// prototype/v1/ui/first-close-dialog.html)。
///
/// 纯展示 + 返回:**不写任何设置标记** —— 「已提示过首关」的持久化由
/// 消费方(T4 TrayController)在结果非 null 时负责,本组件无副作用、
/// 无业务依赖。barrierDismissible=true:barrier 点击 / Esc = 取消(pop null)。
Future<FirstCloseDialogResult?> showFirstCloseDialog(BuildContext context) {
  final t = context.yucai;
  return showDialog<FirstCloseDialogResult>(
    context: context,
    barrierDismissible: true, // barrier 点击 = 取消(不消耗一次性标记)
    // 原型页级令牌 --scrim rgba(2,6,16,.55):**双主题恒定暗遮罩** —— 亮色下
    // 若由 bg 派生会得近白纱罩、模态感弱(review R1);YucaiTheme 无 scrim
    // 变体,以 black@55% 表达(禁裸 hex 不含 Colors.* 语义常量)。
    // F27 FR-1③ scrim 豁免(恒定暗遮罩,保原值)。
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (dctx) => Dialog(
      // v2 口径:暗=描边分层无阴影,亮=无边框卡+柔阴影(照 AppTheme.cardTheme)。
      backgroundColor: t.surface,
      elevation: Theme.of(dctx).brightness == Brightness.dark ? 0 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgBorder, // 16(dialog-first-close 规格)
        side: BorderSide(color: t.border),
      ),
      child: SizedBox(
        width: 400, // 卡宽 400(min(400px,92vw) 的桌面态)
        child: _FirstCloseDialogCard(t: t),
      ),
    ),
  );
}

/// 卡内布局:右上 × / 标题 / 正文 / 右对齐 actions(次→主)/ kbd 提示。
class _FirstCloseDialogCard extends StatelessWidget {
  const _FirstCloseDialogCard({required this.t});

  final YucaiTheme t;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          // 原型 padding:20 20 16。
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 右侧让位给右上 ×(26px 热区),标题不被遮。
              Padding(
                padding: const EdgeInsets.only(right: 34),
                child: Text(
                  '御财将最小化到系统托盘',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.fg,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '关闭窗口后,御财仍会在系统托盘继续运行(到期提醒与自动记账不受影响)。可随时点击托盘图标恢复窗口。',
                style: TextStyle(fontSize: 13, color: t.muted, height: 1.6),
              ),
              const SizedBox(height: 18), // actions margin-top
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 次按钮:muted 文字钮,hover → negative(destructive,
                  // 照原型 .btn-secondary:hover --neg)。
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(FirstCloseDialogResult.quit),
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.hovered)
                            ? t.negative
                            : t.muted,
                      ),
                      textStyle: const WidgetStatePropertyAll(TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    child: const Text('退出程序'),
                  ),
                  const SizedBox(width: 10),
                  // 主按钮:accent 主语义 + minimize 图标(btn-primary);
                  // autofocus 承载原型「默认」语义:Enter = 最小化(review R2
                  // 实证:焦点在卡内按钮时 Esc 的 DismissIntent 仍冒泡至
                  // route 级 Actions(routes.dart _DismissModalAction)→
                  // maybePop,即 autofocus 不吞 Esc,取消路径不受影响)。
                  FilledButton.icon(
                    autofocus: true,
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(FirstCloseDialogResult.minimize),
                    icon: const Icon(LucideIcons.minimize2, size: 14),
                    label: const Text('最小化到托盘'),
                    style: FilledButton.styleFrom(
                      backgroundColor: t.accent,
                      foregroundColor: t.onAccent,
                      minimumSize: const Size(64, 34), // 原型 34px 高
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Esc 或 × = 取消本次关闭 · 此提示仅出现一次',
                  style: TextStyle(fontSize: 11, color: t.muted),
                ),
              ),
            ],
          ),
        ),
        // 右上 ×:取消本次关闭(= pop null,不消耗一次性标记);
        // hover → 图标 fg + surfaceAlt 轨道底(照原型 .x:hover --fg/--seg-track,
        // review R3;非 hover 态回落 null 保持 Material 默认)。
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(LucideIcons.x, size: 14),
            tooltip: '取消关闭',
            visualDensity: VisualDensity.compact,
            splashRadius: 13,
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.hovered)
                    ? t.fg
                    : t.muted,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.hovered) ? t.surfaceAlt : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
