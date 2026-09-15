# Spec — F24 自动更新全链

> 2026-09-15 R11 立项三决策(新 release/自动+手动 UX/EdDSA)+ 引擎 grill 定案(auto_updater=WinSparkle,英文弹窗用户接受「通用」)。前置事实:origin=github.com/williamparris1995/syfinance;`make windows-installer`(flutter release+ISCC)在;版本号单源 pubspec(Runner.rc 自动跟随)。

## Requirements

- **FR-1 发布流水线**:GitHub Actions workflow(tag `v*` 触发):checkout → flutter build windows --release → ISCC 安装包 → 创建 GitHub Release(附安装包)→ 生成 appcast.xml(条目:版本/安装包 URL/changelog 取 tag 注释)→ **DSA 签名** → appcast 附加到 Release。零手工分发步骤。
- **FR-2 appcast 订阅地址**:`https://github.com/williamparris1995/syfinance/releases/latest/download/appcast.xml`(latest 恒指向最新 Release,URL 稳定)。
- **FR-3 密钥管理**:**DSA(Sparkle 经典 1024-bit)密钥对**一次性生成(`tool/gen_appcast_dsa_key.py`);**私钥**入 GitHub Actions Secrets(`APPCAST_DSA_PRIVATE_KEY`),**公钥** PEM 烤入客户端 `windows/runner/dsa_pub.pem`(WinSparkle `DSAPub` 资源验签)。原裁 EdDSA 被引擎现实推翻:auto_updater 1.0.0 捆绑 WinSparkle 0.8.1 仅支持 DSA(EdDSA 需 0.9+);升级路径清单在 tool/gen_appcast.py 头注与 RELEASE.md。
- **FR-4 客户端接入**:依赖 `auto_updater`(WinSparkle);feed URL 常量;初始化于 bootstrap(附属功能降级不阻断启动);版本识别走 exe VERSIONINFO(=pubspec 单源,零额外对齐)。
- **FR-5 更新 UX**:启动后台自动检查(WinSparkle 调度默认 1 天)+ 手动兼有(菜单项触发 WinSparkle 检查 UI);检查失败静默降级,不影响任何既有功能;更新弹窗为引擎英文 UI(决策记录在案)。
- **FR-6 托盘菜单增项**:「检查更新」(触发检查 UI) + 「御财 vX.Y.Z」版本号展示(disabled 项,值取 pubspec 构建注入);置于数据头之下、显示御财之上。
- **FR-7 发布演练**:真实 tag 走全链(Actions 构建→Release→appcast);旧版安装态真机收到更新提示并升级成功(人工验收,用户参与)。
- **NFR-1 降级**:更新子系统任一环节失败(网络/签名/流水线)不阻断 app 启动与既有功能;手动检查项恒可用。
- **NFR-2 版本单源**:pubspec 为唯一版本事实源(Actions/Runner.rc/appcast 全部派生)。
- **NFR-3 零回归**:全量 `flutter test` + `flutter analyze` 基线一致。

## Scope boundary(排除项 + 辩护)

| 排除 | 理由 |
|---|---|
| Authenticode 安装包签名 | 年费成本;EdDSA 清单签名已覆盖更新链完整性(R11 defer 在案) |
| 更新弹窗中文化 | WinSparkle 引擎 UI 英文硬限制;grill 裁「通用可接受」;将来可加中文 toast 引导壳(backlog) |
| prerelease/灰度通道、差分更新 | 个人量级 YAGNI |
| Linux/macOS 通道 | 产品现役仅 Windows |

## Grill record

| 决策 | 挑战 | 定案 |
|---|---|---|
| 引擎 | 成熟签名链 vs 中文 UI(自研=手写密码学校验) | auto_updater(用户「通用」;英文弹窗接受,中文引导壳 backlog) |
| 归属 | R8 sprint-8 vs 新 release | 新 R11 发布线(用户拍板) |
| 更新 UX | 自动 vs 纯手动 | 自动+手动兼有(用户拍板) |
| 校验档位 | EdDSA vs 无 vs Authenticode | 用户裁 EdDSA;实施中引擎现实(WinSparkle 0.8.1 仅 DSA)降档 DSA,EdDSA 决策保留为升级路径 |
| appcast 托管 | release 资产 vs gh-pages | latest release 资产(URL 稳定零基础设施) |

## Feasibility

技术 ✅(auto_updater 事实标准/Actions 免费/ISCC 已有;**外部依赖**:GitHub Actions 需启用、tag push 权限、真机安装验证);经济 ✅(零成本,EdDSA 免费证书);运营 ✅(密钥管理纪律:私钥仅 Secrets;发布演练为验收面)。
