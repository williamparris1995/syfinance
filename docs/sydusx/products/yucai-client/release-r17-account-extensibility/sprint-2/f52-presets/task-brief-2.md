# T2 表单预填通道
account_form_page.dart:构造参数 `AccountPreset? preset` + `bool preselectCreditCard=false`;initState 回填(类别=creditCard;name/institution 控制器;biling/repayment 控制器当非 null);预填态在表单头部渲染 muted chip「预设 · 可修改」(提交不持久,零存储面);额度空聚焦(既有必填校验天然覆盖)。日期空且 preset!=null 时 helperText=hint。T1 的 AccountPreset 契约按 spec LLD(字段名 name/institution/billingDay/repaymentDay/hint)。
测试(既有 account_form 测试文件增组):花呗预填全字段可改/白条 hint/普通信用卡仅类别/无参现状零 diff(既有测全绿)。只跑本文件+既有 form 测。
