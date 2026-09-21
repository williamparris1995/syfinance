// F41 in-app feedback entry (T1): mailto-based feedback with a pure,
// testable core plus the shared UI entry point (T2).
//
// Recipient injection: the address never lives in source; it is compiled
// in via `--dart-define=FEEDBACK_EMAIL=...` (wired in release.yml). When
// the define is absent [feedbackEmail] is '' and [launchFeedback] returns
// [FeedbackLaunchResult.emailMissing] without building a URI or touching
// any seam.
//
// Launch semantics are a three-state result:
//  - launched: the OS opened a mail client for the mailto URI.
//  - emailMissing: FEEDBACK_EMAIL was not compiled in; nothing launched,
//    the UI surfaces a configuration hint.
//  - launchFailedCopied: no mail client took the URI; recipient + subject
//    + diagnostic header were copied to the clipboard so the user can
//    paste them into a webmail client.
//
// Seams: [LaunchUrlFn] / [ClipboardWriter] are injectable function seams
// (mirroring auth's UrlLauncherFn + defaultUrlLauncher precedent). The
// optional `email` parameter defaults to the compile-time [feedbackEmail]
// and exists so tests can exercise the recipient-dependent paths under a
// plain `flutter test` run, where `String.fromEnvironment` resolves to ''.
//
// Module contract (design HLD): this file depends on ZERO feature modules
// — account mode is read from core's own SessionModeTracker (AuthBloc
// drives it), not from auth's presentation layer.
//
// F42 T2: [FeedbackDiagnostics] moved to feedback_kind.dart (model root,
// acyclic edges) and re-exported below; the typed form mailto builder
// ([buildFormFeedbackMail]) and launch flow ([mailFeedbackForm]) live here.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/feedback/feedback_form_dialog.dart';
import 'package:yucai_client/core/feedback/feedback_kind.dart';
import 'package:yucai_client/core/feedback/feedback_submit_service.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

// F41 API compatibility: FeedbackDiagnostics is now defined in
// feedback_kind.dart (F42 T2 move); existing imports keep resolving.
export 'package:yucai_client/core/feedback/feedback_kind.dart'
    show FeedbackDiagnostics;

/// Compile-time feedback recipient. Single definition point repo-wide;
/// release builds pass `--dart-define=FEEDBACK_EMAIL=...` (release.yml).
const feedbackEmail = String.fromEnvironment('FEEDBACK_EMAIL');

/// Cap on the ENCODED mailto URI length (percent-encoded characters).
/// Mail clients commonly reject URIs past ~2000 chars; 1800 keeps
/// headroom for the recipient/subject overhead. F42 T2 brief constant.
const feedbackMailtoMaxEncodedLength = 1800;

/// Truncation marker appended to the trimmed body when the encoded URI
/// exceeds [feedbackMailtoMaxEncodedLength] (prototype v4 copy).
const _feedbackTruncationMarker = '(过长已截断,完整内容已复制)';

/// Function seam for opening a URI with the OS (url_launcher). Production
/// default opens external applications — the mail client for mailto.
typedef LaunchUrlFn = Future<bool> Function(Uri url, {LaunchMode mode});

/// Function seam for writing text to the system clipboard.
typedef ClipboardWriter = Future<void> Function(String text);

Future<bool> _defaultLaunch(
  Uri url, {
  LaunchMode mode = LaunchMode.externalApplication,
}) =>
    launchUrl(url, mode: mode);

Future<void> _defaultClip(String text) =>
    Clipboard.setData(ClipboardData(text: text));

/// Whitelisted diagnostic header moved to feedback_kind.dart (F42 T2);
/// re-exported above for F41 import compatibility.

/// Builds the feedback mailto URI. The standard [Uri] constructor
/// percent-encodes queryParameters, so CJK in subject/body travels as
/// %XX sequences and the URI string carries no raw non-ASCII bytes.
Uri buildFeedbackMailto(FeedbackDiagnostics d, {String? email}) {
  return Uri(
    scheme: 'mailto',
    path: email ?? feedbackEmail,
    queryParameters: {
      'subject': '御财反馈',
      'body': d.bodyLines().join('\n'),
    },
  );
}

/// A typed feedback mail ready for launching.
class FormFeedbackMail {
  const FormFeedbackMail({
    required this.uri,
    required this.truncated,
    required this.fullBody,
    required this.fullEncodedLength,
  });

  /// The mailto URI to hand the OS (already truncated to fit the encoded
  /// cap when needed).
  final Uri uri;

  /// Whether the body had to be tail-truncated.
  final bool truncated;

  /// The FULL untruncated body assembly (clipboard source of truth).
  final String fullBody;

