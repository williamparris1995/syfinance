# F49 code-ledger

## T1 地基:Account.isSystem + AccountVisibility + 透传 — ✅ done(2026-10-10)
- 实现:agent_9ce7c850;独立复核(定向 13 测绿)通过;全量 2506 绿、analyze 零新增。
- 两轴评审:PASS。Standards 2 Minor(JUDGEMENT):①`AccountVisibility` 零生产调用点——计划内(T4 接线/T9 门),**T9 收口清单显式核对**;②`mirror_mappers.dart:3` 头注措辞漂移(ADR-4 不改该文件,注释修正归未来卡贷 bound 票 backlog)。Spec:无 finding(评审附带核证:envelope codec **现状已含** isSystem——T8 降为「核验+补测试」;FR-1 端到端待 T2)。
- 偏离核可:remote_ds comment-only;update 走 patch 语义保留置位;plugin registrant 抖动非人工改动。

## 评审带出的 backlog(非本票)
- `mirror_mappers.dart:3` 头注更新 → 未来卡贷 bound 支持票。
