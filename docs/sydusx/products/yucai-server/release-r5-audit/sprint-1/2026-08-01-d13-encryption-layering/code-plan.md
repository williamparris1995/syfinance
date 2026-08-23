# Code Plan — D13 加密分层 + D19a KDF 版本化

- [x] T1 crypto v2(YC2E 自描述 header[N/r/p 4B LE×3]+默认 2^17/8/1;Decrypt 按 magic 分流;bounds 校验防 DoS 参数;IsEncrypted 识别双 magic——首版漏致既有测试挂)+ 测试 ×4(v2 格式/往返/v1 兼容解密/bounds 拒)
- [x] T2 safety 加密接线(RestoreBackup 的 pre-restore CreateBackup 改 password!=""+password;UploadExternal 维持明文[spec accepted])+ 测试(加密 restore 后 safety 带 YC2E magic)
- [x] T3 0600(LocalProvider 写入与探测 0644→0600)
- [x] T4 audit 警告(加密创建 slog Info "password loss is unrecoverable")
- [x] T5 go test 61 包全绿

## 执行记录(2026-08-23)
- IsEncrypted 首版只查 YC1E——Encrypt 已写 YC2E 后所有加密路径的 magic 判定失效(既有测试 IsEncrypted(files) 挂→修复双 magic)。v1Blob 测试助手手工构造旧格式(Encrypt 只写 v2)。
