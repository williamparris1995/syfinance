use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use chrono::Utc;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use tracing::{error, info};
use urlencoding::encode;

/// OAuth tokens returned after successful authorization.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OAuthTokens {
    pub access_token: String,
    pub refresh_token: Option<String>,
    pub expires_at: Option<i64>,
}

/// Configuration for a specific OAuth provider.
pub struct OAuthConfig {
    pub client_id: String,
    pub client_secret: Option<String>,
    pub auth_url: String,
    pub token_url: String,
    pub scopes: String,
    pub redirect_port: u16,
}

/// PKCE code verifier used during the OAuth flow.
pub struct PkcePair {
    pub verifier: String,
    pub challenge: String,
}

/// Generate a PKCE code verifier and its SHA-256 code challenge (base64url-encoded).
pub fn generate_pkce_pair() -> PkcePair {
    let verifier = generate_code_verifier();
    let challenge = sha256_base64url(&verifier);
    PkcePair {
        verifier,
        challenge,
    }
}

/// Execute the full PKCE-based OAuth flow:
/// 1. Bind a local TCP listener on `redirect_port`.
/// 2. Open the browser at the provider's authorization URL.
/// 3. Wait for the callback containing the auth code.
/// 4. Exchange the code for tokens.
///
/// This function blocks until the flow completes or times out.
pub async fn authorize_with_pkce(
    config: &OAuthConfig,
    app_handle: &tauri::AppHandle,
) -> Result<OAuthTokens, String> {
    // 1. Generate PKCE pair
    let pkce = generate_pkce_pair();

    // 2. Build authorization URL
    let redirect_uri = format!("http://localhost:{}", config.redirect_port);
    let auth_url = format!(
        "{}?client_id={}&redirect_uri={}&response_type=code&scope={}&code_challenge={}&code_challenge_method=S256",
        config.auth_url,
        encode(&config.client_id),
        encode(&redirect_uri),
        encode(&config.scopes),
        encode(&pkce.challenge),
    );

    // 3. Start local TCP server to receive callback
    let listener = std::net::TcpListener::bind(format!("127.0.0.1:{}", config.redirect_port))
        .map_err(|e| format!("failed to bind callback port {}: {}", config.redirect_port, e))?;

    listener
        .set_nonblocking(true)
        .map_err(|e| format!("failed to set non-blocking: {e}"))?;

    // 4. Open browser
    open_url(&auth_url, app_handle)?;
    info!("opened browser for OAuth authorization");

    // 5. Wait for callback (with timeout using tokio)
    let listener_port = config.redirect_port;
    let code_result: Result<String, String> = tokio::task::spawn_blocking(move || {
        // Convert to blocking listener
        let listener = std::net::TcpListener::bind(format!("127.0.0.1:{listener_port}"))
            .map_err(|e| format!("failed to rebind: {e}"))?;

        listener
            .set_nonblocking(false)
            .map_err(|e| format!("failed to set blocking: {e}"))?;

        let (mut stream, _) = listener
            .accept()
            .map_err(|e| format!("failed to accept callback connection: {e}"))?;

        // Set read timeout on the accepted stream
        stream
            .set_read_timeout(Some(std::time::Duration::from_secs(120)))
            .map_err(|e| format!("failed to set read timeout: {e}"))?;

        use std::io::{BufRead, BufReader, Write};
        let mut reader = BufReader::new(&mut stream);
        let mut request_line = String::new();
        reader
            .read_line(&mut request_line)
            .map_err(|e| format!("failed to read callback request: {e}"))?;

        // Extract auth code from the request
        let code = extract_auth_code(&request_line)?;

        // Send a success response to the browser
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n\r\n\
            <html><body><h2>Authorization successful!</h2>\
            <p>You can close this tab and return to the Finance App.</p>\
            <script>window.close();</script></body></html>";
        let _ = stream.write_all(response.as_bytes());
        let _ = stream.flush();

        Ok(code)
    })
    .await
    .map_err(|e| format!("OAuth callback task failed: {e}"))?;

    let code = code_result?;

    // 6. Exchange code for tokens
    exchange_code_for_tokens(config, &code, &pkce.verifier).await
}

/// Refresh an expired access token using the stored refresh token.
// TODO: will be used when OAuth token refresh is implemented
#[allow(dead_code)]
pub async fn refresh_access_token(
    config: &OAuthConfig,
    refresh_token: &str,
) -> Result<OAuthTokens, String> {
    let client = Client::new();

    let mut form = vec![
        ("grant_type", "refresh_token"),
        ("refresh_token", refresh_token),
        ("client_id", &config.client_id),
    ];

    let secret_field: String;
    if let Some(secret) = &config.client_secret {
        secret_field = secret.clone();
        form.push(("client_secret", &secret_field));
    }

    let resp = client
        .post(&config.token_url)
        .form(&form)
        .send()
        .await
        .map_err(|e| format!("token refresh request failed: {e}"))?;

    if !resp.status().is_success() {
        let status = resp.status();
        let body = resp.text().await.unwrap_or_default();
        error!(status = %status, body = %body, "Token refresh failed");
        return Err(format!("token refresh failed with status {status}: {body}"));
    }

    let tokens: serde_json::Value = resp
        .json()
        .await
        .map_err(|e| format!("failed to parse refresh response: {e}"))?;

    parse_token_response(&tokens)
}

