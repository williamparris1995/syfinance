// F42 T2 — dual-channel feedback submit core.
//
// Routing (spec FR-3): one connectivity snapshot decides the channel —
//   online  → SubmitFeedback gRPC (10s deadline; ResourceExhausted →
//             rateLimited variant; everything else → failed);
//   offline → F41 mailto path via [mailFeedbackForm] (typed subject +
//             >1800-encoded-char truncation + clipboard full-text).
// FEEDBACK_EMAIL absent while offline → emailMissing variant (F41 copy).
//
// The service never throws: every failure mode collapses into a
// [SubmitOutcome] variant so the dialog can keep the user's text and offer
// 重试 / 改用邮件.
//
// Seams ([FeedbackSubmitDeps]): the gRPC call is injectable as a plain
// function ([FeedbackSubmitRpc]) — no real channel needed in tests — while
// production builds the generated FeedbackServiceClient over the shared
// GrpcClient channel. AuthInterceptor is no-token tolerant (missing token →
// no authorization header), so the guest path rides the same channel as
// every other RPC; SubmitFeedback is anonymously allowlisted server-side.
import 'dart:async';

import 'package:grpc/grpc.dart' as grpc;

import 'package:yucai_client/core/connectivity/connectivity_gateway.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/feedback/feedback_kind.dart';
import 'package:yucai_client/core/feedback/feedback_launcher.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/proto/feedback/v1/feedback.pb.dart' as pb;
import 'package:yucai_client/proto/feedback/v1/feedback.pbgrpc.dart'
    as feedbackgrpc;

/// Injectable RPC seam: request in, response (or thrown [grpc.GrpcError])
/// out. Mirrors a unary FeedbackService.submitFeedback call.
typedef FeedbackSubmitRpc = Future<pb.SubmitFeedbackResponse> Function(
    pb.SubmitFeedbackRequest request);

/// The four channel outcomes plus the offline misconfiguration variant.
enum SubmitOutcomeVariant {
  /// gRPC accepted the submission; [SubmitOutcome.id] carries the row id.
  uploaded,

  /// Mail channel completed (mail client opened, or clipboard fallback ran
  /// — see [SubmitOutcome.copiedToClipboard]).
  mailed,

  /// Server rate limit (RESOURCE_EXHAUSTED): retry later or switch to mail.
  rateLimited,

  /// Upload failed for any other reason; the form content is preserved.
  failed,

  /// Offline + FEEDBACK_EMAIL not compiled in: nothing could be sent.
  emailMissing,
}

/// Result of one submit attempt (variant + payload).
class SubmitOutcome {
  const SubmitOutcome.uploaded(int this.id)
      : variant = SubmitOutcomeVariant.uploaded,
        copiedToClipboard = false;

  const SubmitOutcome.mailed({this.copiedToClipboard = false})
      : variant = SubmitOutcomeVariant.mailed,
        id = null;

  const SubmitOutcome.rateLimited()
      : variant = SubmitOutcomeVariant.rateLimited,
        id = null,
        copiedToClipboard = false;

  const SubmitOutcome.failed()
      : variant = SubmitOutcomeVariant.failed,
        id = null,
        copiedToClipboard = false;

  const SubmitOutcome.emailMissing()
      : variant = SubmitOutcomeVariant.emailMissing,
        id = null,
        copiedToClipboard = false;

  final SubmitOutcomeVariant variant;

  /// Server row id (uploaded only).
  final int? id;

  /// True when the mail channel degraded to the clipboard fallback.
  final bool copiedToClipboard;
}

/// Constructor-injected dependencies. Every field optional: production
/// defaults resolve lazily from the ambient DI / F41 static seams.
class FeedbackSubmitDeps {
  const FeedbackSubmitDeps({
    this.rpc,
    this.online,
    this.emailSource,
    this.launch,
    this.clip,
    this.timeout = const Duration(seconds: 10),
  });

  /// Direct RPC seam (tests). When null, production builds the stub from
  /// the shared [GrpcClient] channel per call.
  final FeedbackSubmitRpc? rpc;

  /// Connectivity snapshot source; production reads
  /// [ConnectivityGateway.current] once per submit.
  final bool Function()? online;

  /// Recipient source; defaults to the F41 ambient [FeedbackEntry.emailSource].
  final String Function()? emailSource;

