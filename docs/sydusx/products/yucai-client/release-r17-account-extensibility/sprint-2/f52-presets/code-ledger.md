# F52 code-ledger

> 收口全门执行档(2026-10-12,worktree r17-f52):T1-T3 完成档 + 评审结论 + 三道门结果。
> 生产代码改动 = 提交 f45231f9(T1/T2/T3)+ d8c6575f(评审注释级精化);收口期零生产代码改动。

## Tasks(T1-T3 完成档)

- [x] **T1 预设目录 domain 常量** — done(f45231f9)
  - `lib/account/domain/account_presets.dart`:`AccountPreset{name/institution/billingDay?/repaymentDay?/hint}` const 值对象 + `accountPresets` 四条常量(花呗=蚂蚁消费金融/账单 1/还款 9/hint 空;京东白条=京东、美团月付=美团、微信分付=腾讯,日期 null + hint「账单日按激活日,建后可改」)。category 恒 creditCard 不入字段(头注钉死「加速层不是类别替代」);零 import(纯 domain,NFR-2)。
  - 测试 `test/account/domain/account_presets_test.dart` **6 测**:恰四条/按序/字段完备/花呗 1+9+hint 空/白条类日期 null+hint 非空/机构与 hint 文案钉死。
- [x] **T2 表单预填通道** — done(f45231f9;评审注释精化 d8c6575f)
  - `account_form_page.dart`:`AccountFormPage({AccountPreset? preset, bool preselectCreditCard=false})`;initState **仅创建态**回填(类别=creditCard + name/institution;preset 日期非 null 连带账单日/还款日);预填角标 muted chip「预设 · 可修改」(标识来源,提交不持久,零存储面);白条类 hint 行 `_presetHint`(**条件取目录位而非控制器实时态**——用户自填日期后「建后可改」文案仍成立,spec FR-3 场景钉的是初始态;渲染在字段组尾部,不改 category_fields.dart);切类别即弃预设态(角标/hint 随 clearAll 消失);编辑/复制 seed 路径零 diff。纯 initial 注入:提交链路读控制器零改动。
  - 测试 `account_form_page_test.dart` F52 组 **4 测**:花呗全量预填全可改+额度空/白条类日期空+hint/普通信用卡仅类别预选/无参现状零 diff。
- [x] **T3 新建入口六项菜单** — done(f45231f9)
  - `accounts_page.dart`:「新建账户」三触发位(desktop 药丸钮/空态按钮/mobile 汇总卡「+」圆钮)统一 `_CreateMenuAnchor`(PopupMenuButton 包装既有触发体视觉);六项 = ①信用卡(普通,仅预选类别)/②-⑤四预设(副行:花呗「账单 1 日 · 还款 9 日」,白条类=目录 hint 单一来源)/分隔/⑥全部自定义…(现状无参路径)。
  - **菜单原语选型(ADR-4→ADR-007 次序)**:design_kit `AnchoredMenu` 的 `MenuItemData` 无副行/分隔语义,无法表达 FR-2 六项结构,扩 design_kit 越本票文件面 → 按任务书预留次序退 `PopupMenuButton`(库内先例 DebtSortControl/TxnSortControl,position.under+constraints);容器样式 = design_kit `popupMenuStyle` 同值同口径(surface/黑阴影豁免/elevation6)+ v14 .dd radius14/1px border/minWidth300。
  - **路由形态**:`AccountPreset` 构造参数**对象直传**(design LLD 两案中照 `_openEditForm` existing 先例;`(preset: null, creditCard: bool)` 值面见 `_CreateSelection`);「全部自定义」= `const AccountFormPage()` 现状路径逐位一致。
  - 测试 `accounts_page_test.dart` F52-T3 组 **6 测**:菜单恰六项+分隔+副行文案/花呗 preset 对象直传/普通项仅 preselect/自定义现状回归/空态第三触发位/mobile 圆钮。

## 评审结论(评审代理,2026-10-12)

