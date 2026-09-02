# Spec — F6 E2E 全模块关联链路补全

> R8 sprint-2 · 2026-09-02 · analysis 阶段产出(grill 收敛后用户确认)。
> 基础设施基线:commit 90d0f5c2(integration_test 三套件 + YUCAI_DB_FILE 隔离 + make client-e2e)。

## Goal

把 client E2E 覆盖从「页面可达/数据可见 + 4 条 R7 链路」补全到「每个模块和关联性都测」:从代码写管道侧系统枚举全部跨模块链路,补齐缺口;建立**两层测试入口**(管道模式默认回归 + 全 UI 点按手动按需);数据生命周期保持「种子注入 → 断言 → 测后删库」,作为模块修改后的标准回归手段(手动触发)。

## Requirements

### Requirement: FR-1 债权收回链路(管道)

- [ ] 系统 SHALL 支持应收期次收回的跨模块断言:收回动作产生资金账户入账与应收余额下降、期次状态翻转。

#### Scenario: 收回一期应收

- GIVEN 自包含夹具:应收账户(借出双写产物)+ 已知期次
- WHEN 调用收回(管道层,与 UI 同写管道)
- THEN 资金账户余额 + 期次金额;应收余额 − 期次金额;期次状态→已收

### Requirement: FR-2 订阅→自动记账链路(管道)

- [ ] 系统 SHALL 支持订阅模板到期自动记账的确定性断言:`AutoRecordScheduler.run(today)` 补账生成交易、余额变化、游标前移;endDate 截断边界成立。

#### Scenario: 到期订阅确定性补账

- GIVEN 夹具:autoRecord 订阅模板,nextDate < today(无 endDate)
- WHEN 直接调用 `scheduler.run(today)`
- THEN 生成 N 笔交易(按周期数,字段来自模板);资金账户余额按 N×金额变化;nextDate 前移至未来

#### Scenario: endDate 截断

- GIVEN 同上但 endDate < today
- THEN 补账笔数截至 endDate,游标不越过 endDate

### Requirement: FR-3 模板一键记账链路(管道)

- [ ] 系统 SHALL 支持模板应用的记账断言:交易按模板字段(账户/分类/金额)入列,余额联动。

#### Scenario: 应用模板

- GIVEN 夹具:已知字段的记账模板 + 关联资金账户
- WHEN 应用模板(管道层 record)
- THEN 交易入列且字段与模板一致;账户余额按金额变化

### Requirement: FR-4 标签跨模块链路(管道)

- [ ] 系统 SHALL 支持标签的跨模块断言:打标签的交易在标签维度可查、报表聚合口径包含标签交易。

#### Scenario: 标签交易跨模块可见

- GIVEN 夹具:已知交易打 2 个标签
- WHEN 按标签查询交易 / 按标签口径聚合
- THEN 该标签下交易列表与夹具一致;聚合数值 = 手算 oracle

### Requirement: FR-5 预算×分类消耗链路(管道)

- [ ] 系统 SHALL 支持预算消耗的跨模块断言:预算内分类的支出即时反映为预算已用/余额变化。

#### Scenario: 记一笔消耗预算

- GIVEN 夹具:分类 X 的月度预算 + 已知期初
- WHEN 记一笔分类 X 支出(管道层)
- THEN 预算已用 + 金额、余额 − 金额(手算 oracle)

### Requirement: FR-6 目标注资链路(管道)

- [ ] 系统 SHALL 支持目标注资的跨模块断言:注资产生目标进度与来源账户余额联动;完成状态翻转边界成立。

#### Scenario: 注资推进目标

- GIVEN 夹具:目标 + 来源账户已知余额
- WHEN 注资一笔(管道层)
- THEN 目标进度按比例增加;来源账户余额 − 注资额

#### Scenario: 完成翻转

- WHEN 注资使进度 ≥ 100%
- THEN 目标状态翻转为已完成

