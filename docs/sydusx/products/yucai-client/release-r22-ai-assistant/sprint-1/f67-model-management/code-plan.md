# F67 code-plan

> /sydusx-execute 2026-10-23。批次:[T1]→[T2]→[T3] 串行;SDD(子代理+两轴评审)。

- [ ] T1 domain 契约 — model_state.dart(sealed 五态+值相等+ASCII)/model_manager_port.dart(ModelManagerPort+ModelManifest 四钉死常量[repo/file/sha256/bytes])+单测
- [ ] T2 实现+换绑 — http_downloader.dart(abstract ModelHttpClient 缝+dart:io impl)/model_manager_impl.dart(@LazySingleton(as: ModelStore) 双面:下载编排/.part/源回落一次/流式 sha/进度节流 200ms/暂停恢复取消/删除联动 shutdown/占用版本)/DI 换绑/F66 ModelStoreImpl 退役删除/mock http 全单测
- [ ] T3 集成+全门 — loopback 四场景集成测(Range 续传/暂停恢复/取消/sha 不符)+全量门(test/analyze 459/server 零 diff)+覆盖表 code-ledger.md
