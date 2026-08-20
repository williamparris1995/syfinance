# Feature — 资产类模块本地化(holding/budget/goal/debt/receivable/report/networth)

> R6 sprint-2 feature E(依赖 D 的关联链路;holding 收益计算复用现有纯 Dart 领域逻辑)。

## Description

资产/负债/报表类模块接入本地双源:holding(列表/详情/买卖记录)、budget、goal、debt、receivable、report、networth。收益引擎(XIRR/TWR)为纯计算,离线可用;Yahoo 行情依赖天然在线——离线展示最后快照并标注(不做行情缓存队列,YAGNI)。holding 买卖的资金账户联动(客户端镜像服务端「双写」语义)在本地库内以事务实现。

## Stories

1. holding 本地 DAO + 双源接线 + 游客态(记录买卖/持仓列表/收益计算离线可用,行情快照标注)
2. holding 本地资金账户联动(买卖联动账户余额,本地事务,镜像服务端复式语义)
3. budget/goal 本地 DAO + 双源接线 + 游客态
4. debt/receivable 本地 DAO + 双源接线 + 游客态
5. report/networth 本地聚合(基于本地库的报表/净值计算,离线可用)
6. 各模块游客态测试

## title

资产类模块本地化:holding/budget/goal/debt/receivable/report/networth 双源

## keywords

holding, budget, goal, debt, receivable, report, networth, local, dual source, R6

