# Design: F72 审计体验增强

prototype: v22(待 OD 生成+用户过目;fork v21 审计页加:分组段头/搜索框/右键菜单/记行可点态)

## Context

spec:[spec.md](spec.md)(四项用户拍板);F71 对话框/DAO 与 F70 确认门全链在;右键菜单先例=R16 桌面文本票。

## Decisions(ADRs)

- **ADR-1 搜索=DAO 层** — watchPage 增 keyword? 参数(summary LIKE '%kw%',转义 %_);count 同参;过滤态独立分页重置。
- **ADR-2 分组=纯渲染** — 已加载行按日历日聚合段头(复用 T2 相对时间纯函数族);跨页续组;搜索态照分组。
- **ADR-3 再记提案=摘要解析器** — `AddActionFromNote.parse(note 串)`:自家 note 格式(「已记:支出 ¥35.00 午饭」)确定性解析出方向/金额/描述;账户/分类**不**从 note 猜(串中无)——提案时按 F70 工具同款默认推导(描述→分类/默认资产账户),用户在确认卡可改?不可改(v1 确认卡无编辑)→ 描述保留,分类账户按推导,差异由确认卡呈现如实;改/删行零解析。
- **ADR-4 注入路径** — 对话框行点击→回调上抛→设置卡→event bus?最短:bloc 直接可达(AssistantPanelBloc 全局 getIt)——注入 `WriteProposed` 等价事件:bloc 新 event `ProposeFromHistory(action)`→生成新 uuid 键→pending 卡;浮层打开由 overlay host 监听 pending 卡出现(既有挂载逻辑自然承接,若未开则 host 打开)。
- **ADR-5 复制=ContextMenu 先例** — 行包 ContextMenuRegion(照仓内右键先例)单项「复制摘要」+Clipboard+AppToast。

## HLD/LLD

```
daos/agent_audit_dao.dart  +keyword 参数(LIKE 转义)
presentation/widgets/agent_audit_dialog.dart  分组渲染+搜索框+行右键+记行 onTap
assistant/data/note_parser.dart  AddActionFromNote(纯函数+测)
presentation/assistant_panel_bloc.dart  +ProposeFromHistory 事件
```

## Risks

- [note 解析与格式漂移] — 解析器与 _writeNote 格式成对测(生成→解析往返);格式变即红。
- [搜索转义] — %_ 转义测试。
- [再记提案推导差异] — 确认卡如实呈现推导结果;确认门兜底。

## Migration Plan

纯增强零迁移;回滚=还原对话框。

## Open Questions

- v22 形态拍板(用户)。
