// Task 12 — integration test for OIDCAuthenticator loopback PKCE flow.
//
// This is an INTEGRATION test (deferred from Task 10): we exercise the real
// HttpServer the authenticator binds, with only the browser seam replaced by
// a fake `UrlLauncherFn`. The fake records the auth URL the authenticator
// built, then the test performs a real HTTP GET against the loopback
// /callback?code=...&state=... — driving the full request → response →
// completer path inside the authenticator.
//
// Coverage:
//   - success: code/verifier/redirectUri round-trip; auth URL has S256 PKCE
//     challenge + matching state; callback HTML greets the user in Chinese.
//   - state mismatch: throws + callback HTML reports 状态不匹配.
//   - no `code` in callback (e.g. user denied consent): throws + callback
//     HTML reports 未收到授权码.
//   - launcher returns false: throws 'failed to launch browser'.
//
// Notes:
//   - Uses `test` (not `testWidgets`) so real async / dart:io work; each test
//     fails fast via `.timeout(...)` so a regression that fails to complete
//     the dance surfaces in seconds rather than the 3-minute watchdog.
//   - Response body decoded UTF-8 (authenticator writes UTF-8 via
//     HttpResponse.write; SystemEncoding on Windows would mojibake CJK).
//   - Server cleanup is observed indirectly: each test drives the dance to a
//     terminal state (future completes or throws), which is the path that
//     calls `server.close(force: true)`. We do NOT assert "next TCP connect
//     fails" — Windows TCP accepts connections in TIME_WAIT-style lingering
//     states after close(force:true), making that assertion flaky cross-OS.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yucai_client/auth/data/oidc_authenticator.dart';
import 'package:yucai_client/auth/domain/entities/oidc_provider.dart';

OidcProviderConfig _config({
  String authorizationEndpoint = 'https://idp.example.com/authorize',
  String clientId = 'test-client-id',
  List<String> scopes = const ['openid', 'email', 'profile'],
}) =>
    OidcProviderConfig(
      name: 'google',
      displayName: 'Google',
      issuer: 'https://idp.example.com',
      authorizationEndpoint: authorizationEndpoint,
      clientId: clientId,
      scopes: scopes,
    );

/// Tuple of (launcher that captures the auth URL, future that completes with
/// the captured URL). The launcher returns `true` (success) so the
/// authenticator proceeds to wait for the loopback callback.
({UrlLauncherFn launcher, Future<Uri> captured}) _capturingLauncher() {
  final completer = Completer<Uri>();
  return (
    launcher: (url, {LaunchMode mode = LaunchMode.platformDefault}) async {
      if (!completer.isCompleted) completer.complete(url);
      return true;
    },
    captured: completer.future,
  );
}

/// Performs a real HTTP GET against the loopback server, building the callback
/// URL from the auth URL's `redirect_uri` query param. Returns the response
/// status + UTF-8-decoded body so individual tests can assert on the HTML the
/// authenticator sends back to the browser.
Future<({int status, String body})> _hitCallback(
  Uri authUrl, {
  required Map<String, String> query,
}) async {
  final redirectUri = authUrl.queryParameters['redirect_uri']!;
  final callbackUrl = Uri.parse(redirectUri).replace(queryParameters: query);
  final client = HttpClient();
  try {
    final req = await client.getUrl(callbackUrl);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    return (status: res.statusCode, body: body);
  } finally {
    client.close(force: true);
  }
}

/// Eagerly attaches an error listener to [future] so the authenticator's
/// `completer.completeError(...)` — fired from inside the loopback server's
/// request handler — is treated as "handled" rather than reported as an
/// unhandled async error by the test framework. The returned future completes
/// with the captured value OR the captured error (as a value, not a throw),
/// so tests can assert on either branch without racing the listener
/// subscription.
Future<Object?> _captured(Future<dynamic> future) {
  final c = Completer<Object?>();
  future.then(c.complete, onError: (Object e, _) => c.complete(e));
  return c.future;
}

