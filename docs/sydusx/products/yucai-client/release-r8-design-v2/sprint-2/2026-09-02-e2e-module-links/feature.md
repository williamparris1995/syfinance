# Feature — F6 E2E 全模块关联链路补全(R8 sprint-2)

> 2026-09-02 brainstorm 拍板:正式 feature;4 组链路全做;回归保持手动 `make client-e2e`。

## Description

复用既有 E2E 基础设施(integration_test 三套件 + `YUCAI_DB_FILE=yucai_test.db` 隔离库 + 种子注入→断言→测后删库生命周期 + `make client-e2e` 一键回归,commit 90d0f5c2),把覆盖从"页面可达/数据可见 + 4 条链路(借款还款/持仓卖出/转账/借出双写)"补全到"每个模块和关联性都测":从代码写管道侧系统枚举链路矩阵(详见 [spec.md](spec.md)),补齐 10 条管道链 + 2 条条件链 + UI 链全覆盖,两层入口(管道默认回归 / UI 手动按需)。约束:真实库(yucai.db)永不被触碰;每个测试文件单独跑(Windows 设备启动竞争),跑前杀残留实例。

## Stories

- [ ] S1: FR-1 债权收回链路(管道):收回 → 资金入账 + 应收下降 + 期次翻转
- [ ] S2: FR-2 订阅→自动记账链路(管道):`run(today)` 确定性补账 → 交易/余额/游标 + endDate 截断
- [ ] S3: FR-3 模板一键记账链路(管道):模板字段入列 + 余额联动
- [ ] S4: FR-4 标签跨模块链路(管道):标签维度查询 + 报表聚合口径
- [ ] S5: FR-5 预算×分类消耗链路(管道):支出 → 预算已用/余额 oracle
- [ ] S6: FR-6 目标注资链路(管道):进度 + 余额联动 + 完成翻转
- [ ] S7: FR-7 持仓买入链路(管道):资金−/持仓+(FIFO 口径,补 R7 镜像缺口)
- [ ] S8: FR-8 报表聚合 oracle(管道):N 笔已知交易 → 饼图/趋势/月对比 = 手算 oracle
- [ ] S9: FR-9 数据变更级联链路(管道):编辑重算 + 删除回滚 + 账户归档(账户 delete 语义 design 裁决)
- [ ] S10: FR-10 备份归档往返(管道):exportAll → 清库 → importAll → 8 类实体一致
- [ ] S11: FR-11 条件项裁决(design):预算跨月滚动 / 多币种换算 进/出
- [ ] S12: FR-14 列表查询断言:TxnFilterState 四维筛选 + 搜索 + 默认排序(管道层)
- [ ] S13: FR-12 入口 B UI 链:每链路组 ≥1 条(~10 条,含订阅真实启动接线、筛选/搜索交互、归档入口可达)
- [ ] S14: FR-13 入口收编:Makefile 双目标(client-e2e / client-e2e-ui)+ E2E_FILES 按链路组隔离 + 测后删库
- [ ] S15: NFR-5 种子与夹具:幂等种子扩展 + 链路自包含夹具(独立前缀)

## title

F6 E2E 全模块关联链路补全(订阅/模板标签/预算目标/债权备份)

## keywords

e2e-links, module-chain, subscription, template, tag, budget, goal, receivable, backup-restore, regression, seed, client-e2e, F6
