# Code Plan — F17 client 设备身份与拉取

## Tasks

- [ ] **T1 地基+设备身份**:gen-dart(activate+regen+diff 验证)+AGENTS.md 修正;clientId 注入+RegisterDevice 绑定接线+port deviceId 真实化+PushResponse 接收(conflicts 映射);单测+全量门。
- [ ] **T2 PullApplier+编排**:增量 applier(envelope→drift upsert/delete+墓碑+pending 保护)+游标存储+coordinator 拉取编排(回网先拉/push 成功后拉/分页循环);**台账查证→holding_ledger 范围裁决→实施或 defer**;单测+e2e fake 扩展(RegisterDevice/PullChanges 实现+双设备场景)。
- [ ] **T3 全量门**:flutter test/analyze/make client-e2e 全量+client-e2e-ui(F13 契约文件重点)+go test(server 若动)+提交。

## 执行方式

T1→T2→T3 串行派发,每任务两轴 review,修复循环 ≤5。
