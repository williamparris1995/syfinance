# Feature — B2 autoRecord 本地调度器(R7 sprint-2 feature C)

> 双模式常跑(离线完整宪法)+ 一次性补齐;依赖 B(通知通道+托盘 tick)。

## Description

周期模板在本地自动记账:到期判定镜像 server(autoRecord+未暂停+nextDate≤今天),一次性补齐所有错过周期(endDate 截断),nextDate 游标幂等;交易与模板更新走双源 repo(绑定穿透上行);启动/tick/手动三触发;生成后通知(单笔/批量汇总);周期算法 Dart 移植(Custom 按 cycleDays,纠正 server 存根)。绑定+在线的 server 并发双记去重 defer ticket 16。

## Stories

1. 周期推进算法 Dart 移植(server 用例作 oracle;Monthly 月末钳制;Custom=cycleDays)
2. 到期判定 + 一次性补齐调度器(fake repo/notifier 单测)
3. 双源写路径接线(transaction/template repo 穿透)
4. 触发时机(启动 10s/tick 跨日/托盘立即检查)+ 错误隔离
5. 通知(单笔/批量文案)

## title

B2 autoRecord 本地调度器(双模式+一次性补齐)

## keywords

auto-record, scheduler, template, recurring, next-date, catchup, offline, drift, B2
