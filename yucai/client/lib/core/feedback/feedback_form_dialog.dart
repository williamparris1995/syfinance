// F42 T2 — in-app feedback form dialog (prototype v4 is the visual/
// interaction/copy source of truth: ui/feedback-form.html + design-system.md
// Flutter mapping). AlertDialog shape per design LLD: title + content +
// actions 取消/提交反馈.
//
// State machine: idle → submitting (button spinner, disabled) →
//   uploaded → SnackBar 「已提交,感谢反馈」 → dialog closes;
//   mailed   → toast (mail client / clipboard fallback) → dialog closes;
//   failed / rateLimited → dialog STAYS OPEN with content preserved;
//     SnackBar carries the double action 重试 (re-send the same form) /
//     改用邮件 (force the offline mailto path);
//   emailMissing → F41 configuration toast, dialog stays open.
//
// Zero bare colors (R8): every color comes from context.yucai. User-visible
// copy is Chinese per the prototype; comments/logs stay English.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/feedback/feedback_kind.dart';
import 'package:yucai_client/core/feedback/feedback_submit_service.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// Body length limits (runes) — server-validated identically; the counter
/// mirrors the prototype's n/1000 display.
const _maxBodyRunes = 1000;
const _maxContactRunes = 100;

class FeedbackFormDialog extends StatefulWidget {
  const FeedbackFormDialog({
    super.key,
    required this.diagnostics,
    this.submitService,
  });

  /// Read-only diagnostic header data (F41 4-field whitelist), collected by
  /// the entry point BEFORE the dialog opens (context-free afterwards).
  final FeedbackDiagnostics diagnostics;

  /// Constructor seam for tests; production passes the entry-built service
  /// (ambient DI deps).
  final FeedbackSubmitService? submitService;

  @override
  State<FeedbackFormDialog> createState() => _FeedbackFormDialogState();
}

class _FeedbackFormDialogState extends State<FeedbackFormDialog> {
  FeedbackKind? _kind;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _contactCtrl;
  bool _submitting = false;

  /// Inline status strip text (prototype .status-area semantics). While the
  /// dialog is open, SnackBars render beneath its modal barrier and their
  /// actions are untappable on this Flutter (3.44 also removed
  /// SnackBar.actions), so failure/info prompts live INSIDE the dialog —
  /// exactly the prototype's .fail bar with 重试/改用邮件 mini buttons.
  String? _failMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _bodyCtrl = TextEditingController();
    _contactCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  int get _bodyRunes => _bodyCtrl.text.runes.length;
  int get _contactRunes => _contactCtrl.text.runes.length;

  bool get _canSubmit =>
      !_submitting &&
      _kind != null &&
      _bodyRunes > 0 &&
      _bodyRunes <= _maxBodyRunes &&
      _contactRunes <= _maxContactRunes;

  FeedbackForm _buildForm() => FeedbackForm(
        kind: _kind!,
        body: _bodyCtrl.text,
        contact: _contactCtrl.text.trim(),
        diagnostics: widget.diagnostics,
      );

  Future<void> _submit({bool forceMail = false}) async {
    if (!_canSubmit) return;
    // Context handles are captured pre-await (use_build_context_synchronously).
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final form = _buildForm();

    setState(() {
      _submitting = true;
      _failMessage = null;
      _infoMessage = null;
    });
    final outcome = await (widget.submitService ?? FeedbackSubmitService())
        .submit(form, forceMail: forceMail);
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (outcome.variant) {
      case SubmitOutcomeVariant.uploaded:
        // Pop FIRST, then toast: the snackbar would sit under the dialog's
        // modal barrier while it is open.
        navigator.pop();
        messenger.showSnackBar(
            const SnackBar(content: Text('已提交,感谢反馈')));
      case SubmitOutcomeVariant.mailed:
        navigator.pop();
        messenger.showSnackBar(SnackBar(
          content: Text(outcome.copiedToClipboard
              ? '未检测到邮件客户端,反馈内容已复制,可粘贴到网页邮箱发送'
              : '已唤起邮件客户端(离线通道)'),
        ));
      case SubmitOutcomeVariant.emailMissing:
        // Nothing could be sent (offline + no FEEDBACK_EMAIL): keep the
        // dialog open so the user can copy the text manually (F41 copy).
        setState(() => _infoMessage = '反馈邮箱未配置(需 --dart-define=FEEDBACK_EMAIL)');
      case SubmitOutcomeVariant.rateLimited:
        setState(() => _failMessage = '提交过于频繁,请稍后再试');
      case SubmitOutcomeVariant.failed:
        setState(() => _failMessage = '上传失败,内容已保留');
    }
  }

