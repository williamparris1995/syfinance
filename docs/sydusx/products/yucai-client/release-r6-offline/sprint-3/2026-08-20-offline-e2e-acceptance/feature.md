# Feature — R6 三条成功判据 e2e 验收

> R6 sprint-3 feature I(release 收口;依赖 G,H)。

## Description

以 release done-criteria 的三条成功判据做端到端验收(可观察、可复跑):①**断网全新安装、无账号** → app 可启动,建账户/记账/看资产报表(全模块游客链路);②**之后联网登录** → 本地全部数据出现在服务端(条目比对);③**从不绑定** → 数据一直保留本地,app 一直可用(跨重启/升级持久)。

e2e 形式:flutter integration_test(本地 drift 内存/临时库 + 本地起 server 容器或 mock gRPC)+ 人工验收清单(桌面端真实断网场景)。产出验收记录(release gate 证据)。

## Stories

1. e2e-1 断网无账号全新安装全链路(建账户→记账→holding→报表,重启持久)
2. e2e-2 绑定上传(登录→guard→上传→服务端条目比对一致)
3. e2e-3 永不绑定(纯本地长期使用,数据完好)
4. e2e-4 登出回本地(绑定→写→登出→数据本地可见)
5. 人工验收清单执行 + 记录(release gate 证据归档)

## title

R6 e2e 验收:断网单机可用 / 绑定上云 / 不绑定永远本地

## keywords

e2e, acceptance, offline, install, bind, persistence, release gate, R6

