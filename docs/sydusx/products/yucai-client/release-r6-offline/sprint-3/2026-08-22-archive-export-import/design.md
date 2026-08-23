---
feature: 2026-08-22-archive-export-import
status: confirmed
---

# Design — 存档导出/导入

> 消费 [spec.md](spec.md)(confirmed,兼容裁定 A)。server 格式锚点:`[YC1E 4B][salt 32B][nonce 12B][AES-256-GCM ct+tag]`,scrypt(32768,8,1,32);server backup 统一 gzip(envelope JSON 为明文层)。

## Decisions(ADRs)

### ADR-1 `ArchiveCodec`(backup/data/,纯 Dart)
- encrypt(bytes, password) → gzip(bytes) → YC1E 四段装帧;decrypt(bytes, password) → 拆帧(salt/nonce/ct) → scrypt key → GCM open → gunzip;错误分类:NotArchiveError(magic/长度)/WrongPasswordError(GCM 认证失败)/FormatError(gzip/envelope 层)。依赖 pointycastle(scrypt + AES-GCM)+ dart:io gzip(codec 层用 GZipCodec,纯 Dart 可测)。
### ADR-2 `ArchiveImporter`(backup/data/)
- importAll(db, envelopeJson):8 模块 envelope payload(server 形态:PascalCase/int 枚举)→行映射→单 drift 事务 deleteAll×8+插入。映射=**G 导出器的逆向**(snake↔PascalCase 已在 G 做;此处 PascalCase→drift 行)。复用 H 的 deleteAll 系列。
### ADR-3 UI 接线(设置页两入口)
- 导出:对话框(密码×2)→ codec → FilePicker.platform.saveFile(默认名);导入:pickFiles → 密码对话框 → codec 解密 → 确认覆盖对话框 → importer → 结果 snackbar。bloc 化从轻(ArchiveBloc 极简三态)——直接 StatefulWidget 局部状态(收口件,YAGNI)。
### ADR-4 依赖
- pointycastle + file_picker 加入 pubspec。

## 测试计划
- codec 往返(encrypt→decrypt==原)/错误三分类/与 Go 格式样本对拍(内嵌一个 Go Encrypt 输出样本 hex 作 fixture——跨语言 wire 真实样本,I 轮教训)
- importer:envelope 样本→库替换(8 模块计数+抽查);坏 payload 事务回滚(本地不动)
- 设置页入口存在性(widget 测试轻量)

## Risks
- scrypt 参数对拍(N=32768 内存 32MB,移动端可接受;测试用同参)
- file_picker 桌面(Win)支持 saveFile ✓(桌面目标平台)
