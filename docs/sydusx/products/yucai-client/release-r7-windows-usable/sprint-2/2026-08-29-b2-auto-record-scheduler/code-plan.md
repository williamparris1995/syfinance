# Code Plan — B2 auto-record-scheduler

> inline TDD;工作目录 `yucai/client/`。

- [x] **T1 周期算法纯函数** — `advanceNextDate` 抽出 + server oracle 移植(weekly/monthly 月末钳制 1/31→2/28/billingDay/yearly/custom-cycleDays);ds `_advance` 改委托;RED→GREEN
- [x] **T2 AutoRecordScheduler 编排** — fake 模板源+record+notifier:三条件过滤、一次性补齐 N 笔(断网 3 周)、endDate 截断、同日重跑零新增、单模板失败继续、paused/autoRecord=false 跳过
- [x] **T3 通知文案与金额格式复用** — `_formatYuan` 提升;单笔/批量文案断言
- [x] **T4 触发接线** — bootstrap 延迟 10s + tray tick 联动 + 菜单文案「立即检查(提醒/记账)」;错误隔离
- [ ] **收尾** — flutter test/analyze 基线 + windows build → code-review → commit
