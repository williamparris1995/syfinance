# Feature — F6 E2E 全模块关联链路补全(R8 sprint-2)

> 2026-09-02 brainstorm 拍板:正式 feature;4 组链路全做;回归保持手动 `make client-e2e`。

## Description

复用既有 E2E 基础设施(integration_test 三套件 + `YUCAI_DB_FILE=yucai_test.db` 隔离库 + 种子注入→断言→测后删库生命周期 + `make client-e2e` 一键回归,commit 90d0f5c2),把覆盖从"页面可达/数据可见 + 4 条链路(借款还款/持仓卖出/转账/借出双写)"补全到"每个模块和关联性都测":新增 4 组跨模块链路的交互级断言,并扩展幂等种子支撑。约束:真实库(yucai.db)永不被触碰;每个测试文件单独跑(Windows 设备启动竞争),跑前杀残留实例。

## Stories

1. 订阅→自动记账链路:种子订阅模板期次到期 → 本地调度器(autoRecord,B2 基础)生成交易 → 资金账户余额变化 + 订阅管理页期次状态联动
2. 模板链路:模板一键记账 → 交易按模板字段(账户/分类/金额)入列
3. 标签链路:打标签的交易 → 标签页可见可筛,报表聚合联动
4. 预算联动:记一笔分类支出 → 该分类预算余额即时消耗(手算 oracle)
5. 目标联动:目标注资 → 目标进度 + 来源账户余额联动
6. 债权收回链路:应收期次收回 → 资金账户入账 + 应收余额下降
7. 备份往返:导出 → 恢复 → 全模块数据一致断言
8. 种子扩展:为 1-7 补幂等种子夹具(demo_seed 模式,绝对断言成立)
9. 回归收编:新测试文件纳入 Makefile E2E_FILES,`make client-e2e` 一键全量;测后删库生命周期不变;触发保持手动

## title

F6 E2E 全模块关联链路补全(订阅/模板标签/预算目标/债权备份)

## keywords

e2e-links, module-chain, subscription, template, tag, budget, goal, receivable, backup-restore, regression, seed, client-e2e, F6
