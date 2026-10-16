# v18 components

> R21 表单 UX 治理。基准页 `ui/debt-form-ux.html` + `ui/yucai-ux-fixes.html`(OD 拍板 2026-10-15)。令牌延续 v17;交互规范=[ux-interaction.md](../../ux-interaction.md)。

## ProductScenarioPicker(产品场景卡 · F62)

- **purpose**:表单首问——用用户语言(借钱到银行卡/信用卡里的分期/房贷·车贷/亲友借款)推导债务分类;角标露映射;「更多类型」入口展开完整枚举保底。
- **states**:默认/选中(强调色描边+角标)/编辑态反选(按存量 subtype);键盘可达。
- **token**:surface/border/accent/accentSoft。
- **location**:debt-form-ux 区块二;Flutter 落 debt 表单(F62)。

## FilteredAccountPicker(灰显过滤选择器 · F62/C②)

- **purpose**:联动约束=灰显+原因句(如「信用卡不能作为到账卡」);冲突在设计上不可能;替代事后警示条。
- **states**:可选(正常)/不可选(灰显+原因)/当前选中。
- **location**:debt-form-ux 区块二;Flutter 落 debt 表单到账卡/挂卡选择器。

## ProgressiveFormSections(渐进披露三段 · F62/B)

- **purpose**:①基本(债权方/本金/期数)+期供实时预览 ②到账与还款 ③高级默认折叠(「已收起 N 项」);折叠头箭头旋转。
- **location**:debt-form-ux 区块二。

## ErrorRetryView(错误重试视图 · F63)

- **purpose**:统一错误态——警示图标+消息+「重试」主钮+次级动作(返回列表);替代 9 页纯文案错误。
- **states**:错误/重试中(spinner)。
- **location**:yucai-ux-fixes 区块三;蓝本 transactions_page _ErrorView。

## InlineFieldError(行内校验 · F63/E①)

- **purpose**:字段红描边+下方错误文案(失焦即验);提交钮随可提交性禁用;替代提交后 toast 连弹。
- **location**:yucai-ux-fixes 区块二。
