import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:injectable/injectable.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yucai_client/auth/domain/entities/oidc_provider.dart';

/// Result of a successful loopback OIDC dance: the authorization `code`
/// captured on the redirect, plus the PKCE `verifier` (sent to the token
/// endpoint via `AuthRepository.oidcExchange`) and the `redirectUri`
/// (echoed back so the server builds the matching token request).
class OidcAuthResult {
  const OidcAuthResult({
    required this.code,
    required this.verifier,
    required this.redirectUri,
  });

  final String code;
  final String verifier;
  final String redirectUri;
}

/// Function-type seam for opening the system browser. Production wires
/// `launchUrl` (via [defaultUrlLauncher]); tests pass a fake that hits the
/// loopback server directly.
typedef UrlLauncherFn = Future<bool> Function(Uri url, {LaunchMode mode});

/// Production [UrlLauncherFn] — delegates to `url_launcher.launchUrl`.
/// Registered manually in `injection.dart` so the injectable-generated
/// factory for [OIDCAuthenticator] can resolve it.
Future<bool> defaultUrlLauncher(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) {
  return launchUrl(url, mode: mode);
}

/// Loopback-based OIDC authorization-code + PKCE flow for desktop (Windows).
///
/// 1. Generate a PKCE verifier + S256 challenge and a random `state`.
/// 2. Bind a temporary localhost HTTP server on an OS-assigned port.
/// 3. Open the system browser to the provider's authorization endpoint.
/// 4. On the `/callback` request, verify `state` and surface `code`.
/// 5. Close the server and complete with an [OidcAuthResult].
///
/// Throws on user-cancel (no `code` in callback), state mismatch, browser
/// launch failure, or watchdog timeout. The caller (`OidcLoginUseCase`)
/// converts the throw into a `Left(UnexpectedFailure)`.
@LazySingleton()
class OIDCAuthenticator {
  OIDCAuthenticator({UrlLauncherFn launcher = defaultUrlLauncher}) : _launcher = launcher;

  final UrlLauncherFn _launcher;

  Future<OidcAuthResult> authenticate(
    OidcProviderConfig config, {
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final verifier = _generateCodeVerifier();
    final challenge = _s256Challenge(verifier);
    final state = _generateRandomString(16);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    final redirectUri = 'http://localhost:$port/callback';

    final authUrl = Uri.parse(config.authorizationEndpoint).replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': config.clientId,
        'redirect_uri': redirectUri,
        'scope': config.scopes.join(' '),
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
    );

    if (!await _launcher(authUrl, mode: LaunchMode.externalApplication)) {
      await server.close(force: true);
      throw Exception('failed to launch browser');
    }

    final completer = Completer<OidcAuthResult>();
    Timer? watchdog;
    watchdog = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(Exception('oidc flow timed out'));
        server.close(force: true);
      }
    });

    server.listen((HttpRequest req) async {
      final uri = req.uri;
      await _respondAndClose(req);
      if (uri.path != '/callback') return;
      final qp = uri.queryParameters;
      if (qp['state'] != state) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('state mismatch'));
        }
        return;
      }
      final code = qp['code'];
      if (code == null) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception('no code in callback: ${qp['error'] ?? ''}'),
          );
        }
        return;
      }
      if (!completer.isCompleted) {
        completer.complete(OidcAuthResult(
          code: code,
          verifier: verifier,
          redirectUri: redirectUri,
        ));
        watchdog?.cancel();
        await server.close(force: true);
      }
    });

    return completer.future;
  }

  Future<void> _respondAndClose(HttpRequest req) async {
    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write('<html><body><h3>登录成功，请返回御财应用。</h3></body></html>');
    await req.response.close();
  }

  String _generateCodeVerifier() => _generateRandomString(64);

  String _generateRandomString(int n) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final r = Random.secure();
    return List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String _s256Challenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}
