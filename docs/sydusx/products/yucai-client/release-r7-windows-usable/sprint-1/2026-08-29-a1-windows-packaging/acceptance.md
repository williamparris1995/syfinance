# A1 验收记录 — Windows 打包/安装通路(2026-08-29)

> FR-1..FR-3 自动验证 + FR-4 三判据清单。构建环境:本机(开发机)。

## 自动验证(已执行,证据见 git 历史)

| 项 | 结果 |
|---|---|
| FR-1 `make windows-installer` 单命令源码→安装包 | ✅ exit 0,产物 `client/dist/yucai-setup-1.0.0.exe`(14.4MB,lzma2/max) |
| FR-2 版本戳(pubspec 1.0.0 → 安装包文件名/AppVersion) | ✅ 文件名含版本;卸载入口显示「御财 版本 1.0.0」 |
| FR-2 exe 文件属性 | ✅ Runner.rc 原生读 FLUTTER_VERSION 定义,build 自动戳(无需手工 patch) |
| FR-3 静默安装(/VERYSILENT) | ✅ Inno 日志:文件/图标/注册表全成功;开始菜单在 **Roaming**(`{group}` 解析为 Roaming\...\Start Menu\Programs\御财,含卸载快捷方式);桌面快捷方式按 Task 可选 |
| FR-3 卸载 round-trip | ✅ unins000 /VERYSILENT → 目录/开始菜单/注册表三项全清 |
| per-user 免管理员 | ✅ PrivilegesRequired=lowest,装 LOCALAPPDATA\Programs\yucai |

## FR-4 三判据复验(打包版)

- [ ] ①断网全新安装 → 可启动并记账/看资产(人工,blocked-on-user)
- [ ] ②从不绑定 → 数据一直本地、app 一直可用(人工,blocked-on-user)
- [ ] ③绑定路径冒烟(可选,R6 已 e2e 覆盖)(人工)

## 已知代价与观察(记录在案)

1. **Defender 扫描窗口**:新装的无签名 exe/dll 有 ~10-20 秒实时扫描锁,期间快速文件探针(Test-Path 类)可能 False——非安装故障;等待后自愈。分发给他人时同理,首次运行有 SmartScreen 提示(免签名已知代价,spec scope boundary 已记)。
2. **中文向导**:官方 Unofficial ChineseSimplified.isl 入库(packaging/);Inno 6.7 一条新消息无中文翻译回退英文(日志 Warning,无害)。

## 构建环境备忘(给 sprint-2/3 的教训)

- **worktree 路径长度**:Flutter Windows 插件嵌套路径在 `.claude/worktrees/<id>` 下超 MAX_PATH 260(实测 267)→ C1083 假报头文件缺失。**Flutter-Windows 触碰的 feature 应在短路径 worktree 构建**(如 `C:\sywt\<id>`),或直接在主 checkout 验证构建;junction 无效(Flutter 规范化真实路径)。
- Inno .iss 必须 **UTF-8 BOM + CRLF**(LF-only 会导致 directive 解析错位,报 Unrecognized directive)。
- Git Bash 下 ISCC 的 `/D` 参数需 `MSYS2_ARG_CONV_EXCL="/D"` 防 MSYS 路径转换(Makefile 已内置)。
- Inno directive 名为 `OutputBaseFilename`(非 OutputBaseName)。
