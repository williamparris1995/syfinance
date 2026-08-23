# Code Plan — D13 加密分层 + D19a KDF 版本化

- [x] T1 crypto v2(YC2E 自描述 header[N/r/p 4B LE×3]+默认 2^17/8/1;Decrypt 按 magic 分流;bounds 校验防 DoS 参数;IsEncrypted 识别双 magic——首版漏致既有测试挂)+ 测试 ×4(v2 格式/往返/v1 兼容解密/bounds 拒)
- [x] T2 safety 加密接线(RestoreBackup 的 pre-restore CreateBackup 改 password!=""+password;UploadExternal 维持明文[spec accepted])+ 测试(加密 restore 后 safety 带 YC2E magic)
- [x] T3 0600(LocalProvider 写入与探测 0644→0600)
- [x] T4 audit 警告(加密创建 slog Info "password loss is unrecoverable")
- [x] T5 go test 61 包全绿

## 执行记录(2026-08-23)
- IsEncrypted 首版只查 YC1E——Encrypt 已写 YC2E 后所有加密路径的 magic 判定失效(既有测试 IsEncrypted(files) 挂→修复双 magic)。v1Blob 测试助手手工构造旧格式(Encrypt 只写 v2)。

## Review + Test(2026-08-23,pass — 两轮)

- 首轮无 HARD(8 JUDGEMENT:1 Important[decryptV1 截断 panic——v2 有守卫 v1 漏的不对称,IsEncrypted 同款教训重演:改一处漏一处]+NFR-1 两缺口[vacuous safety 测试——成功 restore 后 safety 已删循环空转/缺 0600 测试])→ 修复(守卫/乘积帽/哨兵/audit 时机/真实 safety 链[failingImport→留存→同密码解密→Decompress→payload 断言]/perm_test[Windows skip——FileMode no-op])→ 复审 **pass**。
- Test 裁定:pass——61 包全绿;crypto(v2 格式/往返/v1 兼容经公共分发/bounds 独立+乘积帽/截断不 panic)/safety(真实链)/0600(Unix 断言)。
- **Contract drift 记档**:client R6 J codec 需补 YC2E 解码(defer 任务——server 新建加密备份已 v2,client 自导 YC1E 仍可解)。
- **教训**:"改动+分流"模式的双分支必须对称验证(v1 守卫漏=IsEncrypted 同款;双 magic/双路径改动 grep 两个分支的守卫)。
