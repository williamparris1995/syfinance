// F42 T2 — TDD tests for FeedbackSubmitService (dual-channel submit core):
//
//  1. online → the gRPC seam is called with the fully mapped request
//     (type enum, body, contact, all 4 diagnostics fields) → uploaded(id).
//  2. offline → the gRPC seam is NOT called; the mailto launch seam runs
//     with the typed subject → mailed / mailed(copiedToClipboard) on the
//     clipboard fallback / emailMissing when FEEDBACK_EMAIL is absent.
//  3. failure mapping: unavailable → failed; resourceExhausted →
//     rateLimited; a hanging RPC → failed after the (injectable) timeout.
//  4. retry: re-submitting the SAME form after a failure re-invokes the
//     gRPC seam with a byte-identical payload (dialog 重试 contract).
//  5. forceMail (改用邮件 action) skips the online branch entirely.
//
// The RPC is injected as a plain function seam (typedef FeedbackSubmitRpc)
// so no real channel/stub is needed; the production default wires the
// generated FeedbackServiceClient over the shared GrpcClient channel.
import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:url_launcher/url_launcher.dart';

import 'package:yucai_client/core/feedback/feedback_kind.dart';
import 'package:yucai_client/core/feedback/feedback_submit_service.dart';
import 'package:yucai_client/proto/feedback/v1/feedback.pb.dart' as pb;

const _diag = FeedbackDiagnostics(
  appVersion: '1.0.8',
  platform: 'windows',
  accountMode: 'guest',
  themeMode: '亮',
);

const _form = FeedbackForm(
  kind: FeedbackKind.issue,
  body: '同步后列表偶发空白',
  contact: 'user@example.com',
  diagnostics: _diag,
);

