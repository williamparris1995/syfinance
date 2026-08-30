# Feature — D1 收益引擎本地化(R7 sprint-3 feature D)

> R7 收官件;算法资产复用 R5-G(oracle 齐全);β 双源语义。

## Description

XIRR/TWR/CAGR Dart 引擎移植(归一化+Brent+GIPS 三态;G 测试用例逐值 oracle)+ 本地 performance 装配(trades 现金流+成交价 ffill)替换 throw + 双源 β(guest 本地/绑定 server/绑定断网 fallback 本地+离线口径标注)+ 曲线 best-effort。R6 defer 的「收益引擎离线化」补齐,R7 done-criteria 最后一块。

## Stories

1. return_engine 纯函数移植(xirr/brent/twr)+ G oracle 全量测试
2. 本地装配:_local.getPortfolioPerformance(现金流/终值/ffill TWR/foot 指标)
3. repo β 接线(绑定断网 fallback)+ 离线口径标注字段
4. 曲线 best-effort + 页面优雅降级
5. 打包版冒烟(guest 数值可见/断网 fallback)

## title

D1 收益引擎本地化(XIRR/TWR Dart 镜像+双源 β)

## keywords

xirr, twr, brent, return-engine, local, offline, performance, mirror, D1
