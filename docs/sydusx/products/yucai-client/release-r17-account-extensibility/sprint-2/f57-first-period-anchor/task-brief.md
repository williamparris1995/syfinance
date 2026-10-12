# F57 任务书(单实现者,TDD)
按同目录 spec.md(FR-1/FR-2/NFR-1)与 design.md(3 单元/ADR):
1. CreateAccountParams 旁:CreateDebtParams 增可选 `firstPeriodFromDisbursement=false`(repositories/debt_repository.dart);local DS 创建链路透传至 _flatFeeSchedule→_cardLoanScheduleDates(增 {bool currentPeriod=false}:true 时首期=start 本身,后续照既有逐月;false=现状原样);remote DS 不发(零 proto,注释钉死 guest-local 语义)。
2. debt_form_page:并入模式卡贷区常驻「首期锚点」radio 两项(次月=默认/当期=平安口径,副行实例化日期=所选起始日±1 月,随起始日联动);提交透传;独立模式不渲染;若表单有排期预览则联动。
3. 测试:生成器四例(当期/次月/1-31 起始月末钳制/存量零变化);表单三例(默认/选当期透传/独立不显示)。只跑自己文件+debt 既有相关;analyze 零新增。
禁碰:repairs/账户模块/独立模式语义。