  /// Percent-encoded length of the UNTRUNCATED URI (== uri.toString()
  /// length when not truncated) — exposed so tests pin the boundary
  /// against the pre-truncation length, not the capped one.
  final int fullEncodedLength;
}

/// Builds the typed form mailto (F42): subject 「御财反馈-<类型中文>」;
/// body = 正文 + optional 「联系方式:…」 line + blank line + the 4-line
/// diagnostics header. When the percent-encoded URI would exceed
/// [feedbackMailtoMaxEncodedLength], the 正文 is tail-truncated (rune-safe,
/// binary-searched to the largest fitting prefix) and the truncation
/// marker is appended inside the body — contact/diagnostics always
/// survive.
FormFeedbackMail buildFormFeedbackMail(FeedbackForm form, {String? email}) {
  final recipient = email ?? feedbackEmail;
  final subject = '御财反馈-${form.kind.label}';
  final diag = form.diagnostics.bodyLines().join('\n');

  String assemble(String body) => form.contact.isEmpty
      ? '$body\n\n$diag'
      : '$body\n联系方式:${form.contact}\n\n$diag';

  Uri uriOf(String body) => Uri(
        scheme: 'mailto',
        path: recipient,
        queryParameters: {'subject': subject, 'body': body},
      );

  final fullBody = assemble(form.body);
  final fullUri = uriOf(fullBody);
  if (fullUri.toString().length <= feedbackMailtoMaxEncodedLength) {
    return FormFeedbackMail(
      uri: fullUri,
      truncated: false,
      fullBody: fullBody,
      fullEncodedLength: fullUri.toString().length,
    );
  }

  // Over the cap: binary-search the largest rune prefix whose marked body
  // still fits (encoded length is monotone in prefix length, so the search
  // is exact). The marker consumes budget, so the prefix alone might not
  // have fit even before the marker — the search handles that naturally.
  final runes = form.body.runes.toList();
  int lo = 0, hi = runes.length;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    final marked =
        '${String.fromCharCodes(runes.take(mid))}$_feedbackTruncationMarker';
    if (uriOf(assemble(marked)).toString().length <=
        feedbackMailtoMaxEncodedLength) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  final trimmed =
      '${String.fromCharCodes(runes.take(lo))}$_feedbackTruncationMarker';
  return FormFeedbackMail(
    uri: uriOf(assemble(trimmed)),
    truncated: true,
    fullBody: fullBody,
    fullEncodedLength: fullUri.toString().length,
  );
}

/// Outcome of a feedback launch attempt (three-state, see file header).
enum FeedbackLaunchResult { launched, emailMissing, launchFailedCopied }

