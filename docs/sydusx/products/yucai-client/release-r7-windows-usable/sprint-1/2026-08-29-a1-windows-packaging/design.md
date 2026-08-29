# Design — A1 windows-packaging(R7 sprint-1 feature A)

> 消费 [spec.md](./spec.md);工具型 feature,薄 design——实施决策与环境教训(详录 [acceptance.md](./acceptance.md))。

## Decisions

- **ADR-1 Inno Setup 免签名自用**(spec grill #1)。形态:per-user(PrivilegesRequired=lowest,{localappdata}\Programs)、中文向导(Unofficial ChineseSimplified.isl 入库)、开始菜单+可选桌面+卸载入口、lzma2/max。
- **ADR-2 版本戳零手工**:windows/runner/Runner.rc 原生支持 FLUTTER_VERSION 预处理定义,`flutter build windows --release` 自动从 pubspec 戳 exe 属性;仅 .iss 侧经 `/DAppVersion` 由 Makefile 从 pubspec 提取注入。
- **ADR-3 Makefile 单命令**:`windows-installer` = flutter release build → ISCC(含 MSYS2_ARG_CONV_EXCL 防 /D 路径转换);产物 `client/dist/`(gitignore)。

## HLD/LLD 要点

- `yucai/client/packaging/yucai.iss`(UTF-8 BOM + CRLF,Inno 硬要求)+ `ChineseSimplified.isl`;AppId GUID `5a7d9db0-…`(固定,升级语义)。
- `yucai/Makefile` 增 target + ISCC 路径(`$(LOCALAPPDATA)/Programs/Inno Setup 6/ISCC.exe`,winget JRSoftware.InnoSetup 装于 per-user)。

## Risks / 教训(给后续 feature)

| 项 | 记录 |
|---|---|
| worktree 路径 >MAX_PATH | Flutter Windows 构建须短路径(acceptance 备忘);junction 被 Flutter 规范化,无效 |
| Defender 扫描窗口 | 无签名新二进制 ~10-20s 锁,快速探针假阴性;等窗口过再验 |
| SmartScreen | 未签名安装包首次运行警告(已知代价,scope boundary) |

## Migration

无(纯新增打包资产;Dart/Go 代码零改动)。
