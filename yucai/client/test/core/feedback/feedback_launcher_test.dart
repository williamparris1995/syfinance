// F41 T1 — TDD tests for the pure feedback-launcher core:
// 1. buildFeedbackMailto: subject/body round-trip decode (4 lines, each
//    with field name + value), fully percent-encoded URI (no bare CJK),
//    recipient wired to the compile-time constant.
// 2. bodyLines whitelist: exactly 4 fixed-order fields — no finance data
//    (balance/amount/asset/transaction/currency symbols) can ever leak in.
// 3. launchFeedback three-state flow via injected launch/clip seams.
//
// FEEDBACK_EMAIL is a compile-time String.fromEnvironment that is '' under
// plain `flutter test`, so recipient-dependent cases exercise the optional
// `email` seam (whose default is the same compile-time constant) and one
// case pins the empty-email early-return against `email: ''` explicitly.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yucai_client/core/feedback/feedback_launcher.dart';

void main() {
  const d = FeedbackDiagnostics(
    appVersion: '15.0.1',
    platform: 'windows',
    accountMode: 'guest',
    themeMode: '亮',
  );

  group('buildFeedbackMailto', () {
    test('subject/body round-trip decode: 4 lines with field name + value',
        () {
      final uri = buildFeedbackMailto(d, email: 'feedback@example.com');
      final parsed = Uri.parse(uri.toString());

      expect(parsed.scheme, 'mailto');
      expect(parsed.path, 'feedback@example.com');
      expect(parsed.queryParameters['subject'], '御财反馈');

      final body = parsed.queryParameters['body']!;
      final lines = body.split('\n');
      expect(lines, hasLength(4));
      expect(lines[0], '版本:15.0.1');
      expect(lines[1], '平台:windows');
      expect(lines[2], '账户:guest');
      expect(lines[3], '主题:亮');
    });

    test('URI string is percent-encoded: no bare CJK anywhere', () {
      final uri = buildFeedbackMailto(d, email: 'feedback@example.com');
      final s = uri.toString();
      expect(s.contains('%'), isTrue,
          reason: 'CJK must travel as percent-encoding');
      expect(s.contains(RegExp(r'[^\x20-\x7E]')), isFalse,
          reason: 'mailto URI must not carry raw non-ASCII bytes');
    });

    test('default recipient is the compile-time feedbackEmail constant', () {
      // Contract: the recipient comes from FEEDBACK_EMAIL (dart-define),
      // never a hardcoded address — this pins the single wiring point.
      expect(buildFeedbackMailto(d).path, feedbackEmail);
    });
  });

  group('FeedbackDiagnostics.bodyLines whitelist', () {
    test('exactly 4 lines, fixed field order, no non-whitelisted fields', () {
      final lines = d.bodyLines();
      expect(lines, hasLength(4));
      expect(lines[0].startsWith('版本:'), isTrue);
      expect(lines[1].startsWith('平台:'), isTrue);
      expect(lines[2].startsWith('账户:'), isTrue);
      expect(lines[3].startsWith('主题:'), isTrue);
      // Whitelist: only the four approved field names may ever appear —
      // finance-ish tokens / currency symbols must never leak into the
      // diagnostic header (pure data, so a fake env cannot smuggle them).
      final joined = lines.join('\n');
      const forbidden = ['余额', '金额', '净资产', '资产', '交易', '持仓', '¥', '￥'];
      for (final token in forbidden) {
        expect(joined.contains(token), isFalse,
            reason: 'diagnostics must not contain "$token"');
      }
    });
  });

  group('launchFeedback', () {
    test('empty email → emailMissing early-return, launch seam not called',
        () async {
      var launchCalls = 0;
      final result = await launchFeedback(
        d,
        email: '',
        launch: (_, {LaunchMode mode = LaunchMode.externalApplication}) async {
          launchCalls++;
          return true;
        },
        clip: (_) async => fail('clip must not be called'),
      );
      expect(result, FeedbackLaunchResult.emailMissing);
      expect(launchCalls, 0);
    });

    test('launch seam false → clip seam gets recipient/subject/4 lines, '
        'result launchFailedCopied', () async {
      Uri? launchedUri;
      String? clipped;
      final result = await launchFeedback(
        d,
        email: 'feedback@example.com',
        launch: (url, {LaunchMode mode = LaunchMode.externalApplication}) async {
          launchedUri = url;
          return false;
        },
        clip: (text) async => clipped = text,
      );
      expect(result, FeedbackLaunchResult.launchFailedCopied);
      expect(launchedUri, isNotNull);
      expect(launchedUri!.scheme, 'mailto');
      expect(clipped, isNotNull);
      expect(clipped!, contains('收件人:feedback@example.com'));
      expect(clipped!, contains('主题:御财反馈'));
      expect(clipped!, contains('版本:15.0.1'));
      expect(clipped!, contains('平台:windows'));
      expect(clipped!, contains('账户:guest'));
      expect(clipped!, contains('主题:亮'));
    });

    test('launch seam true → launched, clip seam not called', () async {
      var clipCalls = 0;
      final result = await launchFeedback(
        d,
        email: 'feedback@example.com',
        launch: (_, {LaunchMode mode = LaunchMode.externalApplication}) async =>
            true,
        clip: (_) async {
          clipCalls++;
        },
      );
      expect(result, FeedbackLaunchResult.launched);
      expect(clipCalls, 0);
    });

    // S-4 review fix: a throwing launch seam (url_launcher surfaces
    // PlatformException on unsupported/cancelled launches) must be treated
    // like a plain false — fall through to the clipboard path instead of
    // letting the exception escape launchFeedback.
    test('launch seam throws → treated as false → clipboard fallback '
        '(launchFailedCopied, never throws)', () async {
      String? clipped;
      final result = await launchFeedback(
        d,
        email: 'feedback@example.com',
        launch: (_, {LaunchMode mode = LaunchMode.externalApplication}) async =>
            throw PlatformException(code: 'no_mail_client'),
        clip: (text) async => clipped = text,
      );
      expect(result, FeedbackLaunchResult.launchFailedCopied);
      expect(clipped, isNotNull);
      expect(clipped!, contains('收件人:feedback@example.com'));
      expect(clipped!, contains('主题:御财反馈'));
    });
  });
}