- **P1 — FR 覆盖清单(评审已做,此处引用)**:全 FR/NFR 覆盖,零 MISSING。
  - FR-1 预设目录 → account_presets_test 6 测(目录完整性场景全钉;脱钩场景=预填纯 initial 注入+零存储面,参数面断言覆盖);
  - FR-2 六项平权菜单 → accounts_page_test T3 组 6 测(六项结构+全自定义回归两场景全钉);
  - FR-3 预填语义 → account_form_page_test F52 组 4 测(花呗/白条类/普通信用卡三场景+无参零 diff);
  - NFR-1 零 schema/proto → 分支改动面仅 account domain/presentation + 测试(proto/ent 零触碰);
  - NFR-2 目录形态 → account_presets.dart 零 import 纯常量;
  - NFR-3 门 → 本 ledger 下节三道门。
- **P3 [Minor] 「额度空聚焦」词义消解(不实施聚焦)**:spec FR-3 花呗场景「额度空聚焦」的实体语义 = 额度不预填、留空待用户补——由既有必填校验/提交流程覆盖,测试已钉死额度控制器空(`account_form_page_test` 花呗用例);「聚焦」字面(打开表单即 focus 额度框)未接线——额度字段经 `AmountInput`(`core/widgets/amount_input.dart`)渲染,该组件为 StatelessWidget,构造面无 `focusNode`/`autofocus` 参数,接线即改共享 core 组件,属本票禁改面。词义按「空」消解收口,聚焦不实施。
- **U1 [Minor] 信用卡项字牌 → icon+类目身份色(任务书口径压原型,零代码变更)**:v14 原型普通信用卡项为字牌「信」(`.di.lg-blue`,f52-preset-variants.html:304);任务书 T3 口径 =「信用卡(普通,**icon**)」——任务书口径压原型。实现即任务书形态:`_CreateMenuTile(icon: LucideIcons.creditCard,tileColor 缺省 → categoryColor(creditCard) 类目身份色)`(accounts_page.dart ①项+`_CreateMenuTile.build`);「普通」dn-chip 保留(任务书/原型两口径一致)。无需返工。
- 评审遗留落档:d8c6575f(注释级)——hint 条件取目录位的语义注释 + 切类弃预设态注释精化(评审代理提交,非生产行为变更)。

## 门结果(收口全门,2026-10-12)

- **门 1 全量 flutter test:PASS** —— 尾行 `03:16 +2629: All tests passed!`;**2629 全绿 = main 基线 2613 + F52 新增 16**(T1 六测 + T2 四测 + T3 六测;计数经 main/HEAD 测试文件 diff 逐组核证),耗时 3 分 16 秒。
- **门 2 flutter analyze:PASS(基线持平)** —— 尾行 `462 issues found. (ran in 37.5s)`;**error 恰 20、全部 *.pbserver.dart**(10 个 pbserver 文件 × 2:`ServiceBase$json`/`$messageJson` undefined_identifier,protobuf 生成物既有基线);warning 36 / info 406 与 main 同面——F52 改动文件零新增 diagnostic(account_form_page 2 条 deprecated info = main 既有 DropdownButton `value:` 用法位移;accounts_page `isLast` warning = main 既有参数)。
- **门 3 make client-e2e:PASS** —— 尾行 `client E2E: all suites passed (test DB auto-deleted)`(make exit 0);**执行面 = E2E_FILES 全 15 套件串行**(Windows 真机 `-d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`,每套件前杀残留实例,独立测试库),合计 68 用例全绿:app_pages +5 / linked_transactions +4 / link_debt_subtype +2 / **full_audit +13(1:58)** / link_receivable_collect +3 / link_subscription_template +4 / link_budget_goal +4 / link_tag_report +5 / link_holding_buy +3 / link_mutation_cascade +7 / link_backup_roundtrip +2 / link_list_unify +2 / link_offline_sync_e2e +6 / link_bind_merge_e2e +4 / financial_report_e2e +4。
  - **A2 金图注记**:本次 full_audit 全 13 测直绿,A2 `audit_menu_open.png` 金图未红——收口指令预置的「A2 环境性 2.25% diff = main 同形既有(快道 e1582fa3 后低频残留,progress.md 观察项)」免责条款**备而未用**;若后续复跑偶发红,按该既有定责口径处置,不算 F52 新增失败。

**三道门全 PASS,F52 收口成立。**
