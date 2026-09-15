# R11 · 发布与更新(release-update)

> 立项 2026-09-15(sprint-7 defer 项激活;用户拍板:新 release/自动+手动更新/EdDSA 签名)。
> 前序:R8 设计系统线 sprint-7 收官(功能 done,真机验收待用户);R9/R10 done。

## Goal

御财客户端获得可持续的**分发能力**:tag → 自动构建 → GitHub Release → 客户端自动检查更新并一键安装的完整闭环,更新链路 EdDSA 签名防投毒;版本号纪律单源(pubspec)。

## Scope

### IN
- **F24 自动更新**(sprint-1):发布流水线(GitHub Actions:tag → flutter build + Inno 安装包 → Release + appcast.xml 生成与 EdDSA 签名)+ 客户端更新(auto_updater 接入/appcast 订阅/启动自动检查+托盘菜单「检查更新、版本号」)。
- 发布演练:真实 tag 走一遍全链(含旧版→新版升级验证)。

### OUT / Defer
- Authenticode 安装包签名(年费成本;EdDSA 清单签名已覆盖更新完整性)
- Linux/macOS 通道(产品现役仅 Windows)
- 增量/差分更新(个人量级无必要)
- 灰度/prerelease 通道(YAGNI)

## 状态

- 2026-09-15 **sprint-1 立项**:F24 自动更新(全链)。[sprint-1](sprint-1/sprint.md)
