# 02 · 传输与密钥安全(TLS + JWT 强度 + 撤销 + 轮换)

Type: grilling
Status: resolved
Blocked by: —

## Question

家庭多用户私域下,家人间或 LAN 外部泄露的现实风险(详见 `findings.md` S2/S3/S8/S14):

- **[S2 P0]** gRPC 无 TLS 且绑 `0.0.0.0:9090`(`providers.go:906-914` 无 Creds + `main.go:144-145`):Bearer JWT/refresh/金额明文,同 WiFi 可抓包接管账号。LAN 不是可信信道。
- **[S3 P0]** `JWT_SECRET` 无强度校验(`config.go:14` 仅 required):误填短串可离线爆破 HS256。
- **[S8 P1]** access token 不可撤销 + 无 aud/iss 校验:登出/改密/删 tenant 后 15min TTL 内仍有效。
- **[S14 P2]** 无密钥轮换/kid:轮换强制全员登出。

**决策点:**
1. 传输:server 加 TLS(自签 + 客户端 pin)/ 绑 127.0.0.1 + 反代 TLS / 两者?家庭分发场景哪个可落地?
2. JWT_SECRET 启动强制 ≥32 字节(或 SHA-256 派生)+ warn?
3. access token 撤销:Redis jti blacklist vs 缩短 TTL?Parser 补 `WithAudience("yucai")` + `WithIssuer`?
4. 密钥轮换:`JWT_SECRET_CURRENT` + `JWT_SECRET_PREVIOUS` + kid 是否值得?

## Answer(resolved 2026-07-26)

grilling 决策(4 点):

1. **传输(S2 P0)**:server 加 **自签 TLS**(启动生成/读自签证书,gRPC 启用 `grpc.Creds`)+ **客户端 pin 证书指纹**(防 LAN 中间人)。家庭 LAN 多设备安全访问,不需 CA/域名。绑定的 `0.0.0.0:9090` 改为证书保护(或保留 0.0.0.0 但 TLS 加密)。
2. **JWT_SECRET 强度(S3 P0)**:config 启动**强制 ≥32 字节**,`<32` 拒绝启动 + 清晰错误。防 HS256 离线爆破。
3. **access token 撤销(S8 P1)**:**Redis jti blacklist**。token 加 `jti` claim,登出/改密/删 tenant 时加入 blacklist,AuthInterceptor 查 Redis 拒绝黑名单 jti。Redis 已可用(refresh token 层)。Parser 补 `WithAudience("yucai")` + `WithIssuer(cfg.Issuer)`。
4. **密钥轮换(S14 P2)**:**单密钥**(不引入 kid/双密钥)。轮换时强制全员重登(家庭不频繁轮换,接受中断)。

**实施分阶段**:
- 密钥安全(JWT ≥32 + Redis jti blacklist + aud/iss):server 端,不涉 client。独立。
- TLS(server 自签证书 + Flutter gRPC channel TLS + 客户端 pin 配置 + 证书分发流程):跨端大改。

## Implementation(2026-07-26)

**密钥安全已实施**(commit 本地 main):
- JWT_SECRET ≥32 reject(config 启动校验,<32 拒绝 + openssl 提示)+ `JWT_ISSUER` 配置(默认 `yucai-server`)
- access token 加 `jti`(UUID)+ `aud='yucai'` + `iss` claims;`ParseAccessTokenClaims` 强校验 `WithAudience`/`WithIssuer`
- Redis jti blacklist(`jwt:blacklist:<jti>`,TTL=剩余 exp);AuthInterceptor **fail-closed**(lookup error→Unavailable,hit→Unauthenticated)
- `Service.Logout` + `RefreshToken` 旋转接入加黑;`ParseAccessTokenJTI` 用于触发点取 jti+exp(不强校验 aud/iss,因 token 已认证)
- `NewTokenService` 加 issuer 参数;wire 手维护(`provideTokenBlacklist` + 透传)
- 全包测试绿(含 5 新 middleware 测试 + config/service 测试)

**Follow-up(留后续)**:
- TLS(server 自签证书 + Flutter gRPC channel TLS + 客户端 pin)— 跨端大改
- proto `Logout` RPC + client 发 Bearer on refresh(激活 `Service.Logout` 端到端)
- miniredis(Redis 层 e2e 测试)
- kid/双密钥(单密钥决策,不做)
