// F42 T2 — TDD tests for FeedbackFormDialog (prototype v4 contract):
//  1. rendering: title/三类型卡/计数器/只读诊断头 4 行+隐私 caption/提交禁用态;
//  2. validation guards: 未选类型 or 空正文 or >1000 字 → 提交禁用;
//  3. success: submitted → 「已提交,感谢反馈」 SnackBar → dialog auto-closes;
//  4. failed/rateLimited: dialog stays OPEN with content preserved, SnackBar
//     carries 重试/改用邮件 double actions; 重试 re-submits the same form;
//     改用邮件 routes to the mail channel without touching gRPC.
//
// The submit service is injected via the constructor seam (all deps faked)
// so no network/connectivity is involved.
import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:url_launcher/url_launcher.dart';

import 'package:yucai_client/core/feedback/feedback_form_dialog.dart';
import 'package:yucai_client/core/feedback/feedback_kind.dart';
import 'package:yucai_client/core/feedback/feedback_submit_service.dart';
import 'package:yucai_client/proto/feedback/v1/feedback.pb.dart' as pb;

const _diag = FeedbackDiagnostics(
  appVersion: '1.0.8',
  platform: 'windows',
  accountMode: 'guest',
  themeMode: '亮',
);

/// Builds a service whose gRPC seam records requests and returns
/// [behavior]'s outcome; the launch/clip seams record mail-channel calls.
class _RecordingService {
  _RecordingService({this.behavior});

  final Future<pb.SubmitFeedbackResponse> Function()? behavior;

  final requests = <pb.SubmitFeedbackRequest>[];
  final launched = <Uri>[];
  int rpcCalls = 0;
  int launchCalls = 0;

