// F42 T2 — shared feedback model root. Zero imports beyond the pb stub.
// Class-level dependency flow is one-directional:
//   feedback_kind ← feedback_launcher ← feedback_submit_service ← dialog
// (fix round 1 note: feedback_launcher.dart and feedback_submit_service.dart
// reference each other's TYPES at the file level — launcher hosts the
// submitServiceFactory seam, service falls back to the F41 ambient seams.
// That two-file mutual reference is legal Dart and confined to this feature
// directory; the model/behavior chain above stays acyclic.)
// [FeedbackDiagnostics] moved here from feedback_launcher.dart (F42 T2);
// the launcher re-exports it so existing F41 imports keep working.
import 'package:yucai_client/proto/feedback/v1/feedback.pbenum.dart' as pb;

/// Whitelisted diagnostic header for feedback submissions: exactly the four
/// fields below in fixed order. Financial data (balances, amounts, asset
/// figures) must never appear here — [bodyLines] is the only body source.
class FeedbackDiagnostics {
  const FeedbackDiagnostics({
    required this.appVersion,
    required this.platform,
    required this.accountMode,
    required this.themeMode,
  });

  final String appVersion;

  /// `Platform.operatingSystem` (e.g. 'windows').
  final String platform;

  /// '绑定' (bound session) or 'guest'.
  final String accountMode;

  /// '亮' or '暗' (resolved brightness actually being rendered).
  final String themeMode;

  /// The four body lines in whitelist order: 版本 / 平台 / 账户 / 主题.
  List<String> bodyLines() => [
        '版本:$appVersion',
        '平台:$platform',
        '账户:$accountMode',
        '主题:$themeMode',
      ];
}

/// The three feedback categories (prototype v4: 问题/建议/其他).
enum FeedbackKind {
  /// 问题 — something broken (circle-alert card in the prototype).
  issue('问题', pb.FeedbackType.ISSUE),

  /// 建议 — an improvement idea (lightbulb card).
  idea('建议', pb.FeedbackType.IDEA),

  /// 其他 — anything else (message-circle card).
  other('其他', pb.FeedbackType.OTHER);

  const FeedbackKind(this.label, this.pbValue);

  /// Chinese label shown in the type cards and used in the mail subject
  /// (「御财反馈-问题」); prototype v4 copy, do not reword.
  final String label;

  /// Wire enum for SubmitFeedbackRequest.type (pb stub used, not modified).
  final pb.FeedbackType pbValue;
}

/// A filled-in feedback form (the dialog's output, the service's input).
/// Immutable on purpose: the dialog's 重试 action must be able to re-send
/// the exact same values after a failure.
class FeedbackForm {
  const FeedbackForm({
    required this.kind,
    required this.body,
    this.contact = '',
    required this.diagnostics,
  });

  final FeedbackKind kind;

  /// User-written description; validated 1..1000 runes upstream (dialog).
  final String body;

  /// Optional contact (≤100 runes), empty string when not provided.
  final String contact;

  /// Read-only diagnostic header data (F41 4-field whitelist).
  final FeedbackDiagnostics diagnostics;
}
