import 'package:equatable/equatable.dart';

/// Pure-domain description of an OIDC provider the server advertises via
/// GetOIDCConfig. The data layer maps the proto `OIDCProviderConfig` into
/// this; the data layer's `OIDCAuthenticator` consumes it to build the
/// authorization URL.
class OidcProviderConfig extends Equatable {
  const OidcProviderConfig({
    required this.name,
    required this.displayName,
    required this.issuer,
    required this.authorizationEndpoint,
    required this.clientId,
    required this.scopes,
  });

  /// Stable identifier ("google", "github", ...). Sent back on OIDCExchange.
  final String name;

  /// User-facing label rendered on the login button ("Google").
  final String displayName;

  /// OIDC issuer URL (informational; included for future id-token validation).
  final String issuer;

  /// Authorization endpoint hit by the browser during the loopback flow.
  final String authorizationEndpoint;

  /// OAuth client_id registered with the provider for this app.
  final String clientId;

  /// Scopes to request (e.g. ["openid", "email", "profile"]).
  final List<String> scopes;

  @override
  List<Object?> get props => [
        name,
        displayName,
        issuer,
        authorizationEndpoint,
        clientId,
        scopes,
      ];
}
