# Feature — F30 窗口状态记忆(R13 sprint-1)

> 2026-09-15。

## Description

记住窗口位置/尺寸/最大化态(关闭时保存,启动恢复);出屏/异常尺寸安全回退默认。

## Stories

- [ ] S1: 持久化(save on close/restore on start;secure_storage 或文件,照 TraySettings 范式)
- [ ] S2: 安全回退(恢复位置不在任何显示器 → 回默认居中;最小尺寸钳制)
- [ ] S3: 测试+全量门

## Keywords

`窗口状态` `window-state` `位置` `尺寸` `最大化` `持久化` `restore`
