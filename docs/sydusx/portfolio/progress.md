# Portfolio Progress

> AI resume entry — current position only. No grouping/aggregation。
> Read this → current product → release → sprint → feature → stage。
> 2026-08-05 重构为多产品 roster(server/client 两产品),自原统一 progress 迁移。

## Product roster

| product | domain | vision | 当前 release | 说明 |
|---|---|---|---|---|
| [yucai-server](../products/yucai-server/) | software | [vision](../products/yucai-server/vision.md) | [R5 审计整改](../products/yucai-server/release-r5-audit/release.md)(🔄 active) | Go 后端;produces [yucai-api](contracts/yucai-api/README.md) |
| [yucai-client](../products/yucai-client/) | software | [vision](../products/yucai-client/vision.md) | [R14 债务一致性](../products/yucai-client/release-r14-debt-account-integrity/release.md)(🔄 active 2026-09-18) · [R11 发布与更新](../products/yucai-client/release-r11-release-update/release.md)(✅ done 2026-09-16,演练全链绿) · [R13 shell 打磨](../products/yucai-client/release-r13-shell-polish/release.md)(✅ done 2026-09-15 sprint-1 三件;2026-09-16 sprint-2 F32 hero 验收补票) | Flutter 客户端;consumes yucai-api;R7/R8/R9/R10/R11/R12 已收官(R11=2026-09-16 发布演练 v1.0.1 全链绿) | Flutter 客户端;consumes yucai-api;R7/R8/R9/R10 已收官 |

## Current position

**Status:** yucai-client **[R8 design-v2 立项 2026-08-30](../products/yucai-client/release-r8-design-v2/release.md)**(A+B 亮暗双主题设计系统:用户从 A墨鎏金/B晨白/C琥珀 三方向打样中裁定 A+B 合并;[design-v2.md](../products/yucai-client/design-v2.md) 为视觉事实源,原型 12 页 `design-output-v2/ab/`)。**F1 令牌+双主题地基 ✅ done**(merge `6c48ed8c`:YucaiTheme ThemeExtension + AppTheme.dark + ThemeSettings 持久化 + 设置页主题切换 + app_shell 主题感知)。**F2 页面缺陷修复 ✅ done**(merge `cd887194`:/debts 切页 Bad state 根治[单例被 provider close]+ v1 残留色清理 + **drift 基线清零:全量 1178 tests 历史首次全绿**)。**F3 设计一致性 pass ✅ done**(merge `5b6a8f11`:16 模块页 49 处 v1 一-off 色值→语义令牌,页面间色调统一;有意保留项与 F4 待办见 release.md)。**F4 暗色感知迁移 ✅ done**(merge `cf5f92ce`:1532 处静态色 → context.yucai/46 文件,双主题全应用生效;~306 回退点为 F4-P2 backlog)。R7 windows-usable 已收官(2026-08-29)。yucai-server R5 sprint-2 ✅ done(2026-08-29),server 线按 pivot 暂停(sprint-3 挂起)。

