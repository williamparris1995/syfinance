# Feature — B1 本地通知基础设施 + 到期提醒(R7 sprint-2 feature B)

> pivot A 定时通知主线;grill 定案托盘常驻路线(2026-08-29)。

## Description

leanflutter 三件套(local_notifier + tray_manager + launch_at_startup + window_manager)构建 Windows 常驻提醒:开机自启(默认开,卸载清理)、关闭即最小化到托盘、单实例;本地扫描 drift PaymentScheduleEntries 未付期次,三档策略(T-3/T-0/逾期每日)发 toast 提醒(债务名+金额+相对天数),当日去重持久化;通知封装为 port 可测。纯本地零 server。

## Stories

1. 通知 port 封装(local_notifier 接线,AUMID 对齐安装器)
2. 到期扫描器(三档策略 + 去重持久化 + 触发时机:启动/每日/手动)
3. 托盘常驻(托盘菜单/关闭最小化/退出真退)
4. 开机自启(launch_at_startup 默认开 + Inno 卸载清理)
5. 单实例握手(二次启动唤起既有窗口)
6. 提醒内容与点击聚焦主窗口

## title

B1 本地通知基础设施 + 债务到期提醒(托盘常驻)

## keywords

notification, local-notifier, tray, autostart, due-date, reminder, debt, schedule, windows, B1
