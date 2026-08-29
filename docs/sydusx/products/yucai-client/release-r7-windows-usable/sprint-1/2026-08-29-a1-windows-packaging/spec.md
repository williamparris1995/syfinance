# Spec — A1 windows-packaging(R7 sprint-1 feature A)

> ticket 11(deployment-pathway)client 面;R7 首个 feature。
> branch `feature/a1-windows-packaging`,worktree `.claude/worktrees/a1-windows-packaging`。

## Problem

client 无分发通路:`flutter build windows` 产物只有开发者能跑,无可安装形态、无版本标识、无全新安装验证——"可分发可自用"的第一块缺口。

## FRs

- **FR-1 一键构建**:Makefile `windows-installer` 目标——`flutter build windows --release` → Inno Setup 编译(.iss 入库 `yucai/client/packaging/yucai.iss`)→ `dist/yucai-setup-<version>.exe`;单命令源码→安装包,可重复。
- **FR-2 版本戳**:pubspec `version` 单一来源 → .iss AppVersion + exe 文件属性(产品名/版本/公司)同步生成(构建期从 pubspec 读,不手抄)。
- **FR-3 安装体验**:中文安装向导;开始菜单快捷方式 + 桌面快捷方式(可选);控制面板可卸载;默认装本地 AppData(免管理员)。
- **FR-4 全新安装三判据复验**:干净环境(清 AppData/新用户)装包跑 R6 三判据(断网全新安装可启动记账 / 从不绑定永远本地 / 数据落本地);结果记入本目录 checklist(含 SmartScreen 免签名提示的实测记录;人工部分标注 blocked-on-user)。

## NFRs

- server 零改动(`go test ./...` 不受影响);`flutter test` 基线不退化 + `flutter analyze` 不新增。
- 构建可重复:二进制不入库,`dist/` gitignore;脚本+模板入库。
- 无管理员权限要求(默认 per-user 安装)。

## 测试计划(工具型 feature 的验证形态)

- `make windows-installer` exit 0 且产物存在+版本号正确(构建即测试)。
- 安装→卸载 round-trip 在本机执行并记录。
- 三判据复验 checklist(部分人工)。
- `flutter test` / `flutter analyze` 基线对照。

## Grill record(2026-08-29)

1. **安装器选型 Inno Setup(自用优先免签名)** — 挑战:MSIX 为 Flutter 官方推荐且 Store 唯一通路,现在选 Inno 将来或重做;SmartScreen 警告恐吓家人用户;辩护:近期分发对象=自己+家人,自签 MSIX 的证书信任摩擦恰伤这批人,.iss 纯文本入库一键可重复,Store 通路可作 R8+ 增量不互斥。用户:"自用优先免签名"。

## Scope boundary(排除即决策,逐条有主)

| 排除项 | 归属 | 理由 |
|---|---|---|
| MSIX / Microsoft Store 通路 | R8+ 增量 | 与 Inno 不互斥;自用免签优先(grill #1) |
| 自动更新机制 | 不做 | 自用手动覆盖安装;YAGNI |
| 代码签名证书 | 不做 | 自用免签;SmartScreen 警告为已知代价(记入 checklist) |
| Android / 移动端打包 | R8 | 用户裁定 Windows 优先 |
| 安装向导多语言 | 不做 | 中文 only(ADR-006 阶段一) |

## 可行性

- **Technical: GO** — Inno Setup 免费成熟;Flutter windows release 标准路径;版本读取用 pubspec 解析。
- **Economic: GO** — 半天~1 天。
- **Operational: GO** — 全程本机可完成。
