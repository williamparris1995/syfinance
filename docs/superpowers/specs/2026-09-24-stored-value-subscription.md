# 储值卡 + 订阅中心 落码设计(原型 v6 → 客户端/server)

> 原型:`docs/sydusx/products/yucai-client/prototype/v6/`(OD 项目 yucai-prepaid-sub-6aea,
> run 8af75d90 + aeac5789,用户 2026-09-24 拍板「没有问题,继续」)。

## 口径(与原型一致)

- **储值卡 = 资产账户 + AccountCategory.storedValue**。充值=Transfer(付款账户→储值卡);
  赠送=Income(收入类目账户→储值卡);消费=Expense(正常记账选储值卡为支付账户)。
  余额=账户 current_balance,累计充值/赠送/消费由交易记录聚合。
- **订阅中心 = 模板模块的订阅视图**(TransactionTemplate direction=Expense):
  月度等价 = amount ÷ 周期月数(monthly=1、yearly=12、weekly=52/12、custom=cycle_days→30.44/days);
  下次续费 = next_date;到期 = next_date−today ≤30;操作=暂停/恢复(现有 RPC)、编辑(跳模板页)。
  摊销(待摊资产按月转费用)v1 不做 —— 订阅中心只做「月度等价口径」呈现,报表摊销另立 spec。

## Server 改动(全部加法,无迁移)

1. `yucai/proto/account/v1/account.proto`:`ACCOUNT_CATEGORY_STORED_VALUE = 10;`
2. `account/ent/schema/account.go`:category Values + `"stored_value"`(Postgres varchar,无 check,免迁移)
3. `account/domain/valueobject.go`:const + String()/"stored_value" Parse + ToAccountType 走默认 asset 分支(无需改)
4. `account/adapter/driving/grpc/account_handler.go`:proto↔domain 两处映射(≈541/563)
5. regen:`cd yucai/proto && buf generate --template buf.gen.go.yaml`(account.proto 已在 paths);
   `cd yucai && make gen-dart` 后 `git checkout -- client/lib/proto/sync/v1/sync.pbjson.dart`(F13 补丁)
6. 校验:`go build ./... && go test ./internal/account/...`

## Client 改动

1. `account/domain/value_objects.dart`:`storedValue` 枚举 + 中文 label/description/example
2. `account/data/mappers/account_mapper.dart`:双向映射
3. `account/presentation/widgets/account_category_style.dart`:色彩/图标
4. `account_form_page.dart` + `category_fields.dart`:资产组新增「储值卡」;复用
   card_number_tail(尾号)/notes(存有效期)
5. `account_detail_page.dart`:储值卡形态下嵌 **StoredValuePanel**(照 CreditCardStatementPanel 范式):
   sum-strip 三卡(累计充值/累计赠送/累计消费,从 detail 页已载交易聚合)+
   「充值」对话框(Transfer + 可选赠送 Income 两笔,走现有 recordTransfer/recordIncome)
6. **订阅中心**:`template/presentation/pages/subscription_center_page.dart` + 路由 `/subscriptions`,
   侧栏「订阅管理」改指新页(模板页仍可从设置进入);复用 TemplateBloc(list/pause/resume)
7. 测试:stored-value 类目映射(server)、订阅中心 widget test、充值对话框 smoke;analyze 基线不变

## 明确不做(v1)

- 有效期/到期提醒字段(proto 无位)、挂失状态、退卡/转让一键分录(引导手动两笔)、
  年付待摊摊销、30 天到期推送(已有 due 体系,后续接)
