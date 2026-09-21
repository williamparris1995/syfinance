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
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

/// Compile-time feedback recipient. Single definition point repo-wide;
/// release builds pass `--dart-define=FEEDBACK_EMAIL=...` (release.yml).
const feedbackEmail = String.fromEnvironment('FEEDBACK_EMAIL');

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

/// Whitelisted diagnostic header for the feedback mail: exactly the four
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

/// Shared UI entry for the three feedback affordances (sidebar row,
/// bottom-nav destination, settings row): assembles [FeedbackDiagnostics]
/// from the ambient context/env, launches, and maps the result to a
/// Chinese snackbar prompt (launched stays silent).
///
/// Test seams: AppShell is constructed inside the router, so widget tests
/// pumping the real router cannot reach constructor seams — the ambient
/// statics [emailSource] / [launchUrlFn] / [clipboardWriter] are the
/// injection points (swapped per test and restored on teardown;
/// production never overrides them).
class FeedbackEntry {
  FeedbackEntry._();

  /// Recipient source; defaults to the compile-time [feedbackEmail].
  static String Function() emailSource = () => feedbackEmail;

  /// Default [LaunchUrlFn] seam handed to [launchFeedback].
  static LaunchUrlFn launchUrlFn = _defaultLaunch;

  /// Default [ClipboardWriter] seam handed to [launchFeedback].
  static ClipboardWriter clipboardWriter = _defaultClip;

  static Future<void> launch(BuildContext context) async {
    // Context-dependent inputs are collected synchronously (pre-await),
    // per use_build_context_synchronously. Theme.brightness is the
    // resolved mode actually being rendered (MaterialApp resolves
    // ThemeMode.system against platform brightness), so it answers
    // 亮/暗 without re-deriving the system-vs-forced question.
    //
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final messenger = ScaffoldMessenger.of(context);
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
    final result = await launchFeedback(
      FeedbackDiagnostics(
        appVersion: version,
        platform: Platform.operatingSystem,
        accountMode: accountMode,
        themeMode: dark ? '暗' : '亮',
      ),
      email: emailSource(),
      launch: launchUrlFn,
      clip: clipboardWriter,
    );
    if (!context.mounted) return;
    switch (result) {
      case FeedbackLaunchResult.emailMissing:
        messenger.showSnackBar(
          const SnackBar(
              content: Text('反馈邮箱未配置(需 --dart-define=FEEDBACK_EMAIL)')),
        );
      case FeedbackLaunchResult.launchFailedCopied:
        messenger.showSnackBar(
          const SnackBar(
              content: Text('未检测到邮件客户端,反馈内容已复制,可粘贴到网页邮箱发送')),
        );
      case FeedbackLaunchResult.launched:
        break; // Mail client opened — silent success.
    }
  }
}
