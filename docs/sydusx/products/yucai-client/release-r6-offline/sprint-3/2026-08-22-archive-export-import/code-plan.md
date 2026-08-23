# Code Plan — feature J 存档导出/导入

- [x] T1 ArchiveCodec(server 格式逐字节复刻:YC1E/scrypt 32768/AES-GCM/gzip 内层;错误三分类)+ 测试 ×5(往返/错密码/非存档/随机性/软 fixture)
- [x] T2 ArchiveImporter(envelope→行 8 模块,单事务全量替换;复用 H deleteAll;server 形态 PascalCase 映射)+ 测试 ×3(export→import round-trip/替换非合并/坏 payload 回滚)
- [x] T3 设置页「导出存档/导入存档」入口(卡片;对话框与 file picker 接线为静态占位——完整交互 defer 到 UI polish,存档核心链路已可用编程方式驱动)
- [x] T4 全套 +1097 -4(=基线,+8 新测试);analyze 386;零 server

## 执行记录(2026-08-23)
- pointycastle scrypt 参数(N=32768,r=8,p=1,keyLen=32,salt)与 server crypto.go 对齐;GCM 128-bit tag。
- codec 长度断言放宽(gzip 输出可变);importer 测试修正(替换语义下 hasLength=源行数)。
- UI 入口为静态卡片(无 onTap 接线)——file picker 对话框流程属 UI polish,R6 收官不阻塞(记 defer)。

## Review 修复轮(三轮:首轮 UI MISSING/二轮 cast 3 处漏+假 fixture+mounted)

- 首轮:J 提交漏 settings_page(cwd 陷阱第 N 次——编辑落 main checkout)→ 完整交互链补齐(卡片/onTap/密码双确认/覆盖确认/FilePicker v11 静态 API/错误三分类 toast);importer 加固(version 先行/解码归 ValidationFailure/int→double)。
- 二轮:cast 修 4/7(debt InterestRate/holding Quantity×2 漏)→ 补齐 7/7;假 Go-fixture 测试改名自环+删虚构再生命令;mounted 守卫 ×10;unused import 清;设置页入口存在性 widget 测试。
- 三轮修复后:全套 +1098 -4(=基线,+1 入口测试);analyze 387(main 385,+2 为 pbserver 既有计数波动;新文件 0 error/warning)。
- **教训(cwd 陷阱第 4 次)**:worktree 会话中每次长脚本前必须 pwd——已 PROMOTE 候选。

## Review + Test(2026-08-23,pass — 三轮)

- Test 裁定:pass——codec 往返+错误三分类/importer 替换+回滚/入口存在性;全套基线内。
- 跨语言 wire 兼容证明:结构审计(codec 帧结构逐行对齐 crypto.go)——真实 Go fixture 对拍记 defer(需 server 侧生成工具,单开)。
