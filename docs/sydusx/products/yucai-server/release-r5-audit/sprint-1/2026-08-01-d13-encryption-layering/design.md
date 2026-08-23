---
feature: 2026-08-01-d13-encryption-layering
status: confirmed
---

# Design — D13 加密分层 + D19a KDF 版本化

> 消费 [spec.md](spec.md)(confirmed,FR-1 裁定 B)。设计极简(收尾件):单文件 crypto 改造 + 一参数传递 + 一权限位。

## Decisions(ADRs)

### ADR-1 crypto v2 格式与分流(domain/crypto.go)
- v2 帧结构:`[magic "YC2E" 4B][version 1B=2][N 4B LE][r 4B LE][p 4B LE][salt 32B][nonce 12B][ct+tag 16B]`;常量 `v2ScryptN=131072, r=8, p=1`(OWASP)。
- `Encrypt` 写 v2;`Decrypt` 读前 4 字节:`YC1E`→v1(硬编码 2^15 参数)、`YC2E`→v2(读 header 参数校验 bounds: N∈[2^14,2^22]、r∈[1,32]、p∈[1,8],防 DoS 级参数注入)、其他→`ErrBackupFormatOutdated` 同类错误。
- v1 常量保留不删(向后兼容的活文档)。

### ADR-2 safety 加密接线(Service 层)
- `RestoreBackup`:`preRestore, err := s.CreateBackup(ctx, tenantID, password != "", password, true)`——password 非空即 encrypted+同密码(FR-1-B);空→明文维持。加密场景下 safety 解密密码=用户刚用过的密码(在场已知)。
- `UploadExternal`:维持 `CreateBackup(ctx, tenantID, false, "", true)`(R6 路径保持明文,spec accepted)。
- 修复 D6 注释中"unencrypted safety"描述(现分层)。

### ADR-3 0600 权限(LocalProvider)
- `os.WriteFile(path, data, 0600)`;健康探测的 testPath 探测同理收紧。Windows 上 Go 的 FileMode 仅影响 Unix 语义——单机部署目标 Linux/macOS 生效;Windows no-op(记 design 注)。

### ADR-4 加密创建 audit 警告
- CreateBackup encrypted=true 且非 auto 时 slog Info("backup encrypted", "tenant_id", ..., "operation", "EncryptedBackupCreated", "warning", "password loss is unrecoverable")——server 侧审计事件;client 文案 defer。

## 测试计划
- crypto: v2 往返 / v1 兼容解密(用现存测试样本) / v2 参数 bounds 校验 / 错 magic
- safety: 加密 restore 失败后 safety 可用原密码解(集成) / 明文 restore safety 仍明文
- 权限: 写文件后 Stat Mode 0600
- audit: 日志断言(轻量——slog handler 捕获或跳过记 ledger)

## Risks
- v2 参数 DoS(bounds 已设防)
- 0600 在 Windows no-op(接受)
