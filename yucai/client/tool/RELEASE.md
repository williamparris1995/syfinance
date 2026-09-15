# 御财发布操作手册(RELEASE.md)

> F24 自动更新全链的**用户可重复**操作手册(spec FR-1/2/3/7;design ADR-2/3)。
> 设计文档:`docs/sydusx/products/yucai-client/release-r11-release-update/sprint-1/2026-09-15-auto-update/{spec.md,design.md}`

## 0. 链路总览

```
git push tag vX.Y.Z
      │
      ▼  .github/workflows/release.yml(GitHub Actions,全自动)
checkout → 版本一致性守护(tag vs pubspec,不符 fail-fast)
        → flutter build windows --release
        → Inno Setup 6 打安装包(client/dist/yucai-setup-X.Y.Z.exe)
        → gh release create(安装包上传;说明 = tag 注释)
        → tool/gen_appcast.py(生成 appcast.xml + DSA 签名,私钥来自 Secrets)
        → appcast.xml 附加到 Release
      │
      ▼
客户端(WinSparkle)订阅稳定地址,发现新版 → 下载验签 → Inno 安装
```

- **客户端订阅地址(FR-2,恒指向最新 Release,永不变)**:

  ```
  https://github.com/williamparris1995/syfinance/releases/latest/download/appcast.xml
  ```

- 版本单源(NFR-2):`yucai/client/pubspec.yaml` 的 `version: X.Y.Z+N` 是唯一事实源;
  tag 取 `X.Y.Z`(+N 构建号不进 tag,与 `yucai/Makefile` windows-installer 口径一致),
  exe VERSIONINFO(Runner.rc)与 appcast 版本全部由此派生。

## 1. 前置依赖

| 依赖 | 用在哪 | 说明 |
|---|---|---|
| python 3.9+ | 本机跑 tool/ 两个脚本 | Actions runner 已预装,无需自备 |
| `cryptography` | 经典 DSA(1024-bit + SHA-1)签名/密钥生成 | 本机 `pip install cryptography`;Actions 内 workflow 已显式安装 |
| git + GitHub 仓库写权限 | 打 tag / 配 Secrets | origin = github.com/williamparris1995/syfinance |

两个脚本可随时自检(零副作用,不触真实密钥):

```
cd yucai/client
python tool/gen_appcast.py --self-test
python tool/gen_appcast_dsa_key.py --self-test
```

## 2. 首次设置(一次性)

> **为何 DSA 而非 EdDSA(决策注记,2026-09-15 修订)**:spec/design 原裁
> EdDSA(ed25519,更现代);集成验证发现 **auto_updater 1.0.0 捆绑的
> WinSparkle 0.8.1 只支持经典 DSA 验签**(exe 公钥资源 DSAPub/DSAPEM +
> appcast `sparkle:dsaSignature`),EdDSA(`sparkle:edSignature`)需
> WinSparkle 0.9+。经用户裁决,签名档位降 DSA 匹配引擎。
> 升级引擎(auto_updater/WinSparkle ≥0.9)后切回 EdDSA 清单:
> 1. `gen_appcast.py`:`sparkle:dsaSignature` 改回 `edSignature`,签名实现
>    DSA-SHA1/PEM 改回 Ed25519/base64(密钥工具恢复 EdDSA 语义并更名);
> 2. `release.yml` 与本手册:`APPCAST_DSA_PRIVATE_KEY` 改回
>    `APPCAST_EDDSA_PRIVATE_KEY`,客户端公钥改回 EdDSA 常量接入。

### 步骤 1:生成 DSA 密钥对

```
cd yucai/client
python tool/gen_appcast_dsa_key.py
```

输出:公钥 PEM(SubjectPublicKeyInfo)+ 私钥 PEM(TraditionalOpenSSL DSA,与
Sparkle 官方 `generate_keys` 生态互通)。**脚本只打印到终端,不写任何文件。**

### 步骤 2:公钥烤入客户端

把公钥 PEM **整段**(含 `-----BEGIN PUBLIC KEY-----` /
`-----END PUBLIC KEY-----` 行与全部换行)粘贴保存为
`yucai/client/windows/runner/dsa_pub.pem`(auto_updater 构建时烤入 exe 的
WinSparkle 公钥资源 DSAPub/DSAPEM,更新验签用):

```
-----BEGIN PUBLIC KEY-----
<步骤 1 输出的公钥 PEM 主体,原样粘贴>
-----END PUBLIC KEY-----
```

> 注意:公钥随**客户端版本**发布。改公钥后,只有携带新公钥的版本能验签新 appcast,
> 所以步骤 2 的变更要随下一次正常发版生效。

### 步骤 3:私钥入 GitHub Actions Secrets

仓库页 → **Settings → Secrets and variables → Actions → New repository secret**:

- Name:`APPCAST_DSA_PRIVATE_KEY`(与 release.yml / 本手册三方一致)
- Value:步骤 1 输出的私钥 PEM **整段**(含 BEGIN/END DSA PRIVATE KEY 行与全部换行)

**安全红线(FR-3 / Risks 在案)**:
- 私钥**绝不**提交仓库、写入任何文件、贴聊天窗口、进日志或截图;
- 终端显示用完即清屏;此私钥一旦泄漏,任何人可对伪造安装包完成签名链。

### 步骤 4:确认 Actions 权限