/// Runs the feedback mail flow:
///  - empty recipient → [FeedbackLaunchResult.emailMissing] immediately
///    (no URI built, no seam touched);
///  - launch seam returns true → [FeedbackLaunchResult.launched];
///  - launch seam returns false → clipboard fallback writes
///    `收件人:<email>` / `主题:御财反馈` + the 4-line diagnostic header →
///    [FeedbackLaunchResult.launchFailedCopied].
Future<FeedbackLaunchResult> launchFeedback(
  FeedbackDiagnostics d, {
  String? email,
  LaunchUrlFn? launch,
  ClipboardWriter? clip,
}) async {
  final recipient = email ?? feedbackEmail;
  if (recipient.isEmpty) return FeedbackLaunchResult.emailMissing;
  final uri = buildFeedbackMailto(d, email: recipient);
  // S-4: url_launcher surfaces PlatformException on unsupported/cancelled
  // launches; a throwing seam is treated like a plain false so the
  // clipboard fallback still runs — launchFeedback never throws (file
  // header).
  bool opened = false;
  try {
    opened = await (launch ?? _defaultLaunch)(
      uri,
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (opened) return FeedbackLaunchResult.launched;
  await (clip ?? _defaultClip)(
    '收件人:$recipient\n主题:御财反馈\n\n${d.bodyLines().join('\n')}',
  );
  return FeedbackLaunchResult.launchFailedCopied;
}

/// Runs the typed form mail flow (F42 T2), the form-based counterpart of
/// [launchFeedback]:
///  - empty recipient → [FeedbackLaunchResult.emailMissing] immediately;
///  - over-limit body → the FULL untruncated text goes to the clipboard
///    FIRST (the mail client only receives the truncated URI, so the
///    clipboard is the only carrier of the complete content);
///  - launch seam true → [FeedbackLaunchResult.launched];
///  - launch seam false/throwing → clipboard fallback with recipient +
///    typed subject + full body → [FeedbackLaunchResult.launchFailedCopied].
/// Never throws (same S-4 contract as [launchFeedback]).
Future<FeedbackLaunchResult> mailFeedbackForm(
  FeedbackForm form, {
  String? email,
  LaunchUrlFn? launch,
  ClipboardWriter? clip,
}) async {
  final recipient = email ?? feedbackEmail;
  if (recipient.isEmpty) return FeedbackLaunchResult.emailMissing;

  final mail = buildFormFeedbackMail(form, email: recipient);
  final fullText =
      '收件人:$recipient\n主题:御财反馈-${form.kind.label}\n\n${mail.fullBody}';

  bool opened = false;
  try {
    opened = await (launch ?? _defaultLaunch)(
      mail.uri,
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (mail.truncated) {
    await (clip ?? _defaultClip)(fullText);
  }
  if (opened) return FeedbackLaunchResult.launched;
  if (!mail.truncated) {
    await (clip ?? _defaultClip)(fullText);
  }
  return FeedbackLaunchResult.launchFailedCopied;
}

/// Shared UI entry for the three feedback affordances (sidebar row,
/// bottom-nav destination, settings row). F42: opens the dual-channel
/// [FeedbackFormDialog] (online gRPC with offline-mailto fallback) instead
/// of jumping straight to a mail client; the form's mail channel still
/// consumes the F41 seams below.
///
/// Test seams: AppShell is constructed inside the router, so widget tests
/// pumping the real router cannot reach constructor seams — the ambient
/// statics [emailSource] / [launchUrlFn] / [clipboardWriter] /
/// [submitServiceFactory] are the injection points (swapped per test and
/// restored on teardown; production never overrides them).
class FeedbackEntry {
  FeedbackEntry._();

  /// Recipient source; defaults to the compile-time [feedbackEmail].
  static String Function() emailSource = () => feedbackEmail;

  /// Default [LaunchUrlFn] seam handed to the mail channel.
  static LaunchUrlFn launchUrlFn = _defaultLaunch;

  /// Default [ClipboardWriter] seam handed to the mail channel.
  static ClipboardWriter clipboardWriter = _defaultClip;

  /// Builds the dialog's submit service (ambient deps by default); the
  /// seam exists so entry-path widget tests can inject a fully faked
  /// service without mounting the DI graph.
  static FeedbackSubmitService Function() submitServiceFactory =
      FeedbackSubmitService.new;

  /// Collects the read-only diagnostic header (F41 4-field whitelist):
  /// version (500ms-bounded PackageInfo), platform, account mode
  /// (SessionModeTracker, guarded getIt), resolved theme brightness.
  static Future<FeedbackDiagnostics> collectDiagnostics(
      BuildContext context) async {
    // Account mode goes through SessionModeTracker (core→core), per its
    // house rule: non-presentation consumers must not import AuthBloc.
    // isGuest=false covers Authenticated AND OfflineAuthenticated — both
    // are bound sessions. Guarded getIt: widget tests may mount the
    // entries without the full DI graph; absence degrades to 'guest',
    // matching the tracker's own optimistic guest default.
    final tracker = getIt.isRegistered<SessionModeTracker>()
        ? getIt<SessionModeTracker>()
        : null;
    final accountMode = tracker != null && !tracker.isGuest ? '绑定' : 'guest';
    // Theme.brightness is the resolved mode actually being rendered
    // (MaterialApp resolves ThemeMode.system against platform brightness),
    // so it answers 亮/暗 without re-deriving the system-vs-forced question.
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Version degrades to '' when package_info is unavailable or stalls —
    // feedback is a lifeline and must never hang or throw. plugin-less
    // environments (widget tests) never answer the platform channel, so
    // the lookup is bounded by a timeout (tray_controller degrades its
    // versionProvider the same way).
    String version = '';
    try {
      version = (await PackageInfo.fromPlatform()
              .timeout(const Duration(milliseconds: 500)))
          .version;
    } catch (_) {
      // Keep the empty version value; the 版本 line simply shows blank.
    }
    return FeedbackDiagnostics(
      appVersion: version,
      platform: Platform.operatingSystem,
      accountMode: accountMode,
      themeMode: dark ? '暗' : '亮',
    );
  }

  /// Opens the feedback form dialog (F42 dual-channel). The call-site
  /// signature is unchanged since F41 (sidebar row, bottom-nav destination,
  /// settings row) — zero layout change at the entries.
  static Future<void> launch(BuildContext context) async {
    // Context-dependent inputs are collected synchronously (pre-await),
    // per use_build_context_synchronously; diagnostics finish BEFORE the
    // dialog mounts so the read-only header renders complete.
    final diagnostics = await collectDiagnostics(context);
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => FeedbackFormDialog(
        diagnostics: diagnostics,
        submitService: submitServiceFactory(),
      ),
    );
  }
}
