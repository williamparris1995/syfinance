# Design — F24 自动更新全链

**prototype: none**(新应用内 UI 为零——更新弹窗为 WinSparkle 引擎 UI(英文,决策在案),托盘菜单项为纯文本;无新屏无新组件)

## Context

[spec.md](spec.md)。事实:origin GitHub;`make windows-installer`(flutter release+ISCC,版本自 pubspec);Runner.rc 版本自动跟随 pubspec;F25 后托盘菜单=数据头×2+分隔+记一笔+显示御财+退出,`buildContextMenu` 单一事实源。

## Goals / NonGoals

- **Goals**:tag→构建→Release→签名 appcast→客户端发现并升级,零手工;版本恒单源 pubspec。
- **NonGoals**:见 spec 排除表(Authenticode/中文化弹窗/多通道/差分)。

## Decisions(ADR)

### ADR-1 引擎 = auto_updater(WinSparkle)
- **理由**:Flutter Windows 事实标准;EdDSA 验签引擎内置(不在理财 app 里手写密码学);下载续传/调度/安装流久经考验。
- **备选**:自研(中文 UI 但手写 ed25519 验证+续传+调度,风险>收益;grill 用户裁「通用」)。
- **代价接受**:英文更新弹窗;随包 WinSparkle DLL(CMake 步骤接入)。

### ADR-2 流水线 = 单 workflow 文件(tag 触发)+ 站内脚本复用
- `.github/workflows/release.yml`:on push tags `v*`;job:checkout(submodules 无)→ setup-flutter → `flutter build windows --release` → ISCC(装 Inno Setup via choco)→ `gh release create`(安装包)→ appcast 生成(py 脚本,版本/tag 注释→XML)→ EdDSA 签名(auto_updater 官方签名工具或 python 等价,私钥自 Secrets)→ 附加 appcast 到 Release。
- **版本派生**:workflow 从 tag ref 提取版本(与 pubspec 校验一致性,不一致 fail-fast——版本单源守护)。

### ADR-3 密钥 = EdDSA 密钥对一次性脚本生成
- `tool/gen_appcast_eddsa_key.py`(或 auto_updater CLI):产 `.eddsa` 密钥对;私钥仅入 GitHub Secrets(文档注明**不得入库**);公钥入 `windows/runner` 配置(WinSparkle feeds 验签公钥参数,auto_updater 接入步骤)。

### ADR-4 客户端接入 = bootstrap 附属降级
- bootstrap 末尾 try/catch 初始化 auto_updater(setFeedURL+公钥);失败仅记 print 降级(通知域既有容错先例);手动检查=托盘菜单项→WinSparkle 检查 UI。

### ADR-5 托盘菜单 = F25 单一事实源扩展
- `buildContextMenu` 增:「检查更新」(enabled,action→引擎检查)+「御财 vX.Y.Z」(disabled;版本自 `package_info_plus` 或构建常量——**pubspec 派生**);置于数据头之下。

## HLD

```
.github/workflows/release.yml          # FR-1 流水线(ADR-2)
yucai/client/tool/gen_appcast.py       # appcast 生成+签名(Actions 内跑;本地可 dry-run)
yucai/client/tool/RELEASE.md           # 密钥/Secrets/发布操作手册(用户可重复)
yucai/client/windows/...               # WinSparkle CMake 接入(auto_updater 文档步骤)
yucai/client/lib/core/notifications/tray_controller.dart   # 菜单两新项(FR-6)
yucai/client/lib/main.dart 或 bootstrap                  # auto_updater 初始化(FR-4/5)
```

## LLD 关键流程

- appcast XML:sparkle 规范(`sparkle:edSignature` + 版本 + url 指向本 Release 安装包资产 URL);生成脚本输入(tag/notes/资产 URL)输出签名 XML。
- 版本一致性守护:workflow 步骤比对 tag 与 pubspec version,不符 exit 1。
- 托盘 action:检查更新→`AutoUpdater.instance.checkForUpdates()`(引擎 UI);版本项 label 由 `PackageInfo.fromPlatform` 异步取后并入 `_refreshMenu` 数据流(或构建期 dart-define 注入,二选一实现时定,倾向 PackageInfo 零构建耦合)。
- 测试面:菜单项枚举/版本 label 组装/AutoUpdater 初始化降级(channel mock)/appcast 生成脚本单测(python:XML 结构+签名存在性,签名字节级验证用公钥侧脚本);workflow 全链只能发布演练验证(FR-7)。

## Risks

| 风险 | 缓解 |
|---|---|
| GitHub Actions 未启用/权限 | 演练首跑前用户在 repo Settings 确认(操作手册) |
| auto_updater 包成熟度(DLL/CMake 步骤版本漂移) | 锁版本;演练真机验证安装+升级 |
| 私钥泄漏 | 仅 Secrets;手册明令不入库不入日志 |
| tag 版本与 pubspec 漂移 | workflow fail-fast 守护 |

## Migration

纯新增;未发布前检查更新静默无更新(feed 404 降级)。

## Open Questions

- PackageInfo vs dart-define 版本注入(LLD 二选一,实现时定)。
- WinSparkle 检查 UI 的调度间隔默认(1 天)是否可配(auto_updater setScheduledCheckFrequency)——默认即可,记录。
