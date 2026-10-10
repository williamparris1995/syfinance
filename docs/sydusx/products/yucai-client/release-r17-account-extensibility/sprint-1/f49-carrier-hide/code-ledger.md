# F49 code-ledger

## T1 地基:Account.isSystem + AccountVisibility + 透传 — ✅ done(2026-10-10)
- 实现:agent_9ce7c850;独立复核(定向 13 测绿)通过;全量 2506 绿、analyze 零新增。
- 两轴评审:PASS。Standards 2 Minor(JUDGEMENT):①`AccountVisibility` 零生产调用点——计划内(T4 接线/T9 门),**T9 收口清单显式核对**;②`mirror_mappers.dart:3` 头注措辞漂移(ADR-4 不改该文件,注释修正归未来卡贷 bound 票 backlog)。Spec:无 finding(评审附带核证:envelope codec **现状已含** isSystem——T8 降为「核验+补测试」;FR-1 端到端待 T2)。
- 偏离核可:remote_ds comment-only;update 走 patch 语义保留置位;plugin registrant 抖动非人工改动。

## T2/T3/T6/T7/T8 批次 — ✅ done(2026-10-10,提交 755e47cf)
- 独立复核 160/160 绿;批次两轴评审:**零 Critical/Important**。Standards 无 finding×4 + T7 一 Minor(可空 port 静默 no-op,注释钉死取舍,接受)。Spec Minor-MISSING×2(T2 accountId 接线断言、T7 守卫分支测)→ 归 T10 补硬。
- **评审揪出 spec 缺口(已处置)**:编辑切换并入→独立,载体 isSystem=true 残留且无账单日(隐藏不可达+FR-5 误关风险)。→ spec FR-1 补「编辑切换同步」条款 + T10 任务。
- T3 实现偏离核可:孤儿判别收紧为「无任何 card_loan 借入债」(spec 权威表述,防解挂 e招贷 误关);T3 注释「写不幂等」nuance 记档(marker 门控下无影响)。
- T6 偏离核可:新增平行「现金分期」区块而非替换既有还款计划面板(FR-6 硬约束下正确;双面板重叠露出记档,合并形态 backlog)。

## T4 展示过滤 — ✅ done(2026-10-10,提交 87edfe2e)
- 接线 2 消费点(accounts_page 管道入口/交易账户筛选下拉);结构性排除逐点核证(loan 类载体天然不在 asset/creditCard 选择器);刻意不滤面(净资产/名称解析/镜像)全列档。
- 净资产钉死:账户页 hero 12,400/-2,400 与首页 NetWorth 160,000 双点逐位;贷款组小计=可见行之和。
- 缺口 B(debt_form 关联账户下拉含载体,任务书禁碰)→ 归 T10。
- 偏离核可:home「共 N 个账户」计数维持全量口径(既有口径含分类伪账户,单滤反而不一致);transactions 断言用计数不增(名称解析合法渲染载体名)。

## 评审带出的 backlog(非本票)
- `mirror_mappers.dart:3` 头注更新 → 未来卡贷 bound 支持票。
- 卡详情「现金分期」区块与 F48「还款计划」面板双露出的合并形态 → 候选优化票。