  FeedbackSubmitService build({bool online = true}) {
    return FeedbackSubmitService(
      deps: FeedbackSubmitDeps(
        online: () => online,
        rpc: (req) async {
          rpcCalls++;
          requests.add(req);
          if (behavior != null) return behavior!();
          return pb.SubmitFeedbackResponse(id: Int64(41));
        },
        emailSource: () => 'feedback@example.com',
        launch: (url, {LaunchMode mode = LaunchMode.externalApplication}) async {
          launchCalls++;
          launched.add(url);
          return true;
        },
        clip: (_) async {},
      ),
    );
  }
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required FeedbackSubmitService service,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => FeedbackFormDialog(
                diagnostics: _diag,
                submitService: service,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _fillForm(WidgetTester tester) async {
  await tester.tap(find.text('问题'));
  await tester.pump();
  await tester.enterText(
      find.widgetWithText(TextField, '请描述你遇到的问题或建议…'), '同步后列表偶发空白');
  await tester.pump();
}

/// Scrolls the dialog's content until the failure strip actions are visible
/// (the strip renders below the fold in the default 800x600 viewport).
Future<void> _scrollToFailureActions(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('改用邮件'),
    200,
    scrollable: find
        .descendant(
            of: find.byType(AlertDialog), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
}

Finder get _submitButton => find.text('提交反馈');

/// The dialog's submit FilledButton — stable across idle (label) and
/// submitting (spinner) states, unlike [_submitButton] which only matches
/// the label.
Finder get _submitButtonWidget => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    );

void main() {
  testWidgets('renders: title/type cards×3/counter/diagnostics 4 lines + '
      'privacy caption; submit starts disabled', (tester) async {
    final rec = _RecordingService();
    await _pumpDialog(tester, service: rec.build());

    expect(find.widgetWithText(AlertDialog, '意见反馈'), findsOneWidget);
    expect(find.text('问题或建议直达开发者;在线直传,离线自动改走邮件'),
        findsOneWidget);
    expect(find.text('问题'), findsOneWidget);
    expect(find.text('建议'), findsOneWidget);
    expect(find.text('其他'), findsOneWidget);
    expect(find.text('0/1000'), findsOneWidget);
    // Read-only diagnostics header: the 4 F41 whitelist lines verbatim.
    expect(find.text('版本:1.0.8'), findsOneWidget);
    expect(find.text('平台:windows'), findsOneWidget);
    expect(find.text('账户:guest'), findsOneWidget);
    expect(find.text('主题:亮'), findsOneWidget);
    expect(find.text('随反馈自动附带,便于定位问题;不含任何财务数据'),
        findsOneWidget);
    // Contact field is optional and labeled as such.
    expect(find.text('联系方式(选填)'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      _submitButtonWidget,
    );
    expect(button.onPressed, isNull, reason: 'no type + empty body → disabled');
    expect(rec.requests, isEmpty);
  });

  testWidgets('validation: type selected but empty body → disabled; '
      '1001-rune body → counter over + disabled; valid form → enabled',
      (tester) async {
    final svc = _RecordingService().build();
    await _pumpDialog(tester, service: svc);

    // Type only, body still empty.
    await tester.tap(find.text('问题'));
    await tester.pump();
    var button = tester.widget<FilledButton>(
      _submitButtonWidget,
    );
    expect(button.onPressed, isNull);

    // Valid body → enabled.
    await tester.enterText(
        find.widgetWithText(TextField, '请描述你遇到的问题或建议…'), '正常长度的正文');
    await tester.pump();
    button = tester.widget<FilledButton>(
      _submitButtonWidget,
    );
    expect(button.onPressed, isNotNull);

    // 1001 runes → over-limit counter + disabled again.
    await tester.enterText(find.widgetWithText(
        TextField, '请描述你遇到的问题或建议…'), '长' * 1001);
    await tester.pump();
    expect(find.text('1001/1000'), findsOneWidget);
    button = tester.widget<FilledButton>(
      _submitButtonWidget,
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('success → 「已提交,感谢反馈」 SnackBar, dialog auto-closes',
      (tester) async {
    final rec = _RecordingService();
    final svc = rec.build();
    await _pumpDialog(tester, service: svc);
    await _fillForm(tester);

    await tester.tap(_submitButton);
    await tester.pump(); // snackbar frame
    expect(find.text('已提交,感谢反馈'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AlertDialog, '意见反馈'), findsNothing,
        reason: 'dialog must close itself after success');
    expect(rec.rpcCalls, 1);
    expect(rec.requests.single.body, '同步后列表偶发空白');
    expect(rec.requests.single.type, pb.FeedbackType.ISSUE);
  });

  testWidgets('failed → dialog stays open with content preserved; '
      'SnackBar offers 重试/改用邮件; 重试 re-sends the same form',
      (tester) async {
    final rec = _RecordingService(
      behavior: () async => throw _unavailable(),
    );
    final svc = rec.build();
    await _pumpDialog(tester, service: svc);
    await _fillForm(tester);

    await tester.tap(_submitButton);
    await tester.pump();
    expect(find.text('上传失败,内容已保留'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('改用邮件'), findsOneWidget);
    // Dialog still open and the typed body survived.
    expect(find.widgetWithText(AlertDialog, '意见反馈'), findsOneWidget);
    expect(find.text('同步后列表偶发空白'), findsOneWidget);
    expect(rec.rpcCalls, 1);

    // 重试: the strip sits below the fold of the 800x600 test viewport —
    // scroll like a real user, then tap (fails once more here).
    await _scrollToFailureActions(tester);
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(rec.rpcCalls, 2);
    expect(rec.requests.last.body, rec.requests.first.body);
    expect(find.widgetWithText(AlertDialog, '意见反馈'), findsOneWidget);
  });

  testWidgets('rateLimited → 「提交过于频繁」 variant with the same actions',
      (tester) async {
    final rec = _RecordingService(
      behavior: () async => throw _resourceExhausted(),
    );
    final svc = rec.build();
    await _pumpDialog(tester, service: svc);
    await _fillForm(tester);

    await tester.tap(_submitButton);
    await tester.pump();
    expect(find.textContaining('提交过于频繁'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('改用邮件'), findsOneWidget);
    expect(find.widgetWithText(AlertDialog, '意见反馈'), findsOneWidget);
  });

  testWidgets('改用邮件 after failure → mail channel, gRPC untouched again',
      (tester) async {
    final rec = _RecordingService(
      behavior: () async => throw _unavailable(),
    );
    final svc = rec.build();
    await _pumpDialog(tester, service: svc);
    await _fillForm(tester);

    await tester.tap(_submitButton);
    await tester.pump();
    expect(rec.rpcCalls, 1);

    await _scrollToFailureActions(tester);
    await tester.tap(find.text('改用邮件'));
    await tester.pumpAndSettle();

    expect(rec.rpcCalls, 1, reason: 'mail path must not re-invoke gRPC');
    expect(rec.launchCalls, 1);
    expect(rec.launched.single.queryParameters['subject'], '御财反馈-问题');
    // Mail channel done → toast + close.
    expect(find.text('已唤起邮件客户端(离线通道)'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, '意见反馈'), findsNothing);
  });

  testWidgets('submitting state disables the button (spinner guard)',
      (tester) async {
    final gate = Completer<void>();
    final rec = _RecordingService(
      behavior: () async {
        await gate.future;
        return pb.SubmitFeedbackResponse(id: Int64(9));
      },
    );
    final svc = rec.build();
    await _pumpDialog(tester, service: svc);
    await _fillForm(tester);

    await tester.tap(_submitButton);
    await tester.pump(); // submitting frame, RPC still pending

    final button = tester.widget<FilledButton>(
      _submitButtonWidget,
    );
    expect(button.onPressed, isNull,
        reason: 'double-tap must be impossible while submitting');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('已提交,感谢反馈'), findsOneWidget);
  });
}

// gRPC error factories (service maps by status code).
grpc.GrpcError _unavailable() => const grpc.GrpcError.unavailable('net down');
grpc.GrpcError _resourceExhausted() =>
    const grpc.GrpcError.resourceExhausted('feedback rate limit');
