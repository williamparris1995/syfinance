# account form 对齐 OD 原型 · 设计 spec

- **日期**: 2026-07-12
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: account form 对齐 OD `form-account.html`,3 改动(cat-hint banner + notes 字段 + dynTitle badge),**全 client-only**
- **上游 memory**: `ui-align-visual-companion-workflow`(account form 下个优先级)

## 1. 背景

account form([account_form_page.dart](../../yucai/client/lib/account/presentation/pages/account_form_page.dart))未对齐 OD 原型(OD MCP `yucai-account-prototype-65e6` / `form-account.html`),3 差距(visual companion side-by-side 确认):

1. **cat-hint**:Flutter 用纯 `Text(_category.description)`([:371](../../yucai/client/lib/account/presentation/pages/account_form_page.dart#L371));OD 是 `.cat-hint` banner(`accent-soft` 背景 + 边框 + info icon + hint 含 `<b>示例</b>`)
2. **notes**:Flutter 无;OD 有 `textarea`(备注 section,placeholder"补充说明…")
3. **dynTitle badge**:Flutter FormSection title 只 `${category.label}信息`;OD 有 `资产/负债` badge

**notes 后端已就绪**:proto `AccountDTO.Notes *string`(field 20,optional)+ `GetNotes()` + client `CreateAccountParams.notes`/`UpdateAccountParams.notes` 都有。gap 纯 client form 没用。

## 2. 目标

account form 对齐 OD `form-account.html`,3 改动,全 client-only(零 proto/server)。

## 3. 范围边界

| 在范围 | 不在范围 |
|---|---|
| cat-hint banner(替 Text description) | account list/detail 对齐(已 done) |
| notes 字段(TextFormField + 传 params + 预填) | proto/server 改动(notes 后端已有) |
| dynTitle badge(FormSection trailing) | 其他模块 |

## 4. 决策记录(brainstorm 拍板)

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 范围 | 全修(3 差距) | 完整对齐 OD,client-only 工作量可控 |
| 2 | cat-hint hint 内容 | `description + example` | OD hint 含示例;`AccountCategory.example` 9 类从 OD 提取 |
| 3 | FormSection badge | 扩 `Widget? trailing` | 复用,默认 null 不破坏 8+ 调用 |
| 4 | notes | client-only(传 params + 预填) | proto + params 已有 notes,零后端改动 |
| 5 | badge 样式 | `accentSoft` bg + `accentHover` 文字(对齐 OD `.badge` 金色 pill) | OD `.badge` 金色调;Flutter 无 accentPress,用 accentHover #9C7A48 代(接近 OD #98773f) |

## 5. 架构与组件

3 改动(全 client-only):

| 改动 | 文件 | 职责 |
|---|---|---|
| ① cat-hint banner | `account_form_page.dart` + `value_objects.dart` | 替 Text(description) → banner widget + `AccountCategory.example` |
| ② notes 字段 | `account_form_page.dart` | `_notesCtrl` + 备注 FormSection + TextFormField + 传 params + 预填 |
| ③ dynTitle badge | `account_form_page.dart` + `form_section.dart` | FormSection 加 `trailing` + `_kindBadge` |

**零 proto/server**(notes 后端已就绪)。

## 6. cat-hint banner

### 6.1 AccountCategory.example(value_objects.dart)

`AccountCategory` 加 `example` getter(9 类示例,从 OD `CATEGORIES[].hint` 提取):

```dart
String get example {
  switch (this) {
    case AccountCategory.savings: return '招行储蓄卡、工行活期';
    case AccountCategory.creditCard: return '招行 Visa、中信万事达';
    case AccountCategory.investment: return '华泰证券、蚂蚁财富';
    case AccountCategory.fixedDeposit: return '招行大额存单';
    case AccountCategory.goldFx: return '实物黄金、美元 USD';
    case AccountCategory.realEstate: return '朝阳区房产';
    case AccountCategory.loan: return '招行房贷';
    case AccountCategory.otherAsset: return '公积金账户';
    case AccountCategory.otherLiability: return '亲友借款';
  }
}
```

### 6.2 _catHintBanner widget(account_form_page.dart)

替 [:371-373](../../yucai/client/lib/account/presentation/pages/account_form_page.dart#L371) 的 `Text(_category.description)` + SizedBox:

```dart
Container(
  margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.lg),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
  decoration: BoxDecoration(
    color: AppColors.accentSoft,            // #F3ECDD
    border: Border.all(color: const Color(0xFFE8DCC4)),
    borderRadius: BorderRadius.circular(9),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(LucideIcons.info, size: 15, color: AppColors.accent),
      const SizedBox(width: 8),
      Expanded(
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '${_category.description}  '),
            const TextSpan(text: '示例:', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.accentHover)),
            TextSpan(text: _category.example),
          ]),
          style: const TextStyle(color: Color(0xFF7A6433), fontSize: 13, height: 1.55),
        ),
      ),
    ],
  ),
)
```

## 7. notes 字段

### 7.1 _notesCtrl + 预填

`_AccountFormPageState` 加 `final _notesCtrl = TextEditingController();`。
- `initState` 编辑预填:`_notesCtrl.text = e.notes;`(在现有预填块末尾)
- `dispose`:`_notesCtrl.dispose();`

### 7.2 备注 FormSection

在 category 信息 section 后、`FormActions` 前加:

```dart
const SizedBox(height: AppSpacing.lg),
FormSection(
  title: '备注',
  children: [
    TextFormField(
      controller: _notesCtrl,
      maxLines: 3,
      decoration: const InputDecoration(
        hintText: '补充说明,如账户用途、关联卡片、还款提醒等(可选)',
      ),
    ),
  ],
),
```

### 7.3 传 params

`_buildCreate` 加 `notes: _notesCtrl.text.trim(),`。`_buildUpdate` 加 `notes: _notesCtrl.text.trim(),`(params.notes 是 String 默认 '',空串 = server-side optional 不修改)。

## 8. dynTitle badge

### 8.1 FormSection 扩 trailing(form_section.dart)

```dart
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.children,
    this.fieldSpacing = AppSpacing.md,
    this.trailing,            // 新增,可选
  });

  final String title;
  final List<Widget> children;
  final double fieldSpacing;
  final Widget? trailing;     // 默认 null → 不破坏现有调用

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) SizedBox(height: fieldSpacing),
        ],
      ],
    );
  }
}
```

### 8.2 _kindBadge(account_form_page.dart)

```dart
Widget _kindBadge(AccountCategory c) {
  final isAsset = c.accountType != AccountType.liability;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.accentSoft,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      isAsset ? '资产' : '负债',
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentHover),
    ),
  );
}
```

category section([:420](../../yucai/client/lib/account/presentation/pages/account_form_page.dart#L420))加 trailing:

```dart
FormSection(
  title: '${_category.label}信息',
  trailing: _kindBadge(_category),
  children: categoryFieldsWidget(_category, _bundle, currencySymbol: currencySymbolOf(_currency)),
),
```

## 9. 测试

- **AccountCategory.example**:`value_objects` 测,9 类非空(投资 → '华泰证券、蚂蚁财富' 等)
- **account_form_page widget test**:
  - cat-hint banner 渲染(description + "示例:" + example 文本)
  - notes TextFormField 渲染 + 输入 → submit 传 `CreateAccountParams.notes`
  - 编辑预填 notes(`existing.notes`)
  - dynTitle badge(资产/负债,category 切换变)
- **FormSection trailing**:默认 null(现有调用不破坏)
- **回归**:account 现有测不破(`account_detail_page_test` 预存 fail 跳过,out-of-scope)

## 10. 风险

1. **FormSection 加 trailing 影响 8+ 调用**:默认 null 不破坏,但需 grep 确认所有 FormSection 调用无 break(签名加可选参数,向后兼容)
2. **AccountCategory.example 9 类示例文本**:从 OD 提取,需校对(投资/贷款 等)
3. **notes 传 params 语义**:params.notes 是 String 默认 '';空串 = server-side optional 不修改(对齐 UpdateAccount "absent = 不改"语义)
4. **AppColors token**:accentSoft #F3ECDD / accentHover #9C7A48 / accent #B08D57 已确认存在;#E8DCC4 / #7A6433 硬编码(OD cat-hint 专属,无 token)

## 11. 实施顺序(供 writing-plans,约 3 task)

```
Task 1  value_objects(AccountCategory.example 9 类)+ form_section(FormSection trailing)+ 单测
Task 2  account_form_page:cat-hint banner + notes 字段(_notesCtrl/备注 section/传 params/预填)+ dynTitle badge(trailing: _kindBadge)
Task 3  widget test(cat-hint/notes/badge 渲染 + 传 params + 预填)+ 回归(account 现有测不破)
```

## 12. 参考

- OD 原型:OD MCP `yucai-account-prototype-65e6` / `form-account.html`
- 现状:[account_form_page.dart](../../yucai/client/lib/account/presentation/pages/account_form_page.dart) / [value_objects.dart](../../yucai/client/lib/account/domain/value_objects.dart) / [form_section.dart](../../yucai/client/lib/core/widgets/form_section.dart)
- 后端 notes:[account.pb.go AccountDTO.Notes field 20](../../yucai/server/internal/proto/account/v1/account.pb.go#L274) + [CreateAccountParams.notes](../../yucai/client/lib/account/domain/repositories/account_repository.dart#L36)
- memory:[[ui-align-visual-companion-workflow]](account form 下个优先级)/ [[od-prototype-to-flutter]]
