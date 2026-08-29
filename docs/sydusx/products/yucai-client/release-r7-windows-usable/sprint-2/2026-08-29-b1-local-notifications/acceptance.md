# B1 验收记录 — 本地通知 + 托盘常驻(2026-08-29)

## 自动验证(已执行)

| 项 | 结果 |
|---|---|
| 策略/扫描器/去重 20 单测 | ✅ All tests passed(三档/当日幂等/跨日逾期再发/已付跳过/金额千分位) |
| drift v1→v2(ReminderLogs 表) | ✅ build_runner regen;内存库测试过 |
| flutter test 基线 | ✅ +1118 −4(新增 20 全过;4 失败=既有 drift,无退化) |
| flutter analyze(新模块+main) | ✅ No issues |
| Windows release build(worktree 短路径) | ✅ yucai_client.exe;五新插件链编译过 |
| 安装包(含卸载清理段) | ✅ ISCC exit 0,dist/yucai-setup-1.0.0.exe |

## 运行时冒烟(blocked-on-user,打包版执行)

- [ ] 启动 → 托盘图标出现;点关闭 → 窗口隐藏(托盘在)
- [ ] 造一笔 paymentDate=今天/3 天后/逾期的未付期次 → 启动或托盘"立即检查提醒" → 三条 toast(标题御财·债务名;金额千分位)
- [ ] 同日重复"立即检查" → 不重发;明日逾期条 → 再发一条
- [ ] 点击通知 → 主窗口前置
- [ ] 双开 exe → 无第二个托盘,已有主窗口被唤起
- [ ] 任务管理器确认自启注册(HKCU Run/yucai_client);注销/重启后 app 自动启动到托盘
- [ ] 卸载 → 自启注册被清(reg delete 段)
