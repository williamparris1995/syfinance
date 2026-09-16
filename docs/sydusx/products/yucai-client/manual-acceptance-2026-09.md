# 御财 全量真机验收总手册(2026-09)

> 2026-09-16 编制。目的:把散落 R6/R7/R9/R10/R11 各 release 与 F22-F31 feature 的**全部待人工验收项**合并为一次「构建一次、逐阶段走查」的执行手册。执行后在本文件打勾,异常记文末「异常记录」节,完成后各 release.md 状态节补记归档。
> 组织:阶段一/二 单机即可;阶段三 需 docker+server+第二台设备;阶段四 发布演练(改 GitHub 网页,我方可陪跑)。

## 准备

- [ ] P-1 构建:`cd yucai && make windows-installer`(或阶段四由 Actions 出包);安装器在 dist/
- [ ] P-2 安装旧版(若机器已有旧安装,先卸载或直接覆盖——覆盖可顺带验证升级路径)

## 阶段一 shell 与设计走查(F22-F31,单机)

- [ ] A-1 **图标**:任务栏/开始菜单/桌面/文件管理器显示「御」金渐变图标;若见旧 Flutter 图标 → 跑 `ie4uinit.exe -show` 或换 exe 文件名刷缓存(F23)
- [ ] A-2 **托盘**:右键托盘图标 → 菜单 = 数据头两行(今日收·支/本月结余)+ 记一笔 + 显示御财 + 检查更新 + 御财 vX.Y.Z + 退出;金额与 app 内一致(F25/F24)
- [ ] A-3 **隐私开关**:设置→窗口与提醒→「托盘显示金额」关 → 托盘数据头变「金额已隐藏」;开 → 恢复(F25)
- [ ] A-4 **记一笔快捷**:托盘菜单「记一笔」→ 窗口弹出并直达记账表单(F25)
- [ ] A-5 **关闭行为**:设置「退出程序」→ 点 X 真退出;切回「隐藏到托盘」→ 首次点 X 弹对话框(Esc=窗口保留且下次仍弹;选最小化→隐藏且此后不再弹)(F22)
- [ ] A-6 **设置页退出按钮**:底部「退出御财」即时退出、托盘图标消失(F22)
- [ ] A-7 **变更即扫**:新记一笔今天到期的债务期次 → 秒级弹到期提醒(不等 30 分钟)(F22)
- [ ] A-8 **标题栏**:「御」金渐变徽标+御财+三钮;拖拽移动/双击最大化/□❐ 图标随最大化切换/─ 最小化;**Win+方向键 Snap 贴靠仍原生可用**;登录页(未登录窗口)同样有标题栏(F29)
- [ ] A-9 **窗口记忆**:移动+调整窗口尺寸 → 关闭(隐藏到托盘后退出)→ 重启 → 位置/尺寸恢复;最大化态关闭重启仍最大化;把窗口拖到副屏再拔副屏 → 重启回默认位(F30)
- [ ] A-10 **hero 双主题**:首页净资产/账户详情 hero 暗色=墨面+金渐变描边+渐变金数字;亮色=白卡阴影黑字;切主题即时正确(F26)
- [ ] A-11 **onAccent 观感**:暗色下各表单金色提交按钮文字为深墨色(design-v2 语义,非白);亮色白字;FilterBar 选中态同(F27)
- [ ] A-12 **文案**:各表单示例提示统一「例如：」;密码类「请输入密码」(F28/F31)

## 阶段二 R6/R7 存量清单(单机)

- [ ] B-1 R6 离线清单:[acceptance-checklist.md](release-r6-offline/sprint-3/2026-08-20-offline-e2e-acceptance/acceptance-checklist.md) 逐项执行
- [ ] B-2 R7 各 feature acceptance:打包/通知/自动记账/本地收益引擎([r7 各 sprint acceptance.md](release-r7-windows-usable/) —— 抽验未走查项)

## 阶段三 双设备同步走查(R9+R10,需 docker PG+server+两台设备)

- [ ] C-1 docker 起 PG+server,设备 A 绑定 → 断网记账数笔 → 回网自动补同步(R9)
- [ ] C-2 设备 B 绑定同账号 → 双向互看;A 记账 B 可见,反之亦然(R10)
- [ ] C-3 断网双端各改同一笔 → 冲突面板出现并解决(R10 F18)
- [ ] C-4 备份上云:导出存档→另设备导入还原(R10 F20)

## 阶段四 F24 发布演练(改 GitHub 网页;本地材料已备)

- [x] D-1 打开 `.scratch/appcast-keys/keys.txt`(本地未入库):**私钥 PEM** 段复制 → GitHub 仓库 Settings→Secrets→Actions 新建 `APPCAST_DSA_PRIVATE_KEY`;**公钥 PEM** 段整段替换 `yucai/client/windows/runner/dsa_pub.pem`;`lib/core/notifications/app_updater.dart` 的 `publicKeyIsPlaceholder` 翻 `false`
- [x] D-2 GitHub 仓库 Settings→Actions→General 确认 Workflow permissions=Read and write
- [x] D-3 版本:`yucai/client/pubspec.yaml` version 改 `1.0.1+2` → 提交 → `git tag -a v1.0.1 -m "..." && git push origin main --tags`
- [x] D-4 Actions 页看 release workflow 全绿;Releases 页出现 v1.0.1(安装包+appcast.xml)
- [ ] D-5 旧版本(v1.0.0 安装态)启动 → 托盘菜单「检查更新」→ 引擎弹英文更新窗 → 安装 → 重启后版本号=1.0.1;或等待自动检查(默认 1 天)
- [ ] D-6 异常排查:[RELEASE.md §5](../../yucai/client/tool/RELEASE.md)(密钥/权限/缓存)

## 异常记录

(执行中发现的问题逐条记此,回填对应 feature/release 的 follow-up)