/// Exchange an authorization code for access/refresh tokens.
async fn exchange_code_for_tokens(
    config: &OAuthConfig,
    code: &str,
    code_verifier: &str,
) -> Result<OAuthTokens, String> {
    let client = Client::new();
    let redirect_uri = format!("http://localhost:{}", config.redirect_port);

    let mut form = vec![
        ("grant_type", "authorization_code"),
        ("code", code),
        ("redirect_uri", &redirect_uri),
        ("client_id", &config.client_id),
        ("code_verifier", code_verifier),
    ];

    let secret_field: String;
    if let Some(secret) = &config.client_secret {
        secret_field = secret.clone();
        form.push(("client_secret", &secret_field));
    }

    let resp = client
        .post(&config.token_url)
        .form(&form)
        .send()
        .await
        .map_err(|e| format!("token exchange request failed: {e}"))?;

    if !resp.status().is_success() {
        let status = resp.status();
        let body = resp.text().await.unwrap_or_default();
        error!(status = %status, body = %body, "Token exchange failed");
        return Err(format!("token exchange failed with status {status}: {body}"));
    }

    let tokens: serde_json::Value = resp
        .json()
        .await
        .map_err(|e| format!("failed to parse token response: {e}"))?;

    parse_token_response(&tokens)
}

/// Parse a token JSON response into OAuthTokens.
fn parse_token_response(tokens: &serde_json::Value) -> Result<OAuthTokens, String> {
    let access_token = tokens
        .get("access_token")
        .and_then(|v| v.as_str())
        .ok_or("no access_token in token response")?
        .to_string();

    let refresh_token = tokens
        .get("refresh_token")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string());

    let expires_in = tokens.get("expires_in").and_then(|v| v.as_i64());

    let expires_at = expires_in.map(|secs| Utc::now().timestamp() + secs);

    Ok(OAuthTokens {
        access_token,
        refresh_token,
        expires_at,
    })
}

/// Extract the authorization code from the callback HTTP request line.
fn extract_auth_code(request: &str) -> Result<String, String> {
    // Parse "GET /?code=XXX&state=YYY HTTP/1.1"
    let url_part = request.split(' ').nth(1).unwrap_or("");
    if let Some(query) = url_part.split('?').nth(1) {
        for param in query.split('&') {
            if let Some(code) = param.strip_prefix("code=") {
                let code = code.trim_end_matches(" HTTP/1.1").to_string();
                if !code.is_empty() {
                    return Ok(code);
                }
            }
        }
    }
    Err("no auth code found in callback request".to_string())
}

/// Generate a random code verifier string (43-128 chars, RFC 7636).
fn generate_code_verifier() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    // Mix in a UUID for extra randomness
    let raw = format!(
        "cv-{}-{}-{}-{}",
        now.as_nanos(),
        uuid::Uuid::new_v4(),
        now.as_millis(),
        now.as_secs()
    );
    // Base64url-encode to get valid characters
    URL_SAFE_NO_PAD.encode(raw.as_bytes())
}

/// Compute SHA-256 hash and return base64url-encoded result.
fn sha256_base64url(input: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(input.as_bytes());
    let hash = hasher.finalize();
    URL_SAFE_NO_PAD.encode(hash)
}

/// Open a URL in the user's default browser.
fn open_url(url: &str, app_handle: &tauri::AppHandle) -> Result<(), String> {
    // On Windows, use cmd /C start
    #[cfg(target_os = "windows")]
    {
        std::process::Command::new("cmd")
            .args(["/C", "start", url])
            .spawn()
            .map_err(|e| format!("failed to open browser: {e}"))?;
    }

    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg(url)
            .spawn()
            .map_err(|e| format!("failed to open browser: {e}"))?;
    }

    #[cfg(target_os = "linux")]
    {
        std::process::Command::new("xdg-open")
            .arg(url)
            .spawn()
            .map_err(|e| format!("failed to open browser: {e}"))?;
    }

    let _ = app_handle; // used in other potential implementations
    Ok(())
}

/// Get the OAuth configuration for a given provider.
///
/// Client IDs are stored in the `cloud_settings` table.
/// For now, returns a default config with empty client_id that must be configured by the user.
pub fn get_oauth_config(provider: &str, client_id: &str, client_secret: Option<&str>) -> OAuthConfig {
    match provider {
        "dropbox" => OAuthConfig {
            client_id: client_id.to_string(),
            client_secret: client_secret.map(|s| s.to_string()),
            auth_url: "https://www.dropbox.com/oauth2/authorize".to_string(),
            token_url: "https://api.dropboxapi.com/oauth2/token".to_string(),
            scopes: "files.content.write files.content.read".to_string(),
            redirect_port: 8401,
        },
        "google_drive" => OAuthConfig {
            client_id: client_id.to_string(),
            client_secret: client_secret.map(|s| s.to_string()),
            auth_url: "https://accounts.google.com/o/oauth2/v2/auth".to_string(),
            token_url: "https://oauth2.googleapis.com/token".to_string(),
            scopes: "https://www.googleapis.com/auth/drive.file".to_string(),
            redirect_port: 8402,
        },
        "onedrive" => OAuthConfig {
            client_id: client_id.to_string(),
            client_secret: client_secret.map(|s| s.to_string()),
            auth_url: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize".to_string(),
            token_url: "https://login.microsoftonline.com/common/oauth2/v2.0/token".to_string(),
            scopes: "files.readwrite offline_access".to_string(),
            redirect_port: 8403,
        },
        _ => OAuthConfig {
            client_id: client_id.to_string(),
            client_secret: client_secret.map(|s| s.to_string()),
            auth_url: String::new(),
            token_url: String::new(),
            scopes: String::new(),
            redirect_port: 8410,
        },
    }
}

/// Check if an access token has expired and needs refresh.
// TODO: will be used when OAuth token refresh is implemented
#[allow(dead_code)]
pub fn is_token_expired(expires_at: Option<i64>) -> bool {
    match expires_at {
        Some(exp) => Utc::now().timestamp() >= exp - 60, // 60-second buffer
        None => false, // No expiry info, assume still valid
    }
}
