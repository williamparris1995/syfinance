# Feature — repository 双源 seam + account 模块试点

> R6 sprint-1 feature C(依赖 A 的库、B 的游客态;定型范式供 sprint-2 全模块复制)。
> G2(LLD 决策):模式切换的架构 seam 在哪层,本 feature 以 account 试点定案。

## Description

repository 层引入**双源 seam**:未绑定(游客)→ 读写走本地 drift DAO;已绑定 → 现状远端 gRPC(401-refresh-retry 不变)。以 account 模块试点(列表/详情/CRUD 全链路),定型 seam 范式(候选:data source 路由层 vs repository impl 内分支,design 阶段 ADR 定案),sprint-2 按此范式机械复制到其余模块。

约束:不改 domain 层 repository 接口签名(presentation/bloc 无感);遵守 DDD 四层边界与 port 模式;照 holding/debt 复用范式。绑定后的镜像写穿透不在本 feature(sprint-3 feature H)。

## Stories

1. seam 架构定案(design ADR:data source 路由层 vs repo 内分支,grill 后落档)
2. account 本地 DAO 数据源(实现与 remote ds 同构的 port)
3. account repository 双源接线(游客→本地 / 已绑定→远端),bloc 无感验证
4. account 页面游客态全链路(无账号可建/看/改/删账户,断网可用)
5. 范式文档化:seam 接线步骤清单写入 design.md(sprint-2 复制依据)
6. 测试:游客 CRUD 本地 / 绑定走远端 / 模式切换后数据源切换

## title

repository 双源 seam 定型 + account 模块试点(游客本地读写)

## keywords

dual source, seam, repository, account, guest, local dao, R6, G2