  /// Inline failure strip (prototype .fail): message + the double action
  /// 重试 (re-send the original data) / 改用邮件 (offline mailto path). The
  /// dialog stays open so no typed content is lost.
  Widget _buildFailStrip() => Builder(builder: (context) {
        final t = context.yucai;
        return Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: t.negative.withValues(alpha: 0.08),
            border: Border.all(color: t.negative),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.circleX, size: 16, color: t.negative),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_failMessage!)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: t.accent,
                      foregroundColor: t.onAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: _submitting ? null : () => _submit(),
                    child: const Text('重试', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.muted,
                      side: BorderSide(color: t.border, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: _submitting ? null : () => _submit(forceMail: true),
                    child: const Text('改用邮件', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        );
      });

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    final overLimit = _bodyRunes > _maxBodyRunes;
    return AlertDialog(
      title: const Text('意见反馈'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('问题或建议直达开发者;在线直传,离线自动改走邮件',
                  style: TextStyle(fontSize: 12.5, color: t.muted)),
              const _FieldLabel('类型', required: true),
              Row(
                children: [
                  for (final kind in FeedbackKind.values)
                    Expanded(
                      child: _TypeCard(
                        kind: kind,
                        selected: _kind == kind,
                        onTap: () => setState(() => _kind = kind),
                      ),
                    ),
                ],
              ),
              const _FieldLabel('问题描述', required: true),
              _FieldTextField(
                controller: _bodyCtrl,
                hint: '请描述你遇到的问题或建议…',
                maxLines: 6,
                onChanged: (_) => setState(() {}),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    '$_bodyRunes/$_maxBodyRunes',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: overLimit ? t.negative : t.muted,
                    ),
                  ),
                ),
              ),
              const _FieldLabel('联系方式(选填)'),
              _FieldTextField(
                controller: _contactCtrl,
                hint: '邮箱或其他联系方式,便于回复',
                maxLines: 1,
                maxLength: _maxContactRunes,
              ),
              const SizedBox(height: 18),
              _DiagnosticsBox(diagnosticLines: widget.diagnostics.bodyLines()),
              if (_infoMessage != null)
                _StatusInfoStrip(message: _infoMessage!),
              if (_failMessage != null) _buildFailStrip(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text('取消', style: TextStyle(color: t.muted)),
        ),
        FilledButton(
          onPressed: _canSubmit ? () => _submit() : null,
          style: FilledButton.styleFrom(
            backgroundColor: t.accent,
            foregroundColor: t.onAccent,
          ),
          child: _submitting
              ? SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.onAccent,
                  ),
                )
              : const Text('提交反馈'),
        ),
      ],
    );
  }
}

/// Form field label (prototype .f-label): 12.5px semibold, red asterisk for
/// required fields.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text.rich(
        TextSpan(
          text: text,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          children: [
            if (required)
              TextSpan(text: ' *', style: TextStyle(color: t.negative)),
          ],
        ),
      ),
    );
  }
}

/// Shared input look (prototype textarea/.input): surfaceAlt fill + border,
/// accent border on focus.
class _FieldTextField extends StatelessWidget {
  const _FieldTextField({
    required this.controller,
    required this.hint,
    required this.maxLines,
    this.maxLength,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: t.border, width: 1.5),
    );
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      // Hide the built-in n/100 counter (prototype shows none for contact).
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: t.muted),
        filled: true,
        fillColor: t.surfaceAlt,
        counterText: '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: t.accent, width: 1.5),
        ),
      ),
    );
  }
}

/// Type radio card (prototype .radio-card, F33 _RadioCard form): icon +
/// label, selected state = accent border + accentSoft fill (zero new tokens).
class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final FeedbackKind kind;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (kind) {
        FeedbackKind.issue => LucideIcons.circleAlert,
        FeedbackKind.idea => LucideIcons.lightbulb,
        FeedbackKind.other => LucideIcons.messageCircle,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? t.accentSoft : t.surfaceAlt,
          border: Border.all(
            color: selected ? t.accent : t.border,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon,
                size: 22,
                color: selected ? t.accent : t.muted),
            const SizedBox(height: 7),
            Text(
              kind.label,
              style: TextStyle(
                fontSize: 12.5,
                color: selected ? t.accentDeep : t.fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline info strip (prototype .toast-info semantics): non-fatal prompt
/// while the dialog stays open (e.g. FEEDBACK_EMAIL not configured).
class _StatusInfoStrip extends StatelessWidget {
  const _StatusInfoStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.info.withValues(alpha: 0.08),
        border: Border.all(color: t.info),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: 16, color: t.info),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

/// Read-only diagnostics header (prototype .diag): muted info card with the
/// 4 whitelisted lines + privacy caption. Not editable (F41 whitelist frozen).
class _DiagnosticsBox extends StatelessWidget {
  const _DiagnosticsBox({required this.diagnosticLines});

  final List<String> diagnosticLines;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.info, size: 15, color: t.muted),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in diagnosticLines)
                  Text(line,
                      style: TextStyle(fontSize: 12, color: t.muted)),
                const SizedBox(height: 2),
                Text(
                  '随反馈自动附带,便于定位问题;不含任何财务数据',
                  style: TextStyle(fontSize: 11, color: t.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
