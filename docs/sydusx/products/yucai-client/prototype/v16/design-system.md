# Prototype v16 — 面包屑统一 + 右下悬浮操作簇(F58 壳层导航地基)

> tier: high-fi(design)· path: OD 管线(项目 `crumb-nav-variants`,run `3f25a96c`,2026-10-12;用户在应用内浏览器过目拍板,形态 B 竖排 FAB 堆叠)。
> 底版:design-output-v2/ab 套件(debts.html + account-detail.html fork,零硬编码令牌,双主题)。

## 内容(F58 的 UI 事实源)

- **crumb-nav-variants.html(对比页,四区块)**:
  - 区块一 现状还原:两层面包屑叠加(顶栏纯文本 + 详情页 64px AppBar)三问题标注。
  - 区块二 统一方案(实现基准):顶栏单层全路径 `section › <a>page</a> › <b>current</b>`——page 级 link 色 + hover 下划线可点回退,section 纯标签,current 加粗;第二层整条退役,hero 上移;右下悬浮簇。
  - 区块三 形态 B(**已拍板**):竖排 FAB 堆叠——主 FAB 52px 金渐变圆(--fab-bg/--fab-shadow 语言)+ 其上次级钮 44px 方圆(surface+border);常驻不折叠;底部留白 ≥242px 防遮挡;形态 A 横排胶囊留参考。
  - 页尾对比表:六维 × 现状/方案A/方案B,B 列挂已拍板徽标(用户 2026-10-12 裁定)。
- **两组件契约见 components.md**(FloatingActionDock / CrumbNav,Flutter 实现归属与令牌缝在 F58 design.md ADR-2/4)。
- LLD 对原型有意偏差(F58 评审留档,F59 沿用须知):次级钮半径 14→12;次级图标 --fg→muted;次级钮阴影省略;FAB 内 9.5px 文字→纯 icon+tooltip;dock 视觉上下序与原型互倒(LLD「列表首项最贴 primary」)。

## Constraints(people / data / finance / process)

- **people**:单用户桌面键鼠操作者;tooltip + Tab/Enter 键盘可达为硬性(NFR-4);不可逆操作(删除/关闭账户)必须确认。
- **data**:零 schema/proto 改动;标题通道仅内存显示层数据;样例禁止真实 PII(掩码卡号/虚构 counterparty)。
- **finance**:悬浮簇操作全部复用既有资金流处理器,禁止新增金额计算路径;卡贷禁用态遵 F48(防双重支付)。
- **process**:脏表单离开必须先确认(用户拍板 2026-10-12);回归门 = flutter test 全绿 + analyze 基线 + make client-e2e。

## CURRENT

v16(F58 壳层导航地基;用户 2026-10-12 拍板形态 B;v15 为 F57 存档)。
