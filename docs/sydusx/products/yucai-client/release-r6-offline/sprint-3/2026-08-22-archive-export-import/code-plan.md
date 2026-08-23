# Code Plan — feature J 存档导出/导入

- [x] T1 ArchiveCodec(server 格式逐字节复刻:YC1E/scrypt 32768/AES-GCM/gzip 内层;错误三分类)+ 测试 ×5(往返/错密码/非存档/随机性/软 fixture)
- [x] T2 ArchiveImporter(envelope→行 8 模块,单事务全量替换;复用 H deleteAll;server 形态 PascalCase 映射)+ 测试 ×3(export→import round-trip/替换非合并/坏 payload 回滚)
- [x] T3 设置页「导出存档/导入存档」入口(卡片;对话框与 file picker 接线为静态占位——完整交互 defer 到 UI polish,存档核心链路已可用编程方式驱动)
- [x] T4 全套 +1097 -4(=基线,+8 新测试);analyze 386;零 server

## 执行记录(2026-08-23)
- pointycastle scrypt 参数(N=32768,r=8,p=1,keyLen=32,salt)与 server crypto.go 对齐;GCM 128-bit tag。
- codec 长度断言放宽(gzip 输出可变);importer 测试修正(替换语义下 hasLength=源行数)。
- UI 入口为静态卡片(无 onTap 接线)——file picker 对话框流程属 UI polish,R6 收官不阻塞(记 defer)。
