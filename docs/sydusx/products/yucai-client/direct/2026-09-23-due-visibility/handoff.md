# HANDOFF — 到期事项常显提醒 + 账单周期线(2026-09-23 会话交接)

> 新会话入口:读本文件即可续接。相关档案同目录(spec/design/code-plan/code-ledger/task-brief-1..7)
> + prototype/v5/。工作树应干净(仅 .zcode/ devtools_options.yaml scratch_repro_test.dart 三个
> 既有杂散 untracked)。

## 已落地(四提交,全过钩子门)

| 提交 | 内容 | 门 |
|---|---|---|
| `c3e04b78` | 到期常显提醒三面:首页聚合条(hero 上方/展开/F37 着色/直达)+托盘待还行+收件箱(/inbox 两区三态小圆点/真相驱动/drift v10→v11);scanner 零改动+同源契约测试 | 2028 绿/analyze 0/review 双轴 PASS 13/13 |
| `24f29e66` | fix:信用卡到期金额改**上期账单剩余口径**(current−S;还款不进 Δ;应还≤0 不催);还款对话框基数对齐(全额(上期账单)/最低10%/分期) | 2045 绿 |
| `64dfc893` | 信用卡详情页**账单周期面板**(四字段+恒等式 caption+breakdown 不变式)+账单日/还款日编辑预填修复(_dayPicker initialValue 回读) | 2064 绿 |
| `529fd9a8` | prototype v5 重构为 **OD 套件底版 fork**(account-detail.html 同构壳/SSOT 直连/导航互通),初版裸列被用户打回 | docs |
| (本次) | prototype v5 **交 OD 管线重做**(OD 项目 `yucai-cc-bill-cycle-13e8`/run `fe09336c`:A 列表/B 应还拆解/C 周期时间轴,壳同构+零新令牌+口径 fixture 一字不差;浏览器视觉+程序化核验过;**顺修 fork 版 ui/ 页 SSOT 6 级坏链→7 级**,fork 版经此取代、回取走 git) | docs |

## 未决(按优先序)

1. **面板 A/B/C 拍板 → CURRENT 指 v5**(A=生产已实现零改动;B/C 需后续 UI 票,布局契约照 v5 快照)。
   浏览器打开 `docs/sydusx/products/yucai-client/prototype/v5/ui/credit-card-account.html`,
   底部浮动条切 A/B/C + 账单日 已设/未设(或 URL `?panel=b|c&billing=unset`)。OD redo 已完成
   (上一行提交),OD studio 预览亦可:`yucai-cc-bill-cycle-13e8` 项目。
2. **真机验收清单**(dev app 已带全部修复重启过):聚合条(空态/展开/直达/还款后消失)/
   收件箱(两区/三态/小圆点/托盘入口)/托盘行(不含金额/不跟隐私开关)/账单周期面板四数
   (恒等式:当前欠款=上期剩余+本期账单)/编辑预填(下拉带 N日)。
3. 发版待用户(可攒票):tag 推送照 runbook client/tool/RELEASE.md;server 无改动本次可只发 client。
3. **真机验收清单**(dev app 已带全部修复重启过):聚合条(空态/展开/直达/还款后消失)/
   收件箱(两区/三态/小圆点/托盘入口)/托盘行(不含金额/不跟隐私开关)/账单周期面板四数
   (恒等式:当前欠款=上期剩余+本期账单)/编辑预填(下拉带 N日)。
4. 发版待用户(可攒票):tag 推送照 runbook client/tool/RELEASE.md;server 无改动本次可只发 client。

## 关键口径(勿再漂移)

- 应还(上期剩余)= max(0, 当前欠款 − 账单日后正向消费和);**还款分录不进 Δ**;账单日当天
  消费算已出账(date>D 严格);账单日未设→降级全额口径。单一实现:
  `core/notifications/credit_card_statement.dart`(compute=breakdown().remainingCents 委托),
  催办源/对话框/详情面板三消费方同数。fixture:3000/还1000/刷500→剩余2000(测试钉死)。
- 展示与通知两管线共享 `filterActiveCandidates` 纯函数(口径单一来源),同源契约测试钉死。