  /// Mail launch seam; defaults to the F41 ambient [FeedbackEntry.launchUrlFn].
  final LaunchUrlFn? launch;

  /// Clipboard seam; defaults to the F41 ambient [FeedbackEntry.clipboardWriter].
  final ClipboardWriter? clip;

  /// gRPC deadline (brief: 10s; injectable so tests don't wait).
  final Duration timeout;
}

/// Dual-channel submit orchestrator. Stateless — one instance can serve
/// every submission in the process.
class FeedbackSubmitService {
  FeedbackSubmitService({this.deps = const FeedbackSubmitDeps()});

  final FeedbackSubmitDeps deps;

  /// Submits [form]. [forceMail] routes straight to the mail channel
  /// regardless of connectivity (the dialog's 改用邮件 action after a
  /// failed upload).
  Future<SubmitOutcome> submit(FeedbackForm form, {bool forceMail = false}) async {
    if (!forceMail && _online()) {
      return _submitOnline(form);
    }
    return _submitViaMail(form);
  }

  // ---- online channel ----

  Future<SubmitOutcome> _submitOnline(FeedbackForm form) async {
    final rpc = deps.rpc ?? _ambientRpc;
    try {
      final response = await rpc(_encodeRequest(form)).timeout(deps.timeout);
      return SubmitOutcome.uploaded(response.id.toInt());
    } on grpc.GrpcError catch (e) {
      if (e.code == grpc.StatusCode.resourceExhausted) {
        return const SubmitOutcome.rateLimited();
      }
      return const SubmitOutcome.failed();
    } on TimeoutException {
      return const SubmitOutcome.failed();
    } catch (_) {
      // Non-gRPC failure (encoding, channel construction, ...): same
      // outcome as a failed upload — the dialog offers retry / mail.
      return const SubmitOutcome.failed();
    }
  }

  pb.SubmitFeedbackRequest _encodeRequest(FeedbackForm form) {
    final d = form.diagnostics;
    return pb.SubmitFeedbackRequest(
      type: form.kind.pbValue,
      body: form.body,
      contact: form.contact,
      diagnostics: pb.FeedbackDiagnostics(
        appVersion: d.appVersion,
        platform: d.platform,
        accountMode: d.accountMode,
        themeMode: d.themeMode,
      ),
    );
  }

  /// Production RPC: FeedbackServiceClient over the shared GrpcClient
  /// channel (same construction shape as GrpcOfflineSyncPort). Guest
  /// sessions send no authorization header — the server allowlists
  /// SubmitFeedback for anonymous callers.
  FeedbackSubmitRpc get _ambientRpc {
    return (request) async {
      final grpcClient = getIt.isRegistered<GrpcClient>()
          ? getIt<GrpcClient>()
          : null;
      if (grpcClient == null) {
        // DI graph absent (bare widget tests): nothing to upload through.
        throw const grpc.GrpcError.unavailable('grpc client not registered');
      }
      final client = feedbackgrpc.FeedbackServiceClient(
        grpcClient.channel,
        interceptors: [grpcClient.authInterceptor],
      );
      return await client.submitFeedback(request);
    };
  }

  // ---- offline channel ----

  Future<SubmitOutcome> _submitViaMail(FeedbackForm form) async {
    final result = await mailFeedbackForm(
      form,
      email: (deps.emailSource ?? FeedbackEntry.emailSource)(),
      launch: deps.launch ?? FeedbackEntry.launchUrlFn,
      clip: deps.clip ?? FeedbackEntry.clipboardWriter,
    );
    switch (result) {
      case FeedbackLaunchResult.launched:
        return const SubmitOutcome.mailed();
      case FeedbackLaunchResult.launchFailedCopied:
        return const SubmitOutcome.mailed(copiedToClipboard: true);
      case FeedbackLaunchResult.emailMissing:
        return const SubmitOutcome.emailMissing();
    }
  }

  // ---- ambient helpers ----

  bool _online() {
    // Injected seam wins; otherwise one snapshot of the ambient gateway
    // (optimistic default mirrors ConnectivityGateway's own plugin-failure
    // semantics; guarded getIt keeps bare widget harnesses working).
    final injected = deps.online;
    if (injected != null) return injected();
    if (getIt.isRegistered<ConnectivityGateway>()) {
      return getIt<ConnectivityGateway>().current;
    }
    return true;
  }
}
