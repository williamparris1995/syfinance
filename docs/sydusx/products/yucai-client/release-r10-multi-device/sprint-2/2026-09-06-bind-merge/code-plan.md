# Code Plan — F19 非空账号绑定合并

## Tasks

- [ ] **T1 全量标记+合并链+向导 UI**:markAllPending DAO×8+binding_bloc 状态机扩展(readyToMerge/确认/批推/断点续传/进度)+binding_page UI+统一 push 路径(空/非空);TDD(bloc/DAO/UI)。
- [ ] **T2 e2e+全量门**:fake 预置 server 数据+合并全链 e2e(推→并集→冲突 badge)+三门全绿+提交。

## 执行方式

T1→T2 串行派发,T1 两轴 review,修复循环 ≤5。
