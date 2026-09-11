# Spec — F19 非空账号绑定合并

> R10 sprint-2 · 2026-09-06 · analysis 产出(查证:合并=sync push+镜像拉回,server 零改动)。

## 查证事实基线

- **合并实质已由 F10-F18 机制覆盖**:PushChanges 对不同 id 全 CREATE 落库(零冲突)/同 id 同 payload canonical 短路/同 id 不同版本进 F18 冲突面板;push 后 mirror+pull 收敛两端并集。
- **backup 上传路径是覆盖不是合并**(purgeAndImport 恒 purge),server 侧无空账号守卫(纯 client 守卫)。
- **缺口①**:guest 期行 syncState=synced,PendingCollector 只收 pending——本地全量不在现有 push 通路上。
- **缺口②**:全量单批无拆分——grpc 默认 4MB 接收上限+server 单事务,几千笔触顶。
- blocked UI 现状:仅退出向导,无合并选项。

## Requirements

- **FR-1 合并入口**:绑定向导守卫非空时不再 blocked——新状态 `readyToMerge`(:双按钮「合并上传」/「取消」);确认文案解释合并语义(「服务端已有 N 类数据;本地数据将与之合并:新增项追加、同名/同 id 项若内容不同将进入冲突面板待你裁决」);空账号路径(readyToUpload)零变化。
- **FR-2 全量标记 pending**:合并确认后 `markAllPendingForSync()`(8 头表全行 guest synced→pending;幂等;墓碑表不动[guest 删除不记墓碑,F10 语义])——此后本地全量进入现有 PendingCollector 通路。
- **FR-3 批次拆分 push**:合并流程专用 `pushAllInBatches()`(协调器或 binding bloc 层):收集全量批次→按条数拆(建议 200/批,按序列化尺寸~安全余量;常量注释)→逐批 push(每批独立 writeBack[版本守卫+确认语义]+进度回调;批间失败可重试整体);全部完成→refreshAll 镜像→markBound→registerDevice→成功(本地=两端并集)。F18 冲突(同 id 异 payload)在各批响应携带→badge 自然出现。
- **FR-4 空账号快路径保留**:readyToUpload(空)仍走既有 exportAll→uploadBackup 单向覆盖(语义不变);**或者**统一走合并路径(空时合并=纯上传,效果等价)——**推荐统一**(减一路径;查证:uploadBackup 覆盖语义在空账号下与合并 push 等价;但保留快路径成本更低——设计裁量,倾向统一走 push 以消除 backup 上传面)。
- **FR-5 向导 UI**:`readyToMerge` 状态卡(服务端数据摘要:账户 N/交易 N/持仓 N)+ 合并确认 dialog(强调不可自动撤销,建议先备份——链接到既有本地备份入口文案);uploading 态进度(批次 i/N);成功/失败态沿用。
- **FR-6 测试与门**:binding bloc(readyToMerge/确认→markAllPending/批次 push 序列/中途失败重试);批拆分单测;e2e fake 扩展(push 批次模拟已收数据 server——fake 预置 server 端行+冲突场景);全量门零回归。

## NFR

单设备零回归(空账号绑定路径行为不变或等价);R8 令牌;中文注释/文案。

## Scope boundary

| 排除 | 理由 |
|---|---|
| server 侧任何改动 | 查证:零改动即安全 |
| 同名实体自动去重融合(不同 id 同名账户=两条) | 语义正确(个人数据无外键式唯一名);用户手动清理 |
| 合并进度持久化/断点续传 | 向导内完成,中断重走;YAGNI |
| backup 上传路径删除 | 留作 cloud 恢复通道(F20 评估) |

## Grill record

| 决策 | 定案 |
|---|---|
| 合并路径 | client sync push(候选 B)——查证论证 server 零改动,F18 机制全覆盖 |
| 空/非空统一 vs 双路径 | 推荐**统一走合并 push**(消除 backup 上传面;空时等价纯上传)——技术推荐 |
| guest 行进入通路 | 全量标记 pending(批量 UPDATE,非逐行)——最简 |
| 批大小 | 200/批(尺寸+事务平衡;常量可调)——技术推荐 |

## Feasibility

technical ✓(查证:通路全在,仅缺收集标记+拆分);economic ✓(纯 client);operational ✓(e2e fake 可模拟)。