void main() {
  test('deps default timeout is 10s (brief constant)', () {
    expect(const FeedbackSubmitDeps().timeout, const Duration(seconds: 10));
  });

  group('online channel', () {
    test('rpc called with fully mapped request → uploaded(id)', () async {
      final requests = <pb.SubmitFeedbackRequest>[];
      final svc = FeedbackSubmitService(
        deps: FeedbackSubmitDeps(
          rpc: (req) async {
            requests.add(req);
            return pb.SubmitFeedbackResponse(id: Int64(41));
          },
          online: () => true,
        ),
      );

      final outcome = await svc.submit(_form);

      expect(outcome.variant, SubmitOutcomeVariant.uploaded);
      expect(outcome.id, 41);
      expect(requests, hasLength(1));
      final req = requests.single;
      expect(req.type, pb.FeedbackType.ISSUE);
      expect(req.body, '同步后列表偶发空白');
      expect(req.contact, 'user@example.com');
      expect(req.diagnostics.appVersion, '1.0.8');
      expect(req.diagnostics.platform, 'windows');
      expect(req.diagnostics.accountMode, 'guest');
      expect(req.diagnostics.themeMode, '亮');
    });

    test('rpc throws unavailable → failed', () async {
      final svc = FeedbackSubmitService(
        deps: FeedbackSubmitDeps(
          rpc: (_) async => throw const grpc.GrpcError.unavailable('net down'),
          online: () => true,
        ),
      );
      expect((await svc.submit(_form)).variant, SubmitOutcomeVariant.failed);
    });

    test('rpc throws resourceExhausted → rateLimited', () async {
      final svc = FeedbackSubmitService(
        deps: FeedbackSubmitDeps(
          rpc: (_) async =>
              throw const grpc.GrpcError.resourceExhausted('feedback rate limit'),
          online: () => true,
        ),
      );
      expect((await svc.submit(_form)).variant,
          SubmitOutcomeVariant.rateLimited);
    });

    test('hanging rpc → failed after the injected timeout', () async {
      final svc = FeedbackSubmitService(
        deps: FeedbackSubmitDeps(
          rpc: (_) => Completer<pb.SubmitFeedbackResponse>().future,
          online: () => true,
          timeout: const Duration(milliseconds: 30),
        ),
      );
      expect((await svc.submit(_form)).variant, SubmitOutcomeVariant.failed);
    });

    test('non-grpc exception is also collapsed to failed (never throws)',
        () async {
      final svc = FeedbackSubmitService(
        deps: FeedbackSubmitDeps(
          rpc: (_) async => throw StateError('boom'),
          online: () => true,
        ),
      );
      expect((await svc.submit(_form)).variant, SubmitOutcomeVariant.failed);
    });

    test('retry after failure re-sends the identical payload', () async {
      final bodies = <String>[];
      var calls = 0;
      final svc = FeedbackSubmitService(
        deps: FeedbackSubmitDeps(
          rpc: (req) async {
            calls++;
            bodies.add(req.body);
            // Fail the first attempt, succeed the retry (dialog 重试).
            if (calls == 1) throw const grpc.GrpcError.unavailable('net down');
            return pb.SubmitFeedbackResponse(id: Int64(7));
          },
          online: () => true,
        ),
      );

      final first = await svc.submit(_form);
      expect(first.variant, SubmitOutcomeVariant.failed);

      final second = await svc.submit(_form); // same form object, untouched
      expect(second.variant, SubmitOutcomeVariant.uploaded);
      expect(second.id, 7);
      expect(calls, 2);
      expect(bodies, hasLength(2));
      expect(bodies.first, bodies.last,
          reason: 'retry must re-send the original data verbatim');
    });
  });

  group('offline / mail channel', () {
    test('offline → rpc not called; mailto launched → mailed', () async {
      final launched = <Uri>[];
      var rpcCalls = 0;
      final svc = FeedbackSubmitService(
        deps: FeedbackSubmitDeps(
          rpc: (_) async {
            rpcCalls++;
            return pb.SubmitFeedbackResponse(id: Int64(1));
          },
          online: () => false,
          emailSource: () => 'feedback@example.com',
          launch: (url, {mode = LaunchMode.platformDefault}) async {
            launched.add(url);
            return true;
          },
        ),
      );

      final outcome = await svc.submit(_form);

      expect(rpcCalls, 0, reason: 'offline must not touch gRPC');
      expect(outcome.variant, SubmitOutcomeVariant.mailed);
      expect(outcome.copiedToClipboard, isFalse);
      expect(launched, hasLength(1));
      expect(launched.single.scheme, 'mailto');
      expect(launched.single.path, 'feedback@example.com');
    });

    test('offline + launch fails → mailed(copiedToClipboard: true)', () async {
      final clipped = <String>[];
      final svc = FeedbackSubmitService(
        deps: FeedbackSubmitDeps(
          online: () => false,
          emailSource: () => 'feedback@example.com',
          launch: (url, {mode = LaunchMode.platformDefault}) async => false,
          clip: (text) async => clipped.add(text),
        ),
      );

      final outcome = await svc.submit(_form);

      expect(outcome.variant, SubmitOutcomeVariant.mailed);
      expect(outcome.copiedToClipboard, isTrue);
      expect(clipped, hasLength(1));
      expect(clipped.single, contains('收件人:feedback@example.com'));
      expect(clipped.single, contains('主题:御财反馈-问题'));
    });

    test('offline + FEEDBACK_EMAIL absent → emailMissing, nothing touched',
        () async {
      var rpcCalls = 0;
      var launchCalls = 0;
      final svc = FeedbackSubmitService(
        deps: FeedbackSubmitDeps(
          rpc: (_) async {
            rpcCalls++;
            return pb.SubmitFeedbackResponse();
          },
          online: () => false,
          emailSource: () => '',
          launch: (url, {mode = LaunchMode.platformDefault}) async {
            launchCalls++;
            return true;
          },
        ),
      );

      final outcome = await svc.submit(_form);

      expect(outcome.variant, SubmitOutcomeVariant.emailMissing);
      expect(rpcCalls, 0);
      expect(launchCalls, 0);
    });

    test('forceMail skips the online branch even when online', () async {
      var rpcCalls = 0;
      final launched = <Uri>[];
      final svc = FeedbackSubmitService(
        deps: FeedbackSubmitDeps(
          rpc: (_) async {
            rpcCalls++;
            return pb.SubmitFeedbackResponse();
          },
          online: () => true,
          emailSource: () => 'feedback@example.com',
          launch: (url, {mode = LaunchMode.platformDefault}) async {
            launched.add(url);
            return true;
          },
        ),
      );

      final outcome = await svc.submit(_form, forceMail: true);

      expect(rpcCalls, 0);
      expect(outcome.variant, SubmitOutcomeVariant.mailed);
      expect(launched.single.queryParameters['subject'], '御财反馈-问题');
    });
  });
}