### Requirement: FR-7 持仓买入链路(管道)

- [ ] 系统 SHALL 支持持仓买入的镜像断言(补全 R7 只测卖出的缺口):买入产生资金账户扣款与持仓增加。

#### Scenario: 买入建仓

- GIVEN 夹具:资金账户已知余额 + 标的
- WHEN 买入(管道层)
- THEN 资金账户余额 − 买入额;持仓数量/成本按 FIFO 口径增加

### Requirement: FR-8 报表聚合 oracle(管道)

- [ ] 系统 SHALL 支持报表聚合的手算 oracle 断言:N 笔已知交易 → 分类饼图/收支趋势/月对比的聚合数值 = N 笔之和(现有 A10 只测页面地标)。

#### Scenario: 聚合数值 oracle

- GIVEN 夹具:跨月、跨分类、跨类型的 N 笔已知交易
- WHEN 查询报表聚合(管道层,与报表页同查询管道)
- THEN 分类饼图占比、月度收支、月对比数值均 = 手算 oracle

### Requirement: FR-9 数据变更级联链路(管道)

- [ ] 系统 SHALL 支持改/删/归档的级联断言:交易编辑→余额重算;交易删除→余额回滚;账户归档→状态变化。账户 `delete` 的级联语义(阻止 vs 级联)由 design 阶段查明后定断言。

#### Scenario: 编辑重算

- GIVEN 夹具:已知交易与其余额影响
- WHEN update 交易(改金额/改账户)
- THEN 余额按新值重算(旧影响回滚+新影响入账)

#### Scenario: 删除回滚

- WHEN delete 该交易
- THEN 余额回滚至交易前基线

#### Scenario: 账户归档

- WHEN 账户置 archived
- THEN 账户状态变化,余额口径按产品语义(design 裁决)断言

### Requirement: FR-10 备份归档往返(管道)

- [ ] 系统 SHALL 支持本地归档的完整往返断言:exportAll → 清库 → importAll → 8 类实体(accounts/transactions/debts/budgets/goals/tags/templates/holdings)全量一致。

#### Scenario: 导出恢复一致

- GIVEN 夹具库(含全部 8 类实体已知数据)
- WHEN exportAll → 清测试库 → importAll
- THEN 逐模块实体与导出前快照一致(id/字段级)

### Requirement: FR-11 条件项(design 裁决进/出)

- [ ] design 阶段 SHALL 对以下两项做事实裁决,通过则纳入对应链路文件,不通过则记入排除:① 预算跨月滚动重置(取决于聚合 API 是否日期入参确定性);② 多币种×报表换算(取决于报表是否做 FX 换算;若纯显示切换则并入设置显示链)。

### Requirement: FR-12 入口 B UI 链(手动)

- [ ] 系统 SHALL 提供全 UI 点按链路套件(独立文件,不进默认回归):每个链路组 ≥1 条 UI 链(约 10 条),覆盖订阅真实启动接线、模板一键按钮、代表性别记账表单流(收入/支出/转账)、收回/买入/注资表单、预算创建+消耗显示、标签页筛选交互、备份归档入口可达(原生对话框为止)、列表筛选/搜索交互。

#### Scenario: 订阅启动接线(UI)

- GIVEN 夹具:已到期订阅模板已注入测试库
- WHEN 按真实启动序列拉起 app(复刻 main.dart,含 bootstrapNotifications)
- THEN 启动接线自动补账,交易入列、订阅管理页期次状态正确

### Requirement: FR-13 测试入口与数据生命周期

- [ ] 系统 SHALL 提供两个明确入口并保持数据生命周期:入口 A `make client-e2e`(管道链路,默认回归,文件按链路组隔离串行);入口 B `make client-e2e-ui`(UI 链,手动按需)。两入口均:注入种子 → 断言 → 通过后删除测试库;真实库(yucai.db)零接触。

### Requirement: FR-14 列表查询断言(双层)

