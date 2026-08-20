# Feature — 核心记账模块本地化(transaction/category/tag/template/currency)

> R6 sprint-2 feature D(依赖 sprint-1 C 定型的 seam 范式,机械复制)。

## Description

按 seam 范式把核心记账模块接入本地双源:transaction(表单/列表/详情)、category、tag、template、currency(设置已本地,补齐列表数据源)。每模块:本地 DAO(对齐 A 的 schema)+ repository 双源接线 + 游客态页面可用。transaction 与 account 的关联链路(账户余额联动等)在本 feature 内本地闭环。

## Stories

1. transaction 本地 DAO + 双源接线 + 游客态全链路(建/编/删/列表/筛选)
2. category/tag 本地 DAO + 双源接线 + 游客态管理页
3. template 本地 DAO + 双源接线 + 游客态使用
4. currency 数据源本地化(汇率快照离线展示最后值,实时刷新仅在线)
5. 各模块游客态测试(范式复制的回归保障)

## title

核心记账模块本地化:transaction/category/tag/template/currency 双源

## keywords

transaction, category, tag, template, currency, local, dual source, R6

