# Feature — F24 自动更新全链(R11 sprint-1)

> 2026-09-15 sprint-7 defer 激活;用户三决策(新 R11/自动+手动更新/EdDSA 清单签名)。

## Description

现状:发布靠本地 `make windows-installer` 手工构建,用户(含未来多设备)无更新通道——每次升级需手工替换 exe。目标:tag → GitHub Actions 自动构建 → Release(安装包+签名 appcast.xml)→ 客户端 auto_updater(WinSparkle)自动检查+手动菜单兼有,一键下载安装;EdDSA 签名防更新源投毒;版本号恒单源 pubspec(Runner.rc 已自动跟随)。

## Stories

- [ ] S1: GitHub Actions workflow(tag 触发:checkout→flutter build windows→ISCC→创建 Release 传安装包)
- [ ] S2: appcast.xml 生成 + EdDSA 签名(私钥 Secrets/公钥入客户端;URL=releases/latest/download/appcast.xml)
- [ ] S3: 客户端 auto_updater 接入(依赖+feed URL+版本常量对齐+初始化)
- [ ] S4: 托盘菜单「检查更新」项 + 版本号展示(grill 定形态)
- [ ] S5: 发布演练(真 tag 全链 + 旧版安装→新版升级真机验证)

## Keywords

`自动更新` `auto-update` `auto_updater` `winsparkle` `appcast` `github-actions` `发布流水线` `release` `检查更新` `版本号` `eddsa`