1. 仓库 **Settings → Actions → General**:Actions 已启用(默认启用);
2. 同页 **Workflow permissions** 勾选 **Read and write permissions**
   (workflow 内已显式声明 `permissions: contents: write`,此处是仓库侧默认值确认,
   双保险防 `gh release create` 403);
3. 你的 git 凭据可 push tag(触发器是 tag push,不是分支 push)。

### 步骤 5:验证

跑一遍第 1 节的两个 `--self-test`,均输出 `SELF-TEST PASSED` 即环境就绪。

## 3. 日常发布(全自动)

1. **改版本**:编辑 `yucai/client/pubspec.yaml`:

   ```yaml
   version: 1.0.1+2   # X.Y.Z 递增;+N 构建号随意,只进 exe VERSIONINFO
   ```

2. 提交并合入默认分支(发布流水线从 tag 的提交检出,pubspec 必须先于 tag 落库);
3. **打 tag 并推送**(注释 = Release 页说明 = appcast changelog,spec FR-1):

   ```
   git tag -a v1.0.1 -m "修复:支出列表排序;新增:预算月度对比"
   git push origin v1.0.1
   ```

4. 之后全自动(GitHub 仓库 → Actions → `release` 工作流):
   版本守护 → 构建 → 安装包 → Release → 签名 appcast,全绿即完成;
5. 客户端侧:旧版御财在启动后台检查(默认 1 天一次)或用户点托盘「检查更新」时
   发现新版(WinSparkle 英文弹窗为决策在案的已知代价)。

**版本规则**:tag `vX.Y.Z` 必须等于 pubspec 去掉 `+N` 的部分。不符时流水线在
「Version consistency guard」步 fail-fast(版本单源守护,NFR-2)。

**失败重跑**:
- Actions 页对失败 job 直接 **Re-run** —— Release/资产步骤幂等
  (Release 已存在则改走 `gh release upload --clobber` 覆盖上传);
- tag 本身打错:删掉重推(`git tag -d vX.Y.Z && git push origin :refs/tags/vX.Y.Z`,
  再重新 `git tag -a` + push),对应 Release 若已产生也一并删除后重跑。

## 4. 发布演练清单(FR-7,人工验收)

| # | 检查项 | 通过标准 |
|---|---|---|
| 1 | Secrets 已配置 | Settings → Actions secrets 里存在 `APPCAST_DSA_PRIVATE_KEY` |
| 2 | 演练基线:旧版已安装 | 本机装有携带公钥的旧版御财(如 v1.0.0) |
| 3 | 新版 tag 已推送 | pubspec 版本已改(如 1.0.1+2),`git push origin v1.0.1` |
| 4 | Actions 全绿 | `release` 工作流 12 步全过(守护/构建/ISCC/Release/appcast) |
| 5 | Release 资产齐全 | Release 页有 `yucai-setup-X.Y.Z.exe` 与 `appcast.xml` 两资产,说明=tag 注释 |
| 6 | 稳定订阅地址生效 | `curl -L https://github.com/williamparris1995/syfinance/releases/latest/download/appcast.xml` 返回新版本条目 |
| 7 | appcast 内容正确 | 条目版本=X.Y.Z;enclosure URL 指向该 Release 安装包;dsaSignature/length 存在 |
| 8 | 旧版真机收到提示 | 旧版御财启动(或托盘「检查更新」)→ WinSparkle 更新窗弹出 |
| 9 | 下载→验签→安装→升级 | 一路完成后新版启动,托盘版本展示 = X.Y.Z |
| 10 | 零回归 | `cd yucai/client && flutter test && flutter analyze` 基线一致(NFR-3) |
| 11 | 记录 | 演练结果回填 spec FR-7 验收 |

## 5. 故障排查

| 症状 | 原因 | 处置 |
|---|---|---|
| 守护步 `tag 与 pubspec 不一致` 失败 | tag 与 pubspec 漂移 | 二者对齐后删 tag 重推 |
| `gh release create` 403 / 资产上传失败 | 仓库未给 workflow 写权限 | 见 §2 步骤 4(Read and write permissions) |
| appcast 步骤 `未提供私钥` | Secret 名拼错/未配 | 核对名称必须精确为 `APPCAST_DSA_PRIVATE_KEY` |
| 客户端验签失败(下载后拒绝安装) | 公私钥不配对(如换钥后旧版客户端) | 见 §6 密钥轮换 |
| 客户端检查更新静默无反应 | 尚无任何 Release(feed 404) | 正常降级(design Migration 在案),发出首个 Release 即好 |
| 安装包被 SmartScreen 拦截 | 免 Authenticode 签名的已知代价(spec 排除项) | 「更多信息 → 仍要运行」 |
| 中途换电脑发布 | 私钥只在 Secrets | 无需本机留存私钥,CI 全自动,换机零影响 |

## 6. 密钥轮换(泄漏/丢失时)

1. `python tool/gen_appcast_dsa_key.py` 生成新配对;
2. 新私钥覆盖 Secrets 里的 `APPCAST_DSA_PRIVATE_KEY`;
3. 新公钥按 §2 步骤 2 更新 `dsa_pub.pem`,并**随下一次发版**带出;
4. 过渡期说明:携带旧公钥的存量版本验不了新钥签名 —— 升级链对新版客户端生效
   (个人量级可接受;这是单钥方案的固有代价,design Risks 在案)。
