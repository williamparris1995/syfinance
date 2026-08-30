# Code Plan — D1 local-return-engine

- [x] **T1 引擎移植+oracle** — return_engine/{brent,xirr,twr}.dart 纯函数;G 测试用例全量移植(brent 6/xirr ~15/twr ~10/陡梯度/1e8/极端);RED=未实现编译错,GREEN=逐值对拍
- [x] **T2 本地装配** — holding_local_ds.getPortfolioPerformance:现金流/终值/ffill 价格序列/TWR 分段(三态)/foot 指标;内存 drift 单测(手算 oracle)
- [x] **T3 repo β fallback** — NetworkFailure→_local + offlineScope 字段;单测(fake ds)
- [x] **T4 曲线 best-effort** — ffill 出点;不足→空曲线;页面不炸验证
- [x] **T5 收尾** — 基线+build → code-review → commit → acceptance 冒烟清单
