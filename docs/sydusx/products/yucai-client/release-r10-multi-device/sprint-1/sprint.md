# Sprint 1 — R10 同步引擎地基

> Sprint Goal + feature roster。`/sydusx-portfolio`(2026-09-03,R10 分解确认)。

## Sprint Goal

server 同步核心硬化(并发序列化/设备身份/PullChanges 业务表/冲突检测基础)+ client 设备接入与拉取——多设备的数据一致性地基。

## Feature roster(依赖排序)

- [x] **feature F16** server-sync-hardening — server 同步核心硬化 ✅ done(2026-09-03,merge `d9dc34ec`;版本序列化[唯一约束+重试,PG 并发实证]/设备身份[幂等+硬化]/PullChanges 真分页/冲突检测跳过制[双 payload]/mapError 保真/ADR-5 复合PK不迁移;8 硬伤清账[6 修 2 F11 已修];TDD 54 新测;顺手修 4 存量缺陷;契约登记)
- [ ] **feature F17** client-device-pull — client 设备身份与拉取

## defer

- F18-F20(sprint-2)
- R9 人工验收发现项(若有→F16 查证清单吸收)

## status: pending
