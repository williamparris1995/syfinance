# Feature — F32 hero 验收缺陷修复(R13 sprint-2)

> 2026-09-16。用户真机验收 dashboard 发现;挂载位置经用户拍板(R13 sprint-2)。

## Description

两处验收缺陷:

1. 净资产 hero 大卡负数显示错位:−195,616 显示为 `-,195,616` —— home_page 顶层千分位分组函数把负号计入字符长度定位逗号,负号后多出一个逗号。该函数是 home_page 三处共用(净资产大卡直传带符号值 / 收支卡与 prog-amt 已先行 abs 化),故仅净资产大卡可见。
2. hero 径向光晕被 Stack 默认 Clip.hardEdge 裁在内容框上,呈直边方块残块;设计本意是负偏移溢出至卡缘、由 HeroShell 卡面 antiAlias 按卡片圆角裁(hero_shell 头注「内层 clip 以裁住内容 Stack 里的负偏移金晕」)。home 净资产 hero 与账户详情 hero 同款同修。

## Stories

- [ ] S1: 千分位分组负数安全(先拆符号再按数字部分定位),负净资产 widget 回归测(−195,616 正确显示;`-,` 禁现)
- [ ] S2: 两 hero Stack 放行溢出(Clip.none,卡面圆角接管裁剪),双份 hero 主题跟随测试补 clip 结构断言
- [ ] S3: 门(client 全量 flutter test + flutter analyze 维持基线)

## Keywords

`hero` `净资产` `总净资产` `千分位` `负数` `光晕` `金晕` `dashboard` `net worth` `glow` `Clip.none`
