# Sprint 1 — R10 同步引擎地基

> Sprint Goal + feature roster。`/sydusx-portfolio`(2026-09-03,R10 分解确认)。

## Sprint Goal

server 同步核心硬化(并发序列化/设备身份/PullChanges 业务表/冲突检测基础)+ client 设备接入与拉取——多设备的数据一致性地基。

## Feature roster(依赖排序)

- [x] **feature F16** server-sync-hardening — server 同步核心硬化 ✅ done(2026-09-03,merge `d9dc34ec`;版本序列化[唯一约束+重试,PG 并发实证]/设备身份[幂等+硬化]/PullChanges 真分页/冲突检测跳过制[双 payload]/mapError 保真/ADR-5 复合PK不迁移;8 硬伤清账[6 修 2 F11 已修];TDD 54 新测;顺手修 4 存量缺陷;契约登记)
- [x] **feature F17** client-device-pull — client 设备身份与拉取 ✅ done(2026-09-06,merge `cc118f31`;clientId 贯穿[registerDevice 幂等/push/own-echo 过滤]+PullApplier 9 路增量下行[游标 v4/先拉后推/pending 保护/下行 DELETE 无墓碑]+**孤儿台账闭环[第 9 writer,S-1 ticket 关闭]**+conflicts 最小消费+双设备 e2e;根治 regen 回滚类回归[源注解+config 双改];TDD 27 新测;三门 GREEN)

## defer

- F18-F20(sprint-2)
- R9 人工验收发现项(若有→F16 查证清单吸收)

## status: done(F16 ✅ F17 ✅,2026-09-06——R10 sprint-1 收官,多设备数据一致性地基闭环)
