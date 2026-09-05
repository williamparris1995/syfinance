# Task Brief F14-T1 — 疑点修复:路由+endDate+回拉

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f14`,客户端 `yucai/client/`。**TDD(每修先红测)。**

## 疑点事实(F6/查证在案)

- **#1 路由**:`app/app_shell.dart:242` 导航「订阅管理」→ `/accounts/templates`;`app/router.dart` 无此路由 → 被 `/accounts/:id` 捕获进账户详情。**架构约定:静态子路由必须在 /:id 前**。修法:router 加静态路由(指向模板页——设置页入口用的同一页面组件,读 settings_page 的周期模板跳转形态确定复用目标)。
- **#2 endDate**:`template/data/template_local_ds.dart:365-373` `_nowDate()` 兜底(null/空/不可解析 endDate);调度 `_catchUpOne` 对 endDate ≤today 截断 → **null 语义应为永续(不截断)**。查证范围:proto/存储的 endDate 形态(空串?null?)、`create`/`record`/`advanceNextDate`/scheduler 全触点、backup envelope 兼容、guest 与镜像路径。修法方向:解析层 null/空 → 语义 null(永续);**不可解析串**仍可兜底今天(fail-closed 注释)或同样永续——实现者查证后定并注释;存量库中已被 `_nowDate()` 存进去的值不动(数据不迁移,注释说明)。
- **#3 交易回拉**:`transactions_page` 顶栏创建表单(`_openCreateForm` 路径)提交 pop 后不重载——F6 查证"仅 _openCreateForm 路径 reload 缺失"(对照其余路径已有 reload)。修:pop 后触发既有 Load 路径(保留筛选,照 F7 语义)。
- **#4 持仓回拉**:`holdings_page` TradeSheet pop 后不重拉(无 RouteAware/reload)。修:同 #3 模式(sheet 关闭回调重载 bloc/DS)。

## 交付物

每项:先红测(修前行为复现)→ 修 → 绿:

1. **#1**:widget/router 测试(点「订阅管理」→ 模板页而非账户详情;`/accounts/:id` 仍正常);router 静态路由注册(顺序合规)。
2. **#2**:DS/scheduler 单测(null endDate 补账不截断到今天——跨多期;空串同 null;有 endDate 照旧截断);全触点改造+注释。
3. **#3#4**:widget 测试(表单提交 pop 后列表含新交易/新持仓——mock 或真 DS);页面改造。
4. **F10-T3 集成测试适配**:offline_sync_pipeline 等曾对 #3/#4 有"规避"注释的测试,修复后按需恢复直测(找到 TODO/规避注释同步)。

## 验证

新单测绿(先红后绿)+`flutter test` 全量不回归(≥1449)+analyze 新改动 0 条。

## 约束

R8 令牌;中文注释;不改 F10-F13 语义;不 commit。完成后报告(含 endDate 语义裁决与理由)。
