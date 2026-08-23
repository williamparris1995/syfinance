---
feature: 2026-08-01-d13-encryption-layering
status: drafted
---

# Spec — D13 加密分层 + D19a scrypt 版本化 KDF header

> R5 sprint-1 feature D(依赖 B✓;audit 04 决策点 4 + D19a,最后一个,sprint-1 收官件)。
> 现状事实:safety backup `CreateBackup(ctx, tenantID, false, "", true)`(service.go:146)与 auto backup(scheduler.go:152)都是**明文**;LocalProvider 写文件 0644(local.go:27);crypto.go v1 格式 `[YC1E][salt 32B][nonce 12B][AES-GCM ct+tag]` scrypt N=32768(2^15) 无版本自描述;**R6 J 的 client ArchiveCodec 逐字节复刻此格式**(contract 耦合点)。

## ADDED Requirements

### Requirement: FR-1 safety backup 用户密码加密
- [ ] RestoreBackup 与 UploadExternal 创建的 pre-restore safety backup SHALL 用**用户密码加密**而非明文:RestoreBackup 复用调用方已传的 `password`(加密备份 restore 时即解密密码;明文备份 restore 时 SHALL 要求非空 safety 密码——proto 已有字段,语义扩展见 FR-2);UploadExternal 复用其 `password` 字段(现状 client 传空——safety 加密后空密码=明文 safety,**该路径 SHALL 保持明文**(R6 绑定上云的 safety 是防御纵深,client 无人为错误恢复诉求,记 accepted;password 字段留给未来)。

#### Scenario: 加密备份的 restore,safety 同密码加密
- GIVEN tenant 有一份密码加密备份 P(pw=secret)
- WHEN RestoreBackup(P, password=secret)
- THEN pre-restore safety backup 以 secret 加密(encrypted=true);restore 成功后 safety 删除;**restore 失败后留存的 safety 须用 secret 才能解**——人为错误回滚路径保密码强度

#### Scenario: 明文备份的 restore 需 safety 密码
- GIVEN tenant 有一份明文备份 P
- WHEN RestoreBackup(P, password="")(现状调用形态)
- THEN SHALL 拒绝并提示需要 safety 密码?或 SHALL 以 password 参数为 safety 密码(空=明文 safety 维持)?

**决策点(待用户裁定,推荐 B)**:
- A. 明文 restore 时 server 拒绝空 password(强制 client 改造——proto 语义收紧,R6 J 导入对话框已收集密码可复用,但 R5 server-only scope 外溢)。
- **B(推荐)**:password 非空→safety 加密;password 空→safety 明文维持(现状)——audit 原文针对的 D6 safety 是"加密备份 restore 时的明文 safety"(那时用户已证明在场且有密码);明文备份本身已是用户的明文选择,其 safety 明文与用户已有选择一致。零 client 改动,语义自洽。

### Requirement: FR-2 proto 字段语义(零 breaking)
- [ ] 现有字段复用,SHALL NOT 新增 proto 字段:`RestoreBackupRequest.password`(restore 解密密码 + 兼作 safety 加密密码,FR-1-B);`CreateBackupRequest.password`(手动加密备份,现状已支持)。

### Requirement: FR-3 auto backup 维持明文 + 0600 + 标注
- [ ] scheduler 的 auto backup SHALL 维持明文(server 无密码,不引入 DEK——audit 决策);LocalProvider 写文件 SHALL 强制 **0600** 权限(现 0644);BackupDTO.encrypted=false 且 auto=true 的组合即「自动备份·未加密·仅本机」标注依据(**client UI 标注 defer**——client 侧小步任务,server 先把数据面备齐:DTO 已有 encrypted+auto 字段,零 proto 改动)。
- [ ] **文件权限应用于所有 backup 文件写入**(明文与加密同 0600——统一收紧,不留弱权限面)。

### Requirement: FR-4 D19a scrypt N 2^17 + 版本化 KDF header
- [ ] crypto Encrypt SHALL 写 **v2 自描述格式**:`[magic "YC2E" 4B][version 1B=2][N 4B LE][r 4B LE][p 4B LE][salt 32B][nonce 12B][AES-GCM ct+tag]`,默认参数 N=2^17(131072)、r=8、p=1(OWASP 2024)。
- [ ] Decrypt SHALL 按 magic 分流:`YC1E`→v1 路径(硬编码 N=2^15,兼容所有现存加密备份);`YC2E`→v2 路径(从 header 读 N/r/p)。两者之外→非备份格式错误。
- [ ] KDF 参数变更 SHALL 仅影响 Encrypt 的新文件;存量 v1 备份的 restore 永远可解(向后兼容硬约束)。

### Requirement: FR-5 加密强警告(D19b defer 的替代)
- [ ] CreateBackup 加密路径(encrypted=true 且非 auto)SHALL 在响应/日志中携带「密码丢失不可恢复」警告语义——server 侧记 audit 日志(加密备份创建事件+警告);client 对话框文案属 client 任务(defer 记)。D19b recovery code 维持 defer(map P2 backlog)。

### Requirement: NFR-1 质量基线
- [ ] `go test ./...` 全绿;crypto v2 往返+ v1 兼容解密 + 参数边界单测;safety 加密集成测试(加密 restore 后 safety 须密码可解);0600 权限测试。

### Requirement: NFR-2 scope 排除项
- [ ] SHALL NOT 做:D19b recovery code / server-held DEK / client UI 改造(标注+警告文案+明文 restore 密码收集——defer client 任务)/ maintenance mode。

## scope boundary

- **IN**:safety 加密(FR-1-B 语义)/0600/crypto v2 header+分流/audit 日志警告。
- **OUT**:client 适配(标注/警告/密码收集——记 R6 defer 清单+contract drift 标注)/D19b/DEK。
- **依赖**:B✓(restore 原子+UploadExternal)。
- **Contract drift 标注**:crypto v2 后,server 新建加密备份为 YC2E 格式;R6 J 的 client ArchiveCodec 当前仅解 YC1E——**client 侧 J codec 需补 v2 解码**(否则 client 导入不了 server 新建的加密备份;client 自导的 YC1E 仍可解)。此为已知 drift,记 client defer 任务。

## 可行性

- **technical**:可行——crypto.go 单文件改造+分流;0600 一行;safety 一参数。v1 兼容有既有测试样本。
- **economic**:小。
- **operational**:0600 收紧对单机无影响(单用户进程)。
