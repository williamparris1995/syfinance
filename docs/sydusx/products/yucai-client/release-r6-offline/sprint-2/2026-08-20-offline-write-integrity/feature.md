# Feature — 离线写完整性(本地事务原子性 + 引用完整性 + 断网 UX)

> R6 sprint-2 feature F(依赖 D,E;单机可用的质量收口)。

## Description

全模块本地化后的完整性收口:**本地写事务原子**(多表写要么全成要么全败,镜像服务端 tx 语义);**引用完整性**(本地外键/级联删除策略对齐服务端 ent 约束,防本地库脏数据破坏绑定上传);**断网/恢复 UX**(离线时写操作成功无异常感,联网提示非强制;错误态使用现有 NetworkFailure 文案体系)。

## Stories

1. 多表写事务化(以 holding 买卖联动、transaction+账户余额为原子性 oracle 场景)
2. 引用完整性约束清单(对齐 ent FK/级联语义)+ drift 层实施 + 违例测试
3. 断网 UX:游客态全程无「网络错误」误导文案;离线/在线态 UI 指示(基于 feature B 的 connectivity 网关)
4. 本地数据一致性自检(启动时轻量校验,异常降级提示而非崩溃)
5. e2e:断网创建→编辑→删除全链路,重启后数据完好(成功判据①的模块级验证)

## title

离线写完整性:本地事务原子 + 引用完整 + 断网 UX

## keywords

integrity, local transaction, foreign key, cascade, offline ux, consistency, R6

