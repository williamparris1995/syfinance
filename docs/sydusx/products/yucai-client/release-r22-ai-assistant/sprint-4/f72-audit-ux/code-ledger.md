# F72 code-ledger

> /sydusx-execute 任务台账(task done / fix-rounds / rulings)。批次:T1→T2 串行(SDD);T2 为接管收尾轮(前实现者中途限额中断,半成品接管补残)。评审由控制器另行安排,本表先落事实。

- **T1 DAO 搜索+分组+复制 ✅ done**(commit 2e6cb130;`agent_audit_dao.dart` watchPage/count 增 `keyword?`(summary LIKE '%kw%',`%/_/\` ESCAPE 转义;null/空白=全量)+ `agent_audit_dialog.dart` v22 三增强(分组段头今天/昨天/前天/yyyy年M月d日+段内计数+跨页续组 / 标题下搜索框 300ms 防抖+副行双态+空匹配态 / 行包 ContextMenuRegion 右键「复制摘要」→Clipboard+AppToast)。新增 13 用例(实测:dao 4→9 +5,dialog 15→23 +8);F71 既有 25 行分页测抬窗 1600→2000(F72 搜索框+段头加高,25 行出视口;断言语义不变)。门:test/assistant+DAO 450 全绿 / analyze 466 零新增 / server diff 空。
- **T2 以此再记一笔+全门+覆盖表 ✅ done**(接管收尾轮,commit 见 git log `feat(assistant): F72-T2 以此再记一笔+全门(接管收尾)`)。四件:`data/note_parser.dart`(AddActionFromNote.parse:「已记:支出 ¥35.00 午饭」→方向/金额/描述三要素;改/删族与失败行 ASCII 回退形态 → null)+ bloc `ProposeFromHistoryRequested`(解析 → 默认推导取名 → transaction_add_tool execute 全套消歧 → `_insertPendingCard` 公共体(F70 loop 提案共用,**新 uuid 键**);解析 null/账户池读失败/ToolError → 统一 ErrorMsg「无法从该记录生成提案」;addTool/accounts 可选缝 = 特性惰性,旧装配零扰动)+ 对话框记行可点(`tool == 'transaction_add'` 行 `_ReproposableRow` hover surfaceAlt+右缘「以此再记一笔 ›」accent 提示;改/删行纯透传零手势)+ `AssistantReproposeInbox`(ChangeNotifier getIt 懒单例总线)接线:对话框 request(note)→ AssistantOverlayHost 订阅消费 → `bloc.add(ProposeFromHistoryRequested)` + 打开浮层+预热;host 缺省从 getIt registry 按名取 transaction_add 工具+AccountRepository(guarded)。新增 20 用例(实测:note_parser 9[与 _writeNote 成对往返 3——真 executor 真库生成侧/直接解析 2/畸形 null 4] + bloc 5 + dialog 2 + 集成 4)。零生产事故面:接管线全 guarded,bloc 缺席请求即丢弃。**接管修复三件**:①analyze 6 新增(4×note_parser_test 未用 import/mock 类 + 2×bloc 测试局部 `_acc/_fullPool` 下划线)清零;②集成测①「testWidgets 点确认 → drift 写」10min 死等 → 双区家法重写(见偏差①);③本 code-ledger 补建(F72 格式照 F71)。

## 需求覆盖对照表(T2 汇总;spec FR/NFR ↔ 测试,零 BLOCKED)

测试根 `yucai/client/test/`(T1=core/localdb dao + presentation/widgets dialog,T2=data + presentation + integration 帽石)。

| 需求 | 场景/SHALL | 测试文件 | 用例名(断言要点) | 判定 |
| --- | --- | --- | --- | --- |
| FR-1 按日期分组(T1) | SHALL 日历日分组段头+组内倒序;翻页跨日续组 | `core/localdb/agent_audit_dao_test.dart` + `assistant/presentation/widgets/agent_audit_dialog_test.dart` | dao `watchPage 排序锚`(倒序次锚既有)+ dialog 分组段头用例(今天/昨天/前天/yyyy年M月d日 不补零,groupLabel 纯函数;跨「加载更多」续组)——T1 提交面 | ✓ |
| FR-2 摘要搜索(T1) | Scenario 搜索过滤(DAO 层 LIKE,非仅已加载页) | `core/localdb/agent_audit_dao_test.dart` | `keyword 子串匹配/转义 %_\/空串=全量/大小写 SQLite 语义/分页滑窗` 5 用例(T1 实测 +5)+ dialog 搜索框双态/防抖/空匹配 widget 面 | ✓ |
| FR-3 行复制(T1) | Scenario 复制反馈(右键→剪贴板+toast) | `assistant/presentation/widgets/agent_audit_dialog_test.dart` | 右键菜单项+剪贴板内容断言+AppToast「已复制」(T1 提交面;ContextMenuRegion 照 R16 先例) | ✓ |
| FR-4 再记一笔 SHALL 仅记行可点 | 点击关对话框→开浮层→预填确认卡新键 | 集成 `repropose_pipeline_integration_test.dart`①② + `agent_audit_dialog_test.dart` F72 组 | 集成①②:testWidgets 真链(真库+真工具+真 host guarded getIt 全生产解析+真对话框)点行 → 对话框关+浮层开+engine 预热 → pending 卡(新键 ≠ 原确认实例键/支出 ¥35.00 午饭/默认推导 acc-cash 资产优先+acc-food/preview 名称)→ **点击本身交易/审计/余额全零动** / dialog:`记行 onTap:关对话框 + note 原样上抛(getIt inbox 总线)`(summary 人话单源串原样) | ✓ |
| FR-4 Scenario 再记全流程 | 确认→新交易落库(原交易不动)+审计新行;取消→无副作用 | 集成 ③ + 取消 | ③(纯 test 真事件循环,生产形状装配:bloc 直驱,note=原行 summary 读表原样):提案零落库 → 确认 → 恰两笔(原笔 version/description 不动;新笔 午饭/日期缺省今天[工具时钟]/分录 debit=餐饮 credit=现金/余额 -3500 联动)→ 审计恰两行(新行 ok/summary 人话单源/键=卡键≠原键/entityId=新交易)→ 卡 confirmed → 同键二次确认幂等零双写 / 取消:pending 卡 cancelled,交易/审计/余额零动 | ✓ |
| FR-4 Scenario 改/删行只读 | 点击改/删行无交互(不可点态) | `agent_audit_dialog_test.dart` + 集成④ | dialog:`改/删行只读:点击零上抛零关闭;提示仅记行`(短种子恰 1 笔 add →「以此再记一笔 ›」恰 1)/ 集成④:改/删行点击 → 对话框不关+浮层不开+FAB 在+零落库 | ✓ |
| NFR-1 确认门不变 | 再记 MUST 走完整确认门;点击本身零落库断言 | 集成①③ + `assistant_panel_bloc_test.dart` F72 组 | 集成①:点行后交易/审计/余额三面零动 / 集成③:提案步零落库(执行器不可达),落库唯 ConfirmWriteRequested 通道 / bloc:`零 executor 调用`(FakeWriteExecutor.calls 空)×4 用例共断 | ✓ |
| NFR-2 server 零改动 | git diff yucai/server 为空 | 非测试:全门 | `git diff main -- yucai/server` **0 字节** + server 子目录 status 0 行(T1/T2 每票全门复测通过) | ✓ |

> 漏项检查:spec ADDED 6 条需求(FR-1..4 + NFR-1..2)全部有对应测试/门,**零 BLOCKED**。

## F72 专属用例实测合计

T1 13(dao +5/dialog +8)+ T2 20(note_parser 9 / bloc 5 / dialog 2 / 集成 4)= **33**;test/assistant 门 **461 绿 + 1 自跳过**(= F71 修复轮 433 + T1 8 + T2 20;F66 engine_smoke 引擎夹具自跳,与本票无关)。

## 执行期偏差记档(T2 接管收尾沉淀)

1. **双区家法(集成测形态学,接管修复)**:前实现者集成测①整链 testWidgets(点历史行→确认→落库)在确认步 **10min 死等超时**——根因 = 写路径 `_insertWithEntries` 在 drift transaction 内 `watchEntriesByTransaction(id).first`(QueryStream 的零长 Timer 链),fake-async 假时钟区下即便 settle() 连续 pump 推进假时钟、外层 runAsync 喂真实事件循环,该 Future 均永不完成(接管期 debug 夹具实证:`done=false` 1s 真实时间 + pump 后仍挂)。**修法**:四断言链分层——①②④ 留 testWidgets(UI 点击链,全程零写,假时钟稳定);③ 确认写照 F70/F71 帽石范式改**纯 test() 真事件循环直驱 bloc**(生产形状装配:registry.findByName 同源 addTool+AccountRepository,executor 4 参构造真 sink;note=原行 summary 读表原样=生产「对话框行 summary 上抛」同串),dialog onTap→inbox 与 host inbox→浮层开接线已由①②④ UI 链实证,③从 bloc 事件面续接,断言零删(原①的全部断言保留,另加同键二次确认幂等)。重写后 4/4 首跑 2s 全绿。**后续家法:凡要走本仓 drift 写路径(含确认/重试)的集成测,一律纯 test() 真事件循环;testWidgets 只承载零写 UI 链**(F71 ledger 偏差④的 drift watch Timer 面在写路径的强化版)。
2. **接线选型实录(ADR-4 分支裁决)**:bloc **非 getIt 注册**(生命周期由 AssistantOverlayHost 内建持有,浮层开合不销毁)→ 对话框(设置卡 showDialog 弹出)直接 getIt bloc 不可达;设置卡亦不持有 host 引用、对话框路由上下文寻不到 host state,回调逐级上抛链在现有装配下断链。**取 event-bus 分支**:`AssistantReproposeInbox`(ChangeNotifier,懒单例,纯内存 last-wins,消费即清)——对话框 request(note) → host initState 订阅 → 消费后 `bloc.add(ProposeFromHistoryRequested)` + 未开则开浮层+ensureReady 预热。对话框侧 guarded(未注册静默零副作用);注入缝 onReproposeNote 优先(测试面)。
3. **默认推导的确定性形态(ADR-3 落地)**:note 串中无账户/分类 → bloc 按账户池推导取名(付款户 = 首个可见**资产**户,无资产户才落首个负债户;分类 = 方向匹配科目池首个)→ 再经工具 execute 全套名称→id 消歧(池空 → 不传名 → 工具规范 ToolError 照常可出 → 统一 ErrorMsg 文案)。推导差异由确认卡如实呈现,确认门兜底(design Risk 钉定);集成③断言 acc-cash 资产优先(负债户先插仍让位)。
4. **半成品 analyze 残留(接管修复)**:note_parser_test 4 处未用 import/mock 类、bloc 测试 2 处局部函数下划线命名 lint,共 6 条(472≠466)→ 清零回 466 基线;另 linux/macos/windows generated_plugin_registrant 系 flutter 命令行噪声(内容零变仅行尾),checkout 还原不入 commit。

## 全门输出(T2 接管收尾轮实测)

- `flutter test test/assistant/`:**461 绿 + 1 自跳过**(`All tests passed!`;含集成 4/4)。
- `flutter analyze`:**466 == 基线零新增**。
- `git diff main -- yucai/server`:**0 字节** + server 子目录 status 0 行(NFR-2 实测)。