- [ ] 系统 SHALL 覆盖列表查询操作:管道层逐维断言 `TxnFilterState` 筛选(类型四态/账户/分类/月份)+ 搜索查询 + 默认排序序(日期倒序);入口 B UI 链真实点选筛选器/输入搜索词断言列表变化。分页与用户自定义排序不存在(见排除项)。

## NFR

- **NFR-1 隔离与清理**:全部测试经 `YUCAI_DB_FILE=yucai_test.db` 跑;真实库零接触;测试通过后测试库删除(含种子与夹具)。
- **NFR-2 确定性**:无真实定时器/时钟等待;夹具日期相对化;断言用前后差值或手算 oracle,不用绝对时间敏感值。
- **NFR-3 串行与残留清理**:每个集成文件单独跑(Windows 设备启动竞争);每文件跑前杀 `yucai_client` 残留进程。
- **NFR-4 运行时预算**:入口 A(默认回归)总时长与现有 3 文件同数量级;UI 链(慢)仅入口 B 手动。
- **NFR-5 种子幂等与夹具自包含**:demo_seed 幂等可重复注入;链路夹具用独立前缀、与演示数据零耦合、链路间互不污染。

## Scope boundary(排除项,均经挑战)

| 排除 | owner | 理由(defended) |
|---|---|---|
| 服务器加密备份路径(backup_page gRPC) | server 线测试 | 离线 guest 模式无服务器,不可测;用户确认(决策 3) |
| OIDC 登录链路 | R4 Task13 联调(blocked-on-user) | 离线无头环境不可测 |
| 绑定镜像 bound_mirror 上传 | server 线 | 同离线排除 |
| 提交 hook 自动回归 | 无(用户决策) | 用户拍板手动触发,不拖慢提交(brainstorm) |
| 分页 / 用户自定义排序 | 无 | 功能不存在(查证 2026-09-02:列表全量加载,无排序控件),无可测对象 |
| 真实定时器等待路径 | 无 | 实现无周期定时器(触发=启动+连通性,查证);NFR-2 确定性原则 |

## Grill record

| 决策 | 挑战 | 辩护/定案 |
|---|---|---|
| 断言层级 | UI 点按全测慢且脆 vs 管道模式有表单提交盲区 | 用户设计:两层测试——管道优先,出问题手动调全 UI 点按;两个明确入口 |
| 订阅触发 | 用户提案"定时器改 1 秒测完恢复" | 事实推翻:实现无周期定时器(启动即跑);定:入口 A 直接 `run(today)` 确定性补账,入口 B 真实启动序列覆盖接线;复刻 main.dart 序列的维护成本用户接受 |
| 备份层级 | 服务器加密备份排除的代价 | 用户接受:离线无服务器是环境定义;本地归档管道层全量往返,UI 止于入口可达(原生对话框无头不可入) |
| 文件组织 | 1 文件快 vs 隔离 | 用户定隔离(按链路组拆文件);随后用户挑战完整性——矩阵从代码枚举,缺口 12 买入/13 报表 oracle/14 级联补入,15/16 条件项 |
| 入口 B 范围 | 关键子集留残留盲区(表单接线坏了抓不到) | 用户定:加 UI 链,每链路组 ≥1 条(~10 条) |
| 链路深度 | 用户问:增删查改/筛选分页排序搜索是否覆盖 | 定:链=增→查→边界;改/删/归档集中 FR-9;筛选/搜索/默认排序入 FR-14(双层);分页/自定义排序不存在故排除 |

## Feasibility

- **technical 可行**:全部依赖 API 事实已查证(`run(today)` 入参确定性;exporter/importer 纯数据层;repo update/delete/archived 存在;TxnFilterState 四维筛选)。
- **economic 可行**:复用既有 harness/夹具模式,零新基建;成本为编写与运行时。
- **operational 可行**:两 make 目标即入口,手动触发;隔离库生命周期已有先例(90d0f5c2)。
