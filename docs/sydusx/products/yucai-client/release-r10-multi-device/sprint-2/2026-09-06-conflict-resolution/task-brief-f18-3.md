# Task Brief F18-T3 — 冲突面板 UI + 双设备冲突 e2e + 全量门

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r10-f18`,客户端 `yucai/client/`。T1(8864ddee)+T2(931821ba)已就绪。

## 先读(必读)
1. `docs/.../2026-09-06-conflict-resolution/{spec.md FR-5/8,design.md ADR-5}`
2. `lib/binding/presentation/widgets/sync_status_badge.dart`(F12 badge——扩展点)、`lib/binding/domain/offline_sync_port.dart`(ConflictPage/SyncConflictInfo)、`lib/app/router.dart`(bind-only 前缀先例 `/settings/backup`)
3. `lib/core/localdb/envelope_codec.dart`(per-module 键知识——FieldFormatter 数据源)、F9 DebtSearchSortBar 共享控件先例
4. `integration_test/link_offline_sync_e2e_test.dart`(fake 三能力扩展点:push conflicts 可编程/listConflicts/resolveConflict)

## 交付物
### 1. ConflictFieldFormatter(`lib/binding/presentation/widgets/` 或合适处)
纯函数:module+payload JSON → 2-3 关键字段摘要行(List<String>「名称:xxx」「金额:¥xx.xx」「日期:xx」)——9 模块各自键选取照 envelope_codec 注释知识;坏 payload 容错(「(无法解析)」)。

### 2. ConflictListBloc(`lib/binding/presentation/bloc/`)
事件:Load(首页/刷新)/LoadMore(nextToken)/ResolveConflictRequested(conflictId,resolution);状态:loading/loaded(items+totalCount+hasMore+resolving)/error;port.listConflicts/resolveConflict 经构造注入;解决成功→刷新首页(权威计数);事件命名照 ...Requested 惯例。

### 3. ConflictPanelPage(`lib/binding/presentation/pages/`)
- 路由 `/settings/conflicts`(bind-only 前缀,照 backup 先例);标题「同步冲突」+总数。
- 条目卡:模块徽章(中文模块名映射)+ createdAt 相对时间 + **双栏对照**(「服务端版本」/「我的版本」各 FieldFormatter 摘要,server/client payload 解码)+ 操作按钮「保留服务端」「保留我的」(resolving 中禁用)。
- 分页:滚动到底 LoadMore(或「加载更多」钮——选简单);空态「无待处理冲突」。
- R8 语义令牌(context.yucai,禁硬编码色);中文文案。

### 4. badge 扩展
`SyncStatusBadge`:`conflictCount>0 且非 syncing/failed` → amber 色调 chip「冲突 N」onTap→`context.push('/settings/conflicts')`;优先级:syncing>failed>冲突>pending>隐藏;四态+冲突态共 5 态测试。

### 5. e2e:双设备冲突全链(FR-8)
fake 扩展:push 响应 conflicts 可编程(server 检测太重,fake 直接返回预设 ConflictDTO);listConflicts(fake 维护 conflicts 列表,resolve 时移除);resolveConflict 记录。
新测试(F13 文件或新文件进 E2E_FILES):设备 A 断网写→push OK(fake log);**模拟设备 B**:换 clientId+硬删 A 行+种同 id 不同内容行(模拟 B 独立编辑同实体)→push→fake 返回 conflict(server 检测的 fake 模拟)→断言:本地行标 synced(确认)+协调器 conflicts 列表携带;面板打开(fake listConflicts)→条目渲染双栏摘要→点「保留我的」→fake resolveConflict 被调+面板刷新空;badge 冲突态渲染(onTap 可达)。

### 6. TDD
- bloc:Load/LoadMore/Resolve 三事件+error;widget:面板渲染/双栏/操作回调/空态/resolving 禁用/badge 5 态;formatter:9 模块摘要+坏 payload。

## 验证
1. 新单测绿(先红后绿)
2. `flutter test` 全量(≥1504)+analyze 0 新增
3. e2e 新测试单文件跑绿+`make client-e2e` 全量(12 文件)+`client-e2e-ui F=<badge 涉及>` 抽验(badge 变更→app_shell 测试适配)
4. `go test ./...`(server 不动保险)

## 约束
R8 令牌;中文注释/文案;F12 badge 四态语义零破坏(仅插入冲突分支);不 commit。完成后报告。
