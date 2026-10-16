# Prototype v18 — R21 表单 UX 治理(债务表单重设计 + 整改扫票)

> tier: high-fi(design)· path: OD 管线(项目 `debt-form-ux` run `85f9da58` + `yucai-ux-fixes` run `211dc521`,2026-10-15;用户逐组过目拍板)。
> 底版:design-output-v2/ab 套件(transaction-form.html / transactions.html fork)。

## 内容(R21 的 UI 事实源)

- **ui/debt-form-ux.html(F62 债务表单重设计基准)**:现状还原(10 术语下拉/全量账户/警示条)vs 重设计——产品先行 4 场景卡(角标露推导分类)/到账卡灰显过滤(不可项灰显+原因句)/载体户隐形/渐进披露三段(高级折叠「已收起 6 项」)/期供即时预览。轻交互可点验。
- **ui/yucai-ux-fixes.html(F63 整改扫票基准)**:六组前→后对照(全部可点演示)——①返回条退役+脏态守卫(F58 对话框逐字)②toast 校验→行内+按钮门 ③ErrorRetryView(图标+重试+次CTA)④2-4 值下拉→SegmentedButton ⑤可逆确认→直做+toast ⑥死按钮清理(隐藏/滚动定位)。

两组件契约见 components.md。

## Constraints(people / data / finance / process)

- **people**:单用户桌面键鼠;灰显可聚焦场景卡可键盘操作;规范全文见 [ux-interaction.md](../../ux-interaction.md)(R21 交互事实源)。
- **data**:表单重构零域层改动(白名单降为过滤器数据源);存量 subtype 编辑态反选零迁移。
- **finance**:表单仅影响录入路径,提交链路/期表生成/资金流 handler 零 diff。
- **process**:审计清单=ux-audit-r21.md;回归门 test+analyze+e2e。

## CURRENT

v18(R21 表单 UX;债务表单重设计+六组整改拍板 2026-10-15;v17 为 F59 存档)。
