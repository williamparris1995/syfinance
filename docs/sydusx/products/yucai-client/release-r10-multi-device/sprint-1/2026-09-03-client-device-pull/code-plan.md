# Code Plan — F17 client 设备身份与拉取

## Tasks

- [x] **T1 地基+设备身份**:gen-dart(activate+regen+diff 验证)+AGENTS.md 修正;clientId 注入+RegisterDevice 绑定接线+port deviceId 真实化+PushResponse 接收(conflicts 映射);单测+全量门。
- [x] **T2 PullApplier+编排**:增量 applier(envelope→drift upsert/delete+墓碑+pending 保护)+游标存储+coordinator 拉取编排(回网先拉/push 成功后拉/分页循环);**台账查证→holding_ledger 范围裁决→实施或 defer**;单测+e2e fake 扩展(RegisterDevice/PullChanges 实现+双设备场景)。
- [x] **T3 全量门**:flutter test/analyze/make client-e2e 全量+client-e2e-ui(F13 契约文件重点)+go test(server 若动)+提交。

## 执行方式

T1→T2→T3 串行派发,每任务两轴 review,修复循环 ≤5。


## Ledger 记账

| task | 状态 | fix-rounds | 记事 |
|---|---|---|---|
| T1 地基+身份 | ✅ | 0(review 6PASS,README 补录) | RegisterDevice 需 proto 字段(header 路不可行查证);gen-dart holding stub 顺补 R5-H 遗留;F13 pbjson 补丁 regen 后须重套(已警示) |
| T2 applier+台账 | ✅ | 1(4 minor:fail-closed 探针腐化/头注/gofmt/README) | 台账裁决=实施(server 有存储查证);下行 DELETE 不写墓碑(乒乓回声论证,review 采纳) |
| T3 门+补丁 | ✅ | 1(A12 死锁:regen 回滚 66a9e0e9 手工 hotfix→**源注解+config 双改根治**) | 全量门拦下 regen 类回归的价值实证;毒丸钉游标为 fail-closed 取舍留 F18 复议 |