void main() {
  test('success: returns code + verifier + redirectUri; auth URL has S256 PKCE',
      () async {
    final cap = _capturingLauncher();
    final authenticator = OIDCAuthenticator(launcher: cap.launcher);

    final future = authenticator.authenticate(_config());

    final authUrl = await cap.captured.timeout(const Duration(seconds: 5));
    final state = authUrl.queryParameters['state']!;

    // Auth URL shape — proves PKCE + redirect_uri wired right.
    expect(authUrl.queryParameters['response_type'], 'code');
    expect(authUrl.queryParameters['client_id'], 'test-client-id');
    expect(authUrl.queryParameters['scope'], 'openid email profile');
    expect(authUrl.queryParameters['code_challenge_method'], 'S256');
    // S256 challenge = base64url(sha256(verifier)) without padding → 43 chars
    // (32-byte SHA-256 digest → ⌈32*4/3⌉ = 43 base64 chars, no '=' padding).
    expect(authUrl.queryParameters['code_challenge'], hasLength(43));
    expect(authUrl.queryParameters['redirect_uri'],
        startsWith('http://localhost:'));
    expect(authUrl.queryParameters['redirect_uri'], endsWith('/callback'));
    expect(state, isNotEmpty);

    // Drive the loopback callback with a real HTTP GET.
    final res = await _hitCallback(authUrl,
        query: {'code': 'THE_AUTH_CODE', 'state': state});
    expect(res.status, 200);
    expect(res.body, contains('登录成功'));

    final result = await future.timeout(const Duration(seconds: 5));
    expect(result.code, 'THE_AUTH_CODE');
    expect(result.redirectUri, authUrl.queryParameters['redirect_uri']);
    // Verifier returned to caller → forwarded to OIDCExchange (test proves it
    // matches the challenge the auth URL carried).
    expect(result.verifier, hasLength(64));
  });

  test('state mismatch: throws + callback HTML reports 状态不匹配', () async {
    final cap = _capturingLauncher();
    final authenticator = OIDCAuthenticator(launcher: cap.launcher);

    final future = authenticator.authenticate(_config());
    // Pre-attach error listener: the authenticator completes the future
    // with an error from inside the loopback handler when the bad callback
    // lands; without an eager listener the test framework flags that as an
    // unhandled async error before expectLater can observe it.
    final captured = _captured(future.timeout(const Duration(seconds: 5)));

    final authUrl = await cap.captured.timeout(const Duration(seconds: 5));

    // Deliberately wrong state — authenticator must surface this to the
    // browser AND fail the future.
    final res = await _hitCallback(authUrl,
        query: {'code': 'C', 'state': 'WRONG_STATE'});
    expect(res.status, 200);
    expect(res.body, contains('状态不匹配'));

    final result = await captured;
    expect(result, isA<Exception>());
  });

  test('no code in callback (user denied consent): throws + HTML reports',
      () async {
    final cap = _capturingLauncher();
    final authenticator = OIDCAuthenticator(launcher: cap.launcher);

    final future = authenticator.authenticate(_config());
    // See note in 'state mismatch' test: eager listener prevents the
    // future's error completion from being flagged as unhandled.
    final captured = _captured(future.timeout(const Duration(seconds: 5)));

    final authUrl = await cap.captured.timeout(const Duration(seconds: 5));
    final state = authUrl.queryParameters['state']!;

    // IdP redirects with `error` instead of `code` when the user denies
    // consent. Authenticator surfaces this as "no code in callback".
    final res = await _hitCallback(authUrl,
        query: {'state': state, 'error': 'access_denied'});
    expect(res.status, 200);
    expect(res.body, contains('未收到授权码'));

    final result = await captured;
    expect(result, isA<Exception>());
  });

  test('launcher returns false: throws "failed to launch browser"', () async {
    final authenticator = OIDCAuthenticator(
      launcher: (_, {LaunchMode mode = LaunchMode.platformDefault}) async =>
          false,
    );

    // Should throw after binding + launch attempt. The authenticator is
    // expected to close the briefly-bound server on this branch too —
    // observable indirectly because the future throws (rather than hanging
    // for the watchdog), proving server.close + throw ran in sequence.
    await expectLater(
      authenticator.authenticate(_config()).timeout(const Duration(seconds: 5)),
      throwsA(predicate((Object? e) =>
          e is Exception && e.toString().contains('failed to launch browser'))),
    );
  });
}
