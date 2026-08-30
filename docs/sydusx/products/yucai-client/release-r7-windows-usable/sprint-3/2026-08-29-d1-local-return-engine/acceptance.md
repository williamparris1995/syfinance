# D1 验收记录 — 收益引擎本地化(2026-08-29)

## 自动验证(已执行)

| 项 | 结果 |
|---|---|
| 引擎 oracle 14 测(G 用例逐值移植) | ✅ Excel 37.34%/1e8/极端 1.28e15(闭式对拍)/陡梯度深亏 −0.9697/包络守卫/NaN graceful/scale 不变/TWR 序列+三哨兵+分段链乘 |
| 装配器 4 测(手算 oracle) | ✅ 单笔 XIRR≈20%(365d)/清仓重建链乘 1.21(段天数 10+30)/gap 起点重启/曲线点(元)+split 无点 |
| 首日不产 sub/空段单尾/segStart=首现金流日 | ✅ 三个移植偏差在测试驱动下修正(对齐 G 语义) |
| flutter test 基线 | ✅ +1153 −4(新增 18;4=既有 drift) |
| analyze | ✅ 零新增(基线 21→20) |
| windows build | ✅ |

## 运行时冒烟(blocked-on-user)

- [ ] guest 模式:建仓(买入)→ performance 页 XIRR/TWR/CAGR 数值可见,标注「离线口径」
- [ ] guest 清仓重建 → TWR 分段链乘数值
- [ ] 绑定模式断网 → performance 页本地兜底数值(offlineScope 标注)
- [ ] 绑定在线 → server 权威值(无标注)
