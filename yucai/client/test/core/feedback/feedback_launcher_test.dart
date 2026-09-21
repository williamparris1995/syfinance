// F41 T1 — TDD tests for the pure feedback-launcher core:
// 1. buildFeedbackMailto: subject/body round-trip decode (4 lines, each
//    with field name + value), fully percent-encoded URI (no bare CJK),
//    recipient wired to the compile-time constant.
// 2. bodyLines whitelist: exactly 4 fixed-order fields — no finance data
//    (balance/amount/asset/transaction/currency symbols) can ever leak in.
// 3. launchFeedback three-state flow via injected launch/clip seams.
//
// F42 T2 extension — typed form mailto (buildFormFeedbackMail) + launch
// flow (mailFeedbackForm):
// 4. subject 「御财反馈-<类型中文>」; body = 正文 + optional 联系方式 line +
//    blank line + 4-line diagnostics header.
// 5. >1800 percent-encoded chars → 正文 tail-truncated + 「(过长已截断,
//    完整内容已复制)」 marker + clipboard receives the FULL text; ≤1800 →
//    no truncation, clipboard untouched.
//
// FEEDBACK_EMAIL is a compile-time String.fromEnvironment that is '' under
// plain `flutter test`, so recipient-dependent cases exercise the optional
// `email` seam (whose default is the same compile-time constant) and one
// case pins the empty-email early-return against `email: ''` explicitly.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yucai_client/core/feedback/feedback_kind.dart';
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

  // ── F42 T2: typed form mailto assembly + truncation ────────────────────

  FeedbackForm formWith({
    required FeedbackKind kind,
    String body = '列表偶发空白,重启后恢复',
    String contact = 'user@example.com',
  }) {
    return FeedbackForm(kind: kind, body: body, contact: contact, diagnostics: d);
  }

  group('buildFormFeedbackMail', () {
    test('typed subject; body = 正文 + 联系方式 line + blank + 4 diag lines',
        () {
      for (final (kind, subject) in [
        (FeedbackKind.issue, '御财反馈-问题'),
        (FeedbackKind.idea, '御财反馈-建议'),
        (FeedbackKind.other, '御财反馈-其他'),
      ]) {
        final mail =
            buildFormFeedbackMail(formWith(kind: kind), email: 'fb@example.com');
        expect(mail.uri.queryParameters['subject'], subject);
        expect(mail.truncated, isFalse);

        final body = mail.uri.queryParameters['body']!;
        final lines = body.split('\n');
        expect(lines.first, '列表偶发空白,重启后恢复');
        expect(lines[1], '联系方式:user@example.com');
        expect(lines[2], '');
        expect(lines[3], '版本:15.0.1');
        expect(lines[6], '主题:亮');
      }
    });

    test('empty contact → no 联系方式 line, body still ends with diagnostics',
        () {
      final mail = buildFormFeedbackMail(
          formWith(kind: FeedbackKind.idea, contact: ''),
          email: 'fb@example.com');
      final body = mail.uri.queryParameters['body']!;
      expect(body.contains('联系方式'), isFalse);
      expect(body.split('\n').length, 6); // 正文 + 空行 + 4 diag lines
    });

    test('≤1800 encoded chars → untouched body, no marker', () {
      // 100 CJK chars ≈ 900 encoded chars for the body alone — well under.
      final mail = buildFormFeedbackMail(
        formWith(kind: FeedbackKind.other, body: '短' * 100),
        email: 'fb@example.com',
      );
      expect(mail.truncated, isFalse);
      expect(mail.uri.queryParameters['body']!.contains('已截断'), isFalse);
      expect(mail.uri.toString().length, lessThanOrEqualTo(1800));
    });

    test('>1800 encoded chars → tail-truncated body + marker, uri ≤1800, '
        'fullBody carries the untruncated assembly', () {
      // 400 CJK chars → ~3600 encoded chars for the body alone: far over.
      final original = '问' * 400;
      final mail = buildFormFeedbackMail(
        formWith(kind: FeedbackKind.issue, body: original),
        email: 'fb@example.com',
      );
      expect(mail.truncated, isTrue);
      expect(mail.uri.toString().length, lessThanOrEqualTo(1800),
          reason: 'truncation must bring the URI back under the limit');
      final body = mail.uri.queryParameters['body']!;
      expect(body, contains('(过长已截断,完整内容已复制)'));
      // Tail truncation: the surviving prefix + marker fits, and the
      // contact/diagnostics tail is preserved after the marked body.
      expect(body.endsWith('联系方式:user@example.com'), isFalse,
          reason: 'marker sits inside the body, before the tail sections');
      expect(body, contains('联系方式:user@example.com'));
      expect(body, contains('版本:15.0.1'));
      // fullBody is the untouched assembly (clipboard source of truth).
      expect(mail.fullBody, contains(original));
      expect(mail.fullBody.contains('已截断'), isFalse);
    });

    test('boundary: assembly landing exactly ≤1800 stays untruncated', () {
      // Grow a CJK body until the UNTRUNCATED encoded URI crosses the cap
      // (fullEncodedLength, NOT uri.length — the latter is capped by the
      // truncation itself and would never cross). The largest n under the
      // cap must not truncate; n+1 must.
      int rawLenFor(int n) => buildFormFeedbackMail(
              formWith(kind: FeedbackKind.issue, body: '问' * n),
              email: 'fb@example.com')
          .fullEncodedLength;
      var n = 1;
      expect(rawLenFor(1) <= 1800, isTrue,
          reason: 'sanity: the smallest form must fit');
      while (rawLenFor(n + 1) <= 1800) {
        n++;
        expect(n, lessThan(1000), reason: 'guard against a runaway loop');
      }
      final at = buildFormFeedbackMail(
        formWith(kind: FeedbackKind.issue, body: '问' * n),
        email: 'fb@example.com',
      );
      expect(at.truncated, isFalse, reason: 'n=$n lands at ${rawLenFor(n)}');
      final over = buildFormFeedbackMail(
        formWith(kind: FeedbackKind.issue, body: '问' * (n + 1)),
        email: 'fb@example.com',
      );
      expect(over.truncated, isTrue, reason: 'n+1 crosses the 1800 limit');
    });
  });

  group('mailFeedbackForm', () {
    test('empty recipient → emailMissing, no URI built, seams untouched',
        () async {
      var launchCalls = 0;
      final result = await mailFeedbackForm(
        formWith(kind: FeedbackKind.issue),
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

    test('launched → clip untouched (short body)', () async {
      var clipCalls = 0;
      final result = await mailFeedbackForm(
        formWith(kind: FeedbackKind.issue),
        email: 'fb@example.com',
        launch: (_, {LaunchMode mode = LaunchMode.externalApplication}) async =>
            true,
        clip: (_) async {
          clipCalls++;
        },
      );
      expect(result, FeedbackLaunchResult.launched);
      expect(clipCalls, 0);
    });

    test('launch false → clipboard fallback carries recipient/typed subject/'
        'full body', () async {
      final clipped = <String>[];
      final result = await mailFeedbackForm(
        formWith(kind: FeedbackKind.idea),
        email: 'fb@example.com',
        launch: (_, {LaunchMode mode = LaunchMode.externalApplication}) async =>
            false,
        clip: (text) async => clipped.add(text),
      );
      expect(result, FeedbackLaunchResult.launchFailedCopied);
      expect(clipped, hasLength(1));
      expect(clipped.single, contains('收件人:fb@example.com'));
      expect(clipped.single, contains('主题:御财反馈-建议'));
      expect(clipped.single, contains('列表偶发空白,重启后恢复'));
      expect(clipped.single, contains('版本:15.0.1'));
    });

    test('over-limit body → clipboard gets the FULL text even when the '
        'mail client opened', () async {
      final clipped = <String>[];
      final result = await mailFeedbackForm(
        formWith(kind: FeedbackKind.issue, body: '问' * 400),
        email: 'fb@example.com',
        launch: (_, {LaunchMode mode = LaunchMode.externalApplication}) async =>
            true,
        clip: (text) async => clipped.add(text),
      );
      expect(result, FeedbackLaunchResult.launched);
      expect(clipped, hasLength(1));
      expect(clipped.single, contains('问' * 400));
      expect(clipped.single, contains('主题:御财反馈-问题'));
    });

    test('launch seam throws → treated as false (clipboard fallback)',
        () async {
      String? clipped;
      final result = await mailFeedbackForm(
        formWith(kind: FeedbackKind.other),
        email: 'fb@example.com',
        launch: (_, {LaunchMode mode = LaunchMode.externalApplication}) async =>
            throw PlatformException(code: 'no_mail_client'),
        clip: (text) async => clipped = text,
      );
      expect(result, FeedbackLaunchResult.launchFailedCopied);
      expect(clipped, contains('主题:御财反馈-其他'));
    });
  });
}
