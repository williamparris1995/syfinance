# B2 验收记录 — autoRecord 本地调度器(2026-08-29)

## 自动验证(已执行)

| 项 | 结果 |
|---|---|
| 周期算法 8 测(oracle=server 用例移植) | ✅ weekly/monthly 钳制 1/31→2/28/闰年 2/29/billingDay=0 回退/跨年/yearly 闰日/custom=cycleDays |
| 调度器 5 测 | ✅ 一次性补齐(3 周→4 笔)/今日到期单笔/endDate 截断/未到期零新增/单模板失败继续 |
| ds `_advance` 月度缺陷修复 | ✅ 委托共享算法(旧滚动语义 1/31→3/1 漂移已纠正) |
| flutter test 基线 | ✅ +1132 −4(新增 13;4=既有 drift 无退化) |
| analyze + windows build | ✅ 无 issue;构建过 |

## 运行时冒烟(blocked-on-user,打包版)

- [ ] 造月度模板(nextDate=2 个月前,autoRecord=on)→ 启动 app → 10s 内生成 3 笔交易 +「已自动补记 3 笔」toast;模板 nextDate 前进
- [ ] 托盘「立即检查(提醒/记账)」→ 立即触发
- [ ] paused 模板不自动记;endDate 过期模板停记
- [ ] 绑定模式:生成的交易回网后出现在 server(穿透上行)
