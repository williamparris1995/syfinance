# Prototype v4 — F42 反馈表单(双通道)

> tier: high-fi(design) · path: **B-fallback 延续**(同 v1/v2/v3,OD/Penpot 不可用;项目 path 已锁定);令牌直连 design-v2 事实源(v4/tokens.css @import,不复制值;ui/ 自包含快照同 v3 惯例)。
> v3(F33 债务表单)保持为其锁定参考;本版为 F42 统一反馈表单 + 三通道提交状态,CURRENT 待用户拍板后指 v4。

## 复用声明(零新令牌;组件形态全部沿既有)

- **类型选择 = radio 卡行**:沿 v3 `.radio-card`(F33 定稿形态:icon + label,选中态 accent 描边+软底),3 项(问题/建议/其他)不加新组件。
- **正文/联系方式输入**:令牌拼装输入形态(surface-2 底+border+focus accent;同 OD 表单 .field 视觉),正文多行+字数计。
- **诊断头只读区**:muted 小字信息卡(surface-2 圆角;callout 信息语义的轻量变体,不新造 callout.pos 之外的组件)。
- **按钮**:`.btn-primary` / `.btn-ghost` 既有。
- **提示**:成功/失败 toast 沿 callout.pos 形态;失败双动作「重试/改用邮件」为按钮组合,非新组件。

## 表单字段(FR-1)

| 字段 | 形态 | 校验 |
|---|---|---|
| 类型 | radio 卡行 ×3:问题(circle-alert)/建议(lightbulb)/其他(message-circle) | 必选(默认不选,提交守卫) |
| 正文 | 多行 textarea,placeholder「请描述你遇到的问题或建议…」 | 非空;限长 1000 字符(计数器,超限禁提交) |
| 联系方式 | 单行 input,placeholder「邮箱或联系方式(选填,便于回复)」 | 选填;限长 100 字符 |
| 诊断头 | 只读 4 行(版本/平台/账户/主题)+ 隐私说明 caption | 不可编辑(F41 白名单冻结) |

## 提交通道状态表(FR-3/FR-4 行为演示,ui/feedback-form.html 可交互切换「在线/离线/上传失败」)

| 状态 | 触发 | 表现 |
|---|---|---|
| 在线直传 | 模拟=在线,点提交 | 按钮 spinner「上传中…」→ 成功 toast「已提交,感谢反馈」→ 表单关闭 |
| 离线邮件 | 模拟=离线,点提交 | 「已唤起邮件客户端(离线通道)」toast;正文并入邮件正文,URL 超限截断+「完整内容已复制」提示 |
| 上传失败 | 模拟=失败,点提交 | spinner → 失败条「上传失败,内容已保留」+ [重试](原样重发)/[改用邮件](走离线路径)双动作;表单内容不丢 |
| 限流拒绝 | 服务端 429 语义 | 失败条变体「提交过于频繁,请稍后再试」(同双动作) |

## Flutter 映射(execute 契约)

- radio-card → 房内 `_RadioCard`/ChoiceChip 形态(icon+label,选中 accent 描边/软底,照 F33 实现);lucide `circleAlert`/`lightbulb`/`messageCircle`(以包内实际命名为准)。
- textarea → `TextField(maxLines: 6)`+计数器;联系方式 → 单行 `TextField`;诊断头 → `Container(surface2)`+muted 13px 4 行。
- 挂载形态:AlertDialog(标题+内容+actions 取消/提交)——design.md LLD 定稿;视觉与本原型一致。
- toast/失败条 → SnackBar(callout.pos 语义);双动作 → SnackBarAction×2。
- 零新令牌:全部 context.yucai 既有(surface/surface2?/border/fg/muted/accent/onAccent/negative/positive——以 YucaiTheme 实际令牌名为准,execute 核对映射)。
