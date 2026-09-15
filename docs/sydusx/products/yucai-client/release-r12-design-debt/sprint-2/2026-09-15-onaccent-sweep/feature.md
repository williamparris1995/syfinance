# Feature — F27 onAccent sweep(R12 sprint-2)

> 2026-09-15 F15 backlog 票承接。

## Description

F15 清零了 AppColors 静态口径,但留下了「Colors.* 裸色」backlog:accent 渐变按钮/金色徽标等 accent 面上的前景文字图标仍写死 Colors.white/Colors.black 系,未走 design-v2 的 onAccent 语义令牌(暗=#1A1408 金底深字,亮=#FFFFFF 绿底白字)——双主题下语义正确但口径游离。本 feature 全量清点→逐处判定迁移(accent 面→onAccent;非 accent 面→fg/muted 等正确语义)+ 测试守门。

## Stories

- [ ] S1: 库存清点(grep Colors.* 于 lib/,剔除令牌定义处/合法黑/白[阴影等既有豁免类目],产出迁移清单)
- [ ] S2: 逐处迁移 + 每处判定注释
- [ ] S3: 探针/既有测试守门(迁移处所在页的 theme-follow 或既有色彩断言适配)
- [ ] S4: 全量门

## Keywords

`onAccent` `裸色` `Colors` `sweep` `令牌` `token` `语义色` `design-debt`
