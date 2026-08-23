---
feature: 2026-08-22-archive-export-import
status: drafted
---

# Spec — 存档导出/导入(加密存档文件,多设备迁移/云盘备份)

> R6 sprint-3 feature J(依赖 G;最后一个,R6 收官件)。2026-08-22 fast-lane 立项,2026-08-23 spec 化。
> server 加密格式(wire 事实):`[magic "YC1E" 4B][salt 32B][nonce 12B][AES-256-GCM ciphertext+16B tag]`,scrypt(N=32768,r=8,p=1)派生 32B key;server backup 另统一 gzip。**兼容决策(analysis 裁定 A)**:client 逐字节复刻 server 加密格式——存档跨端可解(本地导入 ✓/server 未来 UploadBackup 密码版可解 ✓/Go 生态可解),云盘存档不锁死在自定格式。

## ADDED Requirements

### Requirement: FR-1 存档导出(密码加密 + file picker)
- [ ] 设置页「导出存档」入口 SHALL:用户输入密码(两次确认)→ 导出(复用 G 的 LocalSnapshotExporter envelope)→ **server 格式加密**(magic YC1E/scrypt 32768/AES-GCM,gzip 内层与 server 一致)→ 系统 file picker 选保存位置(默认名 `yucai-backup-YYYYMMDD-HHmmss.ycb`)。导出过程/结果可见(成功提示含文件路径)。

#### Scenario: 导出并在他处可验
- GIVEN 本地有数据
- WHEN 导出(密码 p)
- THEN 生成 .ycb 文件;格式为 YC1E 头(Go 端 domain.IsEncrypted 判真)

### Requirement: FR-2 存档导入(解密校验 + 全量替换)
- [ ] 设置页「导入存档」入口 SHALL:file picker 选 .ycb → 输入密码 → 解密(gzip→envelope JSON)→ **校验**(magic 不符/损坏→「不是有效的御财存档」;密码错→「密码错误」;version 不符→明确报错)→ 确认对话框(**明示将覆盖本地全部数据**)→ 单事务全量替换本地库(8 契约模块;envelope payload 形态→行映射)。失败任何一步本地库不动。

#### Scenario: 导入覆盖
- GIVEN 存档含 3 账户,本地另有数据
- WHEN 导入(正确密码+确认)
- THEN 本地=存档内容(原数据被替换),条目比对一致

#### Scenario: 密码错误零影响
- WHEN 密码错
- THEN 明确报错,本地库不动

### Requirement: FR-3 错误路径完备
- [ ] 非 YC1E 文件/截断文件/版本不支持 SHALL 各自明确报错(不崩溃/不静默);导入过程异常 SHALL 保证本地库不变(事务)。

### Requirement: NFR-1 质量基线
- [ ] `flutter test` 基线不退化(≤ 4 fail / 3 文件);`flutter analyze` 不新增;分层不倒置;加解密为纯 Dart 可测(不依赖平台插件——file picker 仅 UI 边界)。

### Requirement: NFR-2 零 server 改动
- [ ] 本 feature SHALL NOT 改动 yucai/server;`go test ./...` 保持全绿。

## scope boundary

- **IN**:ArchiveCodec(加密/解密/校验,server 格式复刻)/导入替换器(envelope→行,8 模块)/设置页两入口+密码与确认对话框/file_picker 接入。
- **OUT**:自动定期备份到文件夹(defer,用户手动)/server 端 UploadBackup 密码版对接(存档上云——future,格式已兼容)/存档内敏感字段选择(全量)/i18n。
- **依赖**:G(exporter)/H(deleteAll 系列)/pointycastle(scrypt/AES-GCM)+file_picker(新增依赖)。

## 可行性

- **technical**:可行——pointycastle 有 scrypt 与 AES-GCM;格式四段复刻直白;导入替换器与 G 导出器逆向同构。
- **economic**:小——一个 codec + 一个 importer + 两入口 UI。
- **operational**:可行——密码强度不做强制(v1 提示);文件格式文档随代码注释。
