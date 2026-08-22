---
feature: 2026-08-20-core-modules-local
status: drafted
---

# Spec — 核心记账模块本地化(transaction/tag/template/currency)

> R6 sprint-2 feature D(依赖 A/B/C;范式=C 定型的 local ds 镜像 + repo 一行路由 + 写语义镜像)。**scope 修正:category 零改动**——client 无独立 category 模块,/categories 是 AccountRepository 的视图子集(CategoryBloc 注入 account usecases,客户端过滤 expense/income),C 已双源化,guest 路由自动生效。
> 事实基础(research 2026-08-22):transaction 9 方法(嵌套 entries 整包/游标分页/服务端聚合 summary/三 Simple* 便捷路径);tag 7 方法(含 junction 增删查);template 8 方法(record 有跨聚合副作用);currency list 单方法 + bloc 绕 repo 直连 AuthRemoteDataSource 两条 RPC。

## ADDED Requirements

### Requirement: FR-1 tag 游客全链路
- [ ] Guest 态 tag 的 list/create/update/delete/addTagToTransaction/removeTagFromTransaction/getTransactionTags SHALL 全部对本地 drift 生效(UUID 生成、version=1 起、update 前置乐观锁校验);TransactionTags 联结为本地私有表(备份契约不含,照常读写)。transaction_form_page 对 TagRepository 的跨模块直调在 guest 下自动落本地(page 零改动)。

#### Scenario: 游客建标签并打标
- GIVEN Guest
- WHEN create(name=餐饮,color=#FF0000) → addTagToTransaction(tagId, txId) → getTransactionTags(txId)
- THEN 返回含该标签;全程零网络

### Requirement: FR-2 template 游客全链路(含 record 副作用)
- [ ] Guest 态 template 的 list/create/update/delete/pause/resume/get SHALL 对本地生效(pause/resume 翻转 paused + version+1;update 乐观锁);**record(templateId) SHALL 本地联动**:按模板字段在本地创建一笔交易(经 transaction 本地写路径,复用 FR-3 语义)并推进 nextDate(按 cycle 规则:weekly +7d / monthly 次月同日 / yearly 次年同日 / custom +cycleDays),返回 RecordResult。

#### Scenario: 游客手动触发月度模板
- GIVEN Guest,模板 cycle=monthly、nextDate=2026-09-01、amount=300000
- WHEN record(templateId)
- THEN 本地新增一笔 2026-09-01 的交易,模板 nextDate 推进至 2026-10-01,返回 RecordResult

### Requirement: FR-3 transaction 游客全链路(嵌套 entries 事务性)
- [ ] Guest 态 transaction 的三 Simple*(expense/income/transfer)、复式 recordTransaction、list、getById、update、delete SHALL 对本地生效:
  - Simple* 各组**两条 balanced entries**(借贷方向与 server 对齐:expense=借 expense 贷 asset 等);recordTransaction 按提交的 entries 原样落库。
  - **头表+子表事务性写入**(drift transaction 包裹,entries 与头同成败);update 为**整包替换 entries**(旧 entries 全删再插)+ 前置乐观锁;delete 级联清 entries(FK cascade 已备)。
  - list 为本地分页模拟(按 transactionDate 倒序,pageSize/nextPageToken/hasMore/totalCount 语义与远端一致,过滤参数同语义)。

#### Scenario: 断网记账全链路(成功判据①核心)
- GIVEN Guest,本地已有现金账户
- WHEN recordExpense(100 元 餐饮)→ list → getById → update → list
- THEN 全链路成功:entries 恰两条且 balanced,列表/详情/更新后值一致,零网络

#### Scenario: entries 事务性
- GIVEN Guest
- WHEN recordTransaction 提交的 entries 中途失败(如引用不存在的账户触发约束)
- THEN 头表与子表均不落库(整包回滚)

### Requirement: FR-4 transaction summary 本地聚合
- [ ] Guest 态 summary(year, month, {accountId, scope}) SHALL 基于本地 entries+accounts 聚合,口径与远端一致(income/expense/net/dailyAvg/byDay/byCategory;byCategory 的 accountType 取本地 accounts);accountId 过滤与 scope(day/month/year)语义同远端。

#### Scenario: 游客月度汇总
- GIVEN Guest,本月两笔:餐饮 expense 50 元、工资 income 8000 元
- WHEN summary(2026, 8)
- THEN expenseCents=5000、incomeCents=800000、netCents=795000,byDay/byCategory 对应

### Requirement: FR-5 currency 列表本地化 + guest 分支
- [ ] Guest 态 currency list SHALL 读本地 drift(内置静态种子:常用币种 code/name/symbol,exchangeRate 默认 1.0 标注陈旧,绑定后首连刷新覆盖);CurrencyBloc 在 guest 态加载 SHALL 不因 preferred/intervalHours 两条直连 RPC 失败而报错(preferred 取本地 CurrencySettings 值顶替,intervalHours 取默认 24)。CurrencyRepositoryImpl SHALL 补齐 _guard/GrpcError 分类映射(对齐 account 范式,远端路径行为不变)。

#### Scenario: 游客打开设置页
- GIVEN Guest
- WHEN CurrencyBloc 加载
- THEN 币种下拉有静态种子选项,偏好货币显示本位币值,无网络错误弹窗

### Requirement: FR-6 bloc/presentation 无感 + 范式遵循
- [ ] 各模块 bloc/usecases/pages SHALL 零改动(现有测试不修改仍全绿,被改类自身的单测随构造器/内部扩展更新除外);每模块遵循 C 的四步接线清单;tag/template repo 的 _guard SHALL 补 `on Failure` 透传分支。

### Requirement: NFR-1 质量基线
- [ ] `flutter test` 基线不退化(≤ 4 fail / 3 文件);`flutter analyze` 不新增;data 层不 import presentation。

### Requirement: NFR-2 零 server 改动
- [ ] 本 feature SHALL NOT 改动 yucai/server;`go test ./...` 保持全绿。

## scope boundary

- **IN**:transaction(9 方法含 summary 聚合)/tag(7 方法)/template(8 方法含 record 联动)/currency(list+guest 分支)四模块双源化 + 静态种子。
- **OUT(修正记录)**:**category 零改动**(account 视图子集,自动继承;feature.md 原列 category 系分解时的模块名误植,实际无独立模块)/绑定后镜像(H)/绑定上传(G)/行情汇率在线刷新(无 client 调度,仅展示)/summary 与远端的逐分口径对拍 e2e(oracle 测试覆盖核心口径,全量对拍归 feature I e2e)。
- **依赖**:A(drift 表/DAO 全备)/B(Guest)/C(tracker+范式+Uuid DI)。

## 可行性

- **technical**:可行——表/DAO 全备,范式已验证;最大新面是 transaction 嵌套写入与 summary 聚合,均为本地计算无外部依赖。
- **economic**:可行——机械复制为主,transaction 是唯一重头。
- **operational**:可行——纯 client;静态种子随 app 发布无运维面。
