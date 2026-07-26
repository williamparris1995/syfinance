# 14 · 功能 gap · 家庭多用户(共享账本 + 应用锁)

Type: grilling
Status: open
Blocked by: —

## Question

标尺核心能力缺失(详见 `findings.md` G2/G3):

- **[G2 P0]** 家庭共享账本 + 权限角色:真缺(memory followup family tenant;当前一 tenant 一用户)。auth/tenant 已打底,但同一账本协作/聚合视图/只读 vs 编辑角色未实现。**缺此 = 产品定位未达成**(用户标尺核心)。
- **[G3 P0]** 应用锁 PIN/Windows Hello + 自动锁定 + 隐藏余额 privacy mode:真缺。OIDC 解决"是谁",应用锁解决"运行时谁能看"。桌面家庭共用场景(客厅 PC/夫妻共用笔记本)的安全闭环必备,与 AES-256-GCM 备份加密配套才完整。

**决策点:**
1. 家庭共享:tenant + member + role(只读/编辑)模型?聚合视图(家庭总净资产)+ 个人视图切换?
2. 应用锁:PIN / Windows Hello / 生物?自动锁定超时?privacy mode(一键遮罩余额)?
3. 是否走 prototype(OD)先定型共享账本 UI + 应用锁 UI?
4. 与 01 跨租户隔离的授权模型协同(role claim 进 JWT)?
