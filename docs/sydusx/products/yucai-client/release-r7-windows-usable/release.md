# Release — R7 御财 Client Windows 可用线

> Release Goal + sprint roster + done-criteria。`/sydusx-portfolio` 立项(2026-08-29)。
> 溯源:portfolio pivot A(2026-08-29,client 可用优先——见 [progress](../../../portfolio/progress.md) pivot 记录);用户拍板 Windows 优先、移动端随后(R8)。

## Release Goal

御财客户端 **Windows 可分发、可日常自用**:无账号本地模式在 Windows 上开箱可用——可安装分发、有账单/模板定时提醒、离线可看收益分析(XIRR/TWR)。

## Scope

### IN
| 领域 | 内容 |
|---|---|
| 分发 | Windows 打包/安装通路(exe/msix + 全新安装三判据复验) |
| 通知 | Windows 本地通知基础设施 + 账单到期/模板提醒 |
| 调度 | autoRecord 本地调度器(周期模板本地模式自动生成交易) |
| 收益 | XIRR/TWR Dart 镜像(G[R5 sprint-2] 算法+oracle 移植,performance 双源) |

### OUT(留后续 release)
- **Android/移动端**打包与通知 → R8(用户裁定 Windows 优先)。
- 绑定后离线续写 / 多设备同步 → ticket 16。
- i18n 阶段二([ADR-006](../adr/index.md#adr-006) 不变)。
- AI 语音助手 → 后续 feature 待 ticket 化(pivot 记录)。
- server 改动 → 零(R5 sprint-3[08/09]挂起中)。

## Sprint roster

- [ ] **sprint-1** 分发基础(打包通路 + R6 人工验收归档)
- [ ] **sprint-2** 定时通知(通知基础设施 + autoRecord 本地调度器)
- [ ] **sprint-3** 收益本地化(XIRR/TWR Dart 镜像 + 双源接线)

## Done-criteria(release gate)

- 全新 Windows 安装 → 无账号本地模式可用,R6 三判据在打包版复验通过。
- 到期账单/模板在 Windows 上有通知;本地模式周期模板自动生成交易。
- 断网(从未绑定)下 performance 页有 XIRR/TWR 数值(本地计算)。
- `flutter test` 基线不退化 + `flutter analyze` 不新增 + `go test ./...` 全绿(server 零改动)。

## status: in-progress(sprint-1 进行中)
