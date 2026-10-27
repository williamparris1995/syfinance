/// F64 助手地基 —— 工具契约(FR-1/ADR-1:进程内注册表,不上 MCP)。
///
/// 每个可被 LLM 调用的本地能力实现 [AssistantTool];结果统一为
/// [ToolResult] 结构(JSON 数据 / 可自纠错误),金额口径由具体工具
/// 保证 cents 整数 + 元两位小数字符串双口径(ADR-6)。
library;

/// 助手工具契约(name/description/schema 直接进入 LLM 上下文)。
abstract class AssistantTool {
  /// 唯一名:域前缀 + 动词式(如 networth_snapshot),约束
  /// `[A-Za-z0-9_-]`(OpenAI function name 合法字符集)。
  String get name;

  /// 何时用 / 何时不用(自描述,注册表序列化进 tools schema)。
  String get description;

  /// 参数 JSON Schema(OpenAI tools function.parameters 形状)。
  Map<String, Object> get parametersSchema;

  /// 执行(参数为 LLM 产出的原始 map;非法参数应返回 [ToolError]
  /// 而非抛异常,供 agent loop 回传自纠)。
  Future<ToolResult> execute(Map<String, Object> args);
}

/// 工具执行结果(两态;执行方永不抛异常冒泡,失败也走 [ToolError])。
sealed class ToolResult {
  const ToolResult();
}

/// 成功:结构化 JSON payload(cents + 元双口径,NFR-2 聚合摘要)。
class ToolData extends ToolResult {
  const ToolData(this.json);

  /// 结果树(可整树 jsonEncode)。
  final Map<String, Object> json;
}

/// 失败:自解释可自纠信息,回传 LLM 让其改参重试(FR-3;连续达上限
/// 由 agent loop 终止循环)。英文消息,零敏感数据携带。
///
/// F70-T3 最小扩(豁免面):部分错误额外携 [guideHint] 结构标记 ——
/// T1 写工具的消歧错误原为纯文案无标记(v20 V4 引导卡需要结构化判型),
/// 扩枚举不改既有消息文案/调用方,T1 测试面零扰动。
class ToolError extends ToolResult {
  const ToolError(this.message,
      {this.guideHint, this.guideName, this.guideAmountYuan});

  final String message;

  /// 引导标记(null = 普通自纠错误;非 null = agent loop 旁路发
  /// ToolGuidance 事件 → bloc 映射 GuidanceMsg 引导卡,v20 V4)。
  final ToolGuideHint? guideHint;

  /// 引导实体名(如零命中的账户/分类名;[guideHint] 非 null 时有值)。
  final String? guideName;

  /// 引导参数行金额(v20 V4「金额 ¥12.00」行;请求金额的元两位小数串,
  /// [guideHint] 非 null 时可携 —— 评审 T3-M2:卡不丢请求上下文)。
  final String? guideAmountYuan;
}

/// 引导标记协议(F70-T3 v20 V4 查无实体引导):unknown-account 型
/// ToolError 的结构化判型 —— 写工具解析口述账户/分类名零命中时携带
/// (add 的 account 与 category / update 的 new_account 与 new_category;
/// 分类 = 收支型科目账户,account-as-category 同一引导与跳转,FR-4)。
/// 消费链:tool → agent loop(ToolGuidance 事件)→ bloc(GuidanceMsg)
/// → 引导卡。
enum ToolGuideHint {
  /// 账户/分类名零命中(→ 引导卡「新建账户」跳 /accounts;不静默代建,
  /// FR-4「账户/分类不存在时引导」——分类即账户,同一账户页表单可达)。
  unknownAccount,
}
