# HANDOFF — 到期事项常显提醒 + 账单周期线(2026-09-23 会话交接)

> 新会话入口:读本文件即可续接。相关档案同目录(spec/design/code-plan/code-ledger/task-brief-1..7)
> + prototype/v5/。工作树应干净(仅 .zcode/ devtools_options.yaml scratch_repro_test.dart 三个
> 既有杂散 untracked)。

## 已落地(六提交,全过钩子门)

| 提交 | 内容 | 门 |
|---|---|---|
| `c3e04b78` | 到期常显提醒三面:首页聚合条(hero 上方/展开/F37 着色/直达)+托盘待还行+收件箱(/inbox 两区三态小圆点/真相驱动/drift v10→v11);scanner 零改动+同源契约测试 | 2028 绿/analyze 0/review 双轴 PASS 13/13 |
| `24f29e66` | fix:信用卡到期金额改**上期账单剩余口径**(current−S;还款不进 Δ;应还≤0 不催);还款对话框基数对齐(全额(上期账单)/最低10%/分期) | 2045 绿 |
| `64dfc893` | 信用卡详情页**账单周期面板**(四字段+恒等式 caption+breakdown 不变式)+账单日/还款日编辑预填修复(_dayPicker initialValue 回读) | 2064 绿 |
| `529fd9a8` | prototype v5 重构为 **OD 套件底版 fork**(account-detail.html 同构壳/SSOT 直连/导航互通),初版裸列被用户打回 | docs |
| `c32c7bd1` | prototype v5 **交 OD 管线重做**(OD 项目 `yucai-cc-bill-cycle-13e8`/run `fe09336c`:A 列表/B 应还拆解/C 周期时间轴,壳同构+零新令牌+口径 fixture 一字不差;浏览器视觉+程序化核验过;**顺修 fork 版 ui/ 页 SSOT 6 级坏链→7 级**,fork 版经此取代、回取走 git) | docs |
| (本次) | **拍板 B「应还拆解」落地生产**:面板重写(应答块[还款日应还大字 accent+还有N天 chip+恢复等式推导]+构成条 80/20+双图例+下期出账日+降级「去设置」);页面级全对齐(hero 恒等式 caption/未设降级文案、stats 语义卡[上期剩余(应还) accent+本期新增(未出账)]、「还款日提醒」callout);`nextRepaymentDate` 共享静态入 core;CURRENT→v5、原型默认切 B;仅 creditCard 分支,其他账户类型零变化 | 2068 绿/analyze 438=基线 |

## 未决(按优先序)

1. **真机验收清单**(dev app 需带本次修改重启):聚合条(空态/展开/直达/还款后消失)/
   收件箱(两区/三态/小圆点/托盘入口)/托盘行(不含金额/不跟隐私开关)/**B 面板**
   (应答块=还款对话框/催办同数、构成条 80/20、hero 恒等式 caption、还款日 callout、
   未设账单日降级+去设置)/编辑预填(下拉带 N日)。
2. 发版待用户(可攒票):tag 推送照 runbook client/tool/RELEASE.md;server 无改动本次可只发 client。

## 关键口径(勿再漂移)

- 应还(上期剩余)= max(0, 当前欠款 − 账单日后正向消费和);**还款分录不进 Δ**;账单日当天
  消费算已出账(date>D 严格);账单日未设→降级全额口径。单一实现:
  `core/notifications/credit_card_statement.dart`(compute=breakdown().remainingCents 委托),
  催办源/对话框/详情面板三消费方同数。fixture:3000/还1000/刷500→剩余2000(测试钉死)。
- 展示与通知两管线共享 `filterActiveCandidates` 纯函数(口径单一来源),同源契约测试钉死。