- Current product: **yucai-client**(R12 design-debt 收官线;R8 已收官 2026-09-15)
- Current release: [release-r14-debt-account-integrity](../products/yucai-client/release-r14-debt-account-integrity/release.md)(2026-09-18 立项:sprint-1 = F33 subtype 全链路可编辑+9 类 / F34 支出信用卡支付 / F35 详情页还款计划面板 / F36 负债记账治本方案 A;优先级 F33→F34→F35→F36;分类 9 类与方案 A 用户拍板见 release.md Decisions)。
- **并行线 3(2026-09-18):R14 立项背景**——用户实测「账户页贷款分组小计 ≠ 负债页分类总览」,diagnosis 实证两页分组维度错位(账户类别 vs 债务 subtype;数据面贷款账户挂「房贷」标签债,差 ¥5,753.26 恰为该笔)+ 本息/本金口径差(未付利息 ¥286,692.03);叠加用户 5 点需求拆 F33-F36。前置:在途 WIP(担保人+合同附件 v1+周期规则+利息减免+AccountsPage 贷款卡接债务实时数据,drift v6→v8)已审验合入 `e8966072`(1825 测全绿+analyze 439 info 基线[429→439]+go 绿+client-e2e 13/13;golden audit_menu_open 随新 UI 重录);`3de98191` 补齐其漏提交的 server untracked(shared/domain/recurrence 包+recurrence.pb.go)。**F33 ✅ done(2026-09-18,ff 合并 `fd3be313`)**——subtype 全链路可编辑(proto UpdateDebtRequest 追加 subtype=19 空串保持/server 接线/client 五处透传/表单解禁)+分类 9 类(新增信用贷款/现金分期/消费贷/经营贷)+创建自动归位(未触碰才联动)+白名单冲突非阻断警示条(callout.warn 复用);全流程 grill 三轮→spec→design 六 ADR→prototype v3(用户定稿原样式)→T1-T7 SDD(3 并行代理+串行表单双任务,全部两轴评审 pass)→test 门 6/6 需求覆盖;门:go 全绿/flutter **1849**/analyze 437≤439/client-e2e **14/14**(新成员 link_debt_subtype);worktree 已清、分支已删。**F34 ✅ done(2026-09-18,ff 合并 `c45127bb`)**——支出支付方式放开信用卡(paymentAccounts=asset∪信用卡类负债;刷卡消费=借支出/贷信用卡,余额更新器 liability 方向既有语义零新记账;类型切换失效清空守卫防下拉崩溃;信用卡详情「记一笔」预选成立);4 新测;1855 全绿+analyze 438≤439+e2e 14/14;NonGoal:转账/收入维持 asset-only(信用卡还款语义另议)。用户实测报告的两点(卡详情记账不带卡/转出选不了卡)即本票主体,当票修复。**F35 ✅ done(2026-09-18,ff 合并 `e9b6d94a`)**——贷款账户详情页「还款计划」只读面板(AccountRepaymentPlanPanel:每笔债 counterparty+剩余本金 badge+未来未还期次前 3+跳转 /debts/:id;空态隐藏退役「待 payment_schedule 接入」占位;RouteAware+didPopNext 重拉——顺手补齐该页缺失的订阅,简报勘误入 ledger);3 新测;1858 全绿+analyze 438≤439+e2e 14/14;范围=loan 类,otherLiability 扩展 backlog。**F36 ✅ done(2026-09-19,ff 合并 `d81a3539`;spec 3 决策点用户「按推荐」拍板)**——负债记账治本方案 A 全落地:T1 client 三缺口分录(创建无到账→权益户/改总额→同事务调整/删除→清账,含息超还反向)+不变式助手;T2 server 创建·改额·清账入账(RepaymentCashRecorder port+WithTx 同事务,AccountLookup 最小扩展 FindByAccountType,租户缺权益户降级跳过);T3 存量迁移(runF36LiabilityBalanceRepair 逐持借入债负债账户 delta 调整,经交易管道联动余额[旧 raw SQL repair 不联动=漂移根源],app_meta 幂等+中断重入安全,挂 beforeOpen 管道);不变式矩阵 13 测(client 7+server 3+repair 3),存储口径 balance==+Σ剩余;已知边界:改总额 server 透传待 proto 字段(gRPC 不经,client 本地路径先行)。1871 全绿+analyze 438≤439+go 全绿+e2e 14/14。**R14 sprint-1 4/4 收官=release 功能 done**(done-criteria 1-5 达成,deploy 待用户;F36 真库修复随下次启动 beforeOpen 触发)。*F36 验收热修待观察:无——一次性通过。* **v1.0.6+7 已发布**(2026-09-19:tag `v1.0.6`→Actions 绿[~7min]→Release 双资产[yucai-setup-1.0.6.exe+DSA appcast],稳定订阅地址已供 1.0.6;R14「债务与账户一致性」全链闭环——分类体系/信用卡支付/还款计划面板/负债记账不变式+存量修复)。
- **并行线 2:yucai-client [R9 离线续写 立项 2026-09-03](../products/yucai-client/release-r9-offline-continue/release.md)**(ticket 16 之①;F10 离线写缓冲 → F11 server 最小同步[窄幅复线] → F12 状态与冲突 → F13 e2e;多设备 sync engine 仍留 ticket 16)。
- Current sprint: R8 线 sprint-3/4/5 ✅ 收官(F15 `b2a04b73`)。**sprint-6 ✅ done**(F21 清空数据重新开始,merge `6aa670fb`;精简走法,spec/code-plan 在 feature 目录,无 sprint.md)。**sprint-7 立项**(2026-09-15 brainstorm 四项用户拍板:[sprint-7](../products/yucai-client/release-r8-design-v2/sprint-7/sprint.md) — **F22 ✅ done**(2026-09-15,merge `6e6d1698`:退出入口[设置页底部按钮+AppExitPort 即时退出]+关闭行为设置化+首关一次性对话框+扫描调度治本[drift watch 变更即扫+可配间隔 15/30/60,撤跨日门槛与「立即检查」];TrayController 注入化=F25 地基;1643 全绿+e2e+review 门 pass;真机人工验收清单 5 项待用户)/ F23 ✅ done(2026-09-15,merge `f5d7ac2b`:六档 ICO 替换 runner+托盘印章简化形+可重跑管线+缓存覆盖修复;真机走查待用户)/ F25 ✅ done(2026-09-15,merge `e5e1734e`[fast-forward]:托盘数据头两行+记一笔+隐私开关,1665 全绿)——**sprint-7 收官**;R8 release **已收官 2026-09-15**,defer→R12)。**R11 发布与更新 ✅ 收官**(2026-09-16:演练 v1.0.1 全链绿——DSA 真钥接入 `cdb3264d`→tag 推送→Actions 构建→Release 双资产[安装包+签名 appcast];「推 tag 即发版」闭环;D-5 真机旧版升级提示为最后人工项)。**R13 shell 打磨 sprint-1 ✅ 收官=R13 release 收官**(2026-09-15:F29 自定义标题栏 `4a4a676b`[TitleBarStyle.hidden+「御」金渐变徽标+三窗口钮,关闭直通 F22 决策树,侧栏徽标统一]/F30 窗口状态记忆 `3bd8cd35`[防抖落盘+出屏检测+钳制恢复]/F31 文案散件 `17a2073e`;1731 全绿+analyze 428;真机 Snap/窗口恢复验收待用户)。**R13 sprint-2 ✅ 收官**(2026-09-16,F32 hero 验收缺陷修复 `0f220db6`[ff]:负净资产千分位错位根治[−195,616 误显 −,195,616,分组函数负号计入定位]+ 两 hero 光晕 Stack 硬裁放行[Clip.none,卡面 antiAlias 圆角接管];两轴 review pass——3 Minor 修 2[string 侧剥符号/account 暗色 clip 断言]defer 1[千分位副本收敛另开票],评审修复 `364669f4`[ff];+4 测,worktree 门 1735 全绿+analyze 429 基线;真机 dashboard 复核待用户——**2026-09-16 已复核 ✅**(开发版实测:hero −195,616 千分位正确/光晕圆角裁剪正常)并随 **v1.0.5+6 发布**(`d00b2613`,tag `v1.0.5`;含 WinSparkle 版本串死循环热修 b93c90ca=首个 X.Y.Z 串 Release;Actions 7m14s 绿,Release 双资产+签名 appcast 上线)。**R12 design-debt sprint-3 ✅ 收官=R12 release 收官**(2026-09-15,F28 占位文案 done,merge `ed4eed69`[ff]:31 处按规范迁移[例如：/请输入X,用户两项拍板]+FR-2 grep 门;1686 全绿;R8 defer 三票全清[hero/onAccent/文案],design-v2 零裸色零杂式达成;helperText×2 后续票)。**R12 design-debt sprint-2 ✅ 收官**(2026-09-15,F27 onAccent sweep done,merge `ff4dabf1`[ff]:75 处 Colors.* 全量判定 47→onAccent/29 豁免带注,1686 全绿+analyze 428,评审零错例;design-v2 令牌三阶段闭环)。**R12 design-debt sprint-1 ✅ 收官**(2026-09-15,F26 净资产 hero 终态 done,merge `0fa0123b`[ff]:home+账户详情两 hero 迁 design-v2 §4 随主题+F15 豁免两目清零+HeroShell 共享件;1683 全绿+analyze 429;下一 sprint 候选=onAccent sweep/占位文案)。**R11 发布与更新立项激活**(2026-09-15,用户三决策:新 release/自动+手动更新 UX/EdDSA 清单签名):[R11](../products/yucai-client/release-r11-release-update/release.md) sprint-1 = F24 自动更新全链 **代码面 ✅ done**(2026-09-15,merge `021cd2d9`[fast-forward]:Actions 流水线+DSA 签名 appcast[EdDSA 引擎降档在案]+auto_updater+托盘检查更新/版本号;1679 全绿;**S5 发布演练待用户**:密钥→Secrets→真 tag→真机升级,runbook=client/tool/RELEASE.md)。**R10 多设备同步立项激活**(2026-09-03 用户确认分解:**sprint-1 ✅ 收官**(F16+F17);**sprint-2 进行中**——F18 冲突解决 ✅ `001c7b07`(检测统一 canonical 短路[阻断修复]/确认/解决落库/版本感知 applier/冲突面板/双设备 e2e),**sprint-2 ✅ 收官**(F18 `001c7b07`/F19 `df651460`/**F20 `9acab473`**)——**R10 多设备同步 release 功能 done**(F16-F20 五 feature 全落地)。**待人工验收**:R9+R10 真机走查(docker PG+server→绑定→断网记账→回网→双设备互看;清单 R9 release.md)。原 F19/F20 行:(双向持续循环+删除传播进回归门;存档上云=事实性映射+backlog)——**R10 五 feature 全 done,done-criteria 达成**(R9 真机人工验收为唯一外部待办,清单见 [R9 release.md](../products/yucai-client/release-r9-offline-continue/release.md) 收官节;建议用户连同 R10 地基一起走一遍:docker PG+server→绑定→断网记账→回网→双设备互看);sprint-2 F18 冲突/F19 绑定合并/F20 上云+e2e;建议 sprint-1 实施前完成 R9 真机验收)。**R9 离线续写 sprint-1 收官**(2026-09-03,F10 `39063da2`/F11 `745a4aa1`/F12 `a1f015f7`/F13 `7f2345c2` 四 feature 全 done——绑定后断网完整记账/增量同步通路/状态徽标/契约 e2e 进回归门;release 功能 done,真机全栈人工验收待用户;ticket16 线增厚在案)。sprint-2 ✅ done(2026-09-03,F6 E2E 全模块关联链路补全,merge `160c3f30`:**模块修改后标准回归 = `make client-e2e`[管道 47 测试] / 出问题定位用 `make client-e2e-ui`[UI 17 测试],均支持 `F=` 单文件;种子→断言→测后删库,真实库零接触**);sprint-1(F1-F4)done;F4-P2(~306 处)与 backlog 见 sprint-2 defer(标签反查/category 接线/生产疑点 6 处等)。
- **2026-08-29 优先级 pivot(用户拍板方案 A)**:client 可用优先 → R7 四 feature 全落地收官后转入 R6 人工验收(待用户)与 R8 UI 线(已立项)。AI 语音助手=后续 feature 待 ticket 化。
- **并行线**:yucai-client **[R6 offline-first](../products/yucai-client/release-r6-offline/release.md) 整体 done**(2026-08-23,十二 feature A-J 全 merged;人工清单真机执行待用户归档;defer 清单见 release.md——含 J codec 补 YC2E 解码[R5 D 的 contract drift]与 ticket 16 线)。

## Legacy milestones(pre-split,pre-sydusx,统一御财)

> 2026-08-05 拆分前的耦合里程碑(server+client 共同)。非 canonical release,仅追溯。

- **R1 架构重建** ✅ — Tauri+Rust+React → Go+Flutter 重写([ADR-001](adr/index.md#adr-001),2026-06-09)。
- **R2 holding 系统** ✅ — 资产管理 + 收益引擎(XIRR/TWR/Yahoo)+ 双写 + tag/template。
- **R3 备份/预算/目标/dashboard** ✅ — 本地备份 + budget + goal + dashboard。
- **R4 auth OIDC** ✅ — 自建密码→OIDC(Google,server+client;Task 13 联调 blocked-on-user)。

拆分后:server 继续 R5;client 无 active release,下一 release 待规划。

## baselines(repo-global,2026-08-01 建立 / 2026-08-05 迁 portfolio/)

`docs/sydusx/portfolio/` 下:
- [conventions](conventions.md) · [infrastructure](infrastructure.md) · [ci-cd](ci-cd.md) · [ai-harness](ai-harness.md) · [adr cross-cutting](adr/index.md)
- 产品层:yucai-server / yucai-client 各 [architecture](../products/yucai-server/architecture.md) + [tech-stack](../products/yucai-server/tech-stack.md) + [adr](../products/yucai-server/adr/index.md)。
- 契约:[contracts/yucai-api](contracts/yucai-api/README.md)(server produces / client consumes)。

**harness enforcement wall**(scaffold + e2e 验证 exit 0,2026-08-01):
- [.claude/hooks/verify-commit.ps1](../../../.claude/hooks/verify-commit.ps1) — PreToolUse(git commit)跑 `go test ./...`(全绿 block)+ `flutter test`(基线容忍:account_detail_page_test / receivable_detail_page_test drift 放行)。注册于 `.claude/settings.json`。
- **已 e2e 验证**:go test 全绿 + flutter 仅剩 baseline 2 文件 drift(容忍)→ exit 0。

## 备注

- 本地 main 与 origin 已同步(2026-08-01 push `ec7dcb2` 后;此前 memory 说"346+ 未 push"已过时)。
- 基线:go test 全绿 + flutter 3 fail/2 文件 drift(CLAUDE.md 记录值,2026-08-01 验证)。
- pre-commit 测试 gate hook 已生效 + 实测通过。

## 历史背景

- 现有 SDD 产物:`docs/superpowers/`(233 specs+plans,2026-05~07-26)。
- 御财审计:`.scratch/yucai-audit/`(16 ticket,9 已决策;01/02/07 已实施,03 事务架构 2026-07-26 落地 11 commits)。
