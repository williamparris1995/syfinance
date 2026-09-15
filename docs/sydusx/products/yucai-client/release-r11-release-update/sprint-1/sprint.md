# Sprint 1 — R11 F24 自动更新全链

> /sydusx-portfolio(2026-09-15)。来源:sprint-7 defer 激活;用户三决策(新 R11/自动+手动/EdDSA)。

## Sprint Goal

tag 推送 → GitHub Actions 自动构建 Inno 安装包 → Release + 签名 appcast → 已装客户端自动发现新版本并一键升级——零手工分发步骤。

## Feature roster

- [x] **feature F24** auto-update — 发布流水线(Actions workflow:tag → build+ISCC → Release+appcast 生成/EdDSA 签名/密钥 Secrets 管理)+ 客户端(auto_updater 接入+appcast URL 常量+启动自动检查+托盘菜单「检查更新」「版本号」项)+ 发布演练(真 tag 走全链+旧版升级验证) ✅ 代码面 done(2026-09-15,merge `021cd2d9`[fast-forward];双轴评审过+1679 全绿;签名档位 EdDSA→DSA 引擎现实在案;S5 发布演练待真钥+真 tag——runbook: yucai/client/tool/RELEASE.md)

## defer

- Authenticode 证书(成本)
- Linux/macOS 通道、prerelease 通道、差分更新
- 更新弹窗中文化(取决于引擎选型,spec 裁)

## status: active(S1-S4 done;S5 发布演练=用户外部步骤)
