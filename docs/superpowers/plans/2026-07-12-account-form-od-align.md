# account form 对齐 OD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** account form 对齐 OD `form-account.html`,3 改动(cat-hint banner + notes 字段 + dynTitle badge),全 client-only。

**Architecture:** `AccountCategory.example` getter(9 类示例)+ `FormSection` 扩 `Widget? trailing`(默认 null 不破坏)+ `account_form_page` 替 Text → cat-hint banner、加 notes TextFormField(传 params + 预填)、category section 加 `_kindBadge`。零 proto/server(notes 后端 `AccountDTO.Notes` + params.notes 已就绪)。

**Tech Stack:** Flutter(flutter_bloc + mocktail)+ 御财设计 token(AppColors.accentSoft/accentHover/accent)。

**Spec:** [docs/superpowers/specs/2026-07-12-account-form-od-align-design.md](../specs/2026-07-12-account-form-od-align-design.md)

## Global Constraints

- **全 client-only** —— 零 proto/server 改动(notes 后端 `AccountDTO.Notes` field 20 + `Create/UpdateAccountParams.notes` 已就绪)
- **中文 UI 直写**(项目惯例,非 i18n);lucide icons
- **`flutter analyze`** 基线 22 error 全 `*.pbserver.dart`(客户端未用)—— 不暴增
- **回归**:account 现有测不破(`account_detail_page_test` 预存 fail 跳过,out-of-scope)
- **复用** `FormSection`/`FormCard`/`FormRow`/`TypeTabs`/`AccountCategory`;AppColors token(`accentSoft` #F3ECDD / `accentHover` #9C7A48 / `accent` #B08D57)

## File Structure

| 文件 | 责任 | 动作 |
|---|---|---|
| `yucai/client/lib/account/domain/value_objects.dart` | `AccountCategory.example` getter(9 类示例) | Modify |
| `yucai/client/lib/core/widgets/form_section.dart` | `FormSection` 加 `Widget? trailing` | Modify |
| `yucai/client/test/account/domain/value_objects_category_test.dart` | example 单测 | Modify |
| `yucai/client/lib/account/presentation/pages/account_form_page.dart` | cat-hint banner + notes + dynTitle badge + 传 params + 预填 | Modify |
| `yucai/client/test/account/presentation/pages/account_form_page_test.dart` | widget test(渲染) | Create |

---

### Task 1: AccountCategory.example + FormSection trailing

**Files:**
- Modify: `yucai/client/lib/account/domain/value_objects.dart`(`AccountCategory` 加 `example`)
- Modify: `yucai/client/lib/core/widgets/form_section.dart`(`FormSection` 加 `trailing`)
- Test: `yucai/client/test/account/domain/value_objects_category_test.dart`(加 example 测)

**Interfaces:**
- Consumes: 无(domain 基础)
- Produces: `AccountCategory.example`(String getter,9 类)、`FormSection.trailing`(Widget? 可选)。Task 2 用。

- [ ] **Step 1: Write the failing test**

追加到 `value_objects_category_test.dart`(`import 'package:flutter_test/flutter_test.dart'` 已有;`value_objects.dart` 已 import):

```dart
  test('AccountCategory.example 9 类非空 + 含示例文本', () {
    expect(AccountCategory.values.length, 9);
    expect(AccountCategory.savings.example, '招行储蓄卡、工行活期');
    expect(AccountCategory.creditCard.example, '招行 Visa、中信万事达');
    expect(AccountCategory.investment.example, '华泰证券、蚂蚁财富');
    expect(AccountCategory.fixedDeposit.example, '招行大额存单');
    expect(AccountCategory.goldFx.example, '实物黄金、美元 USD');
    expect(AccountCategory.realEstate.example, '朝阳区房产');
    expect(AccountCategory.loan.example, '招行房贷');
    expect(AccountCategory.otherAsset.example, '公积金账户');
    expect(AccountCategory.otherLiability.example, '亲友借款');
    for (final c in AccountCategory.values) {
      expect(c.example.isNotEmpty, true, reason: '$c.example 非空');
    }
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd yucai/client && flutter test test/account/domain/value_objects_category_test.dart`
Expected: FAIL(`example` getter undefined)。

- [ ] **Step 3: Add AccountCategory.example**

在 `value_objects.dart` `AccountCategoryX` extension(现有 `label`/`description`/`accountType` getter 后)加:

```dart
  /// 该 category 的示例账户(对齐 OD cat-hint 的"示例"部分)。
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

- [ ] **Step 4: Add FormSection.trailing**

Modify `form_section.dart` `FormSection` —— 加 `trailing` 字段 + build title 用 Row:

```dart
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.children,
    this.fieldSpacing = AppSpacing.md,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final double fieldSpacing;
  final Widget? trailing; // 可选 title 右侧 widget(如 badge);默认 null 不破坏现有调用

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
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

- [ ] **Step 5: Run test to verify it passes + analyze**

Run: `cd yucai/client && flutter test test/account/domain/value_objects_category_test.dart && flutter analyze lib/core/widgets/form_section.dart lib/account/domain/value_objects.dart`
Expected: test PASS(含 example 测);analyze 0 error(FormSection trailing 默认 null,现有调用不破坏)。

- [ ] **Step 6: Commit**

```bash
git add yucai/client/lib/account/domain/value_objects.dart yucai/client/lib/core/widgets/form_section.dart yucai/client/test/account/domain/value_objects_category_test.dart
git commit -m "feat(account): AccountCategory.example + FormSection trailing(对齐 OD cat-hint/badge)"
```

---

### Task 2: account_form_page 3 改动(cat-hint banner + notes + dynTitle badge)

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_form_page.dart`
- Create: `yucai/client/test/account/presentation/pages/account_form_page_test.dart`

**Interfaces:**
- Consumes: Task 1 `AccountCategory.example`、`FormSection.trailing`。现有 `CreateAccountParams.notes`/`UpdateAccountParams.notes`、`Account.notes`、`AppColors.accentSoft/accentHover/accent`、`LucideIcons.info`。
- Produces: account_form_page 对齐 OD(cat-hint banner + notes + badge)。

- [ ] **Step 1: Write the failing widget test**

Create `account_form_page_test.dart`(参照 `accounts_page_test.dart` mocktail + BlocProvider 模式):

```dart
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/get_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/pages/account_form_page.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';

class _MockList extends Mock implements ListAccountsUseCase {}
class _MockCreate extends Mock implements CreateAccountUseCase {}
class _MockDelete extends Mock implements DeleteAccountUseCase {}
class _MockGet extends Mock implements GetAccountUseCase {}
class _MockUpdate extends Mock implements UpdateAccountUseCase {}

class _FakeCurrencyBloc extends Fake implements CurrencyBloc {
  _FakeCurrencyBloc(this._state);
  final CurrencyState _state;
  @override
  CurrencyState get state => _state;
  @override
  Stream<CurrencyState> get stream => Stream.value(_state);
}

AccountBloc _bloc() {
  registerFallbackValue(const CreateAccountParams(
    name: '', accountType: AccountType.asset, category: AccountCategory.savings,
    currencyCode: 'CNY', initialBalanceCents: 0, ownership: Ownership.personal,
  ));
  return AccountBloc(
    list: _MockList(),
    create: _MockCreate(),
    delete: _MockDelete(),
    get: _MockGet(),
    update: _MockUpdate(),
  );
}

void main() {
  testWidgets('cat-hint banner + notes + badge render(创建模式 savings)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<AccountBloc>(
        create: (_) => _bloc(),
        child: const AccountFormPage(),
      ),
    ));
    await tester.pump();

    // ① cat-hint banner:含 description + "示例:" + example
    expect(find.textContaining('示例:'), findsOneWidget);
    expect(find.textContaining(AccountCategory.savings.example), findsOneWidget);

    // ② notes TextFormField(备注 section,placeholder 含"补充说明")
    expect(find.textContaining('补充说明'), findsOneWidget);

    // ③ dynTitle badge:savings → 资产
    expect(find.text('资产'), findsOneWidget);
  });

  testWidgets('切换 category → cat-hint example + badge 更新', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<AccountBloc>(
        create: (_) => _bloc(),
        child: const AccountFormPage(),
      ),
    ));
    await tester.pump();

    // 点投资 tab
    await tester.tap(find.text('投资'));
    await tester.pump();

    expect(find.textContaining(AccountCategory.investment.example), findsOneWidget);
    expect(find.text('资产'), findsOneWidget); // 投资 → 资产
  });

  testWidgets('编辑模式预填 notes', (tester) async {
    final existing = const Account(
      id: 'a1', name: '测试', accountType: AccountType.asset,
      category: AccountCategory.savings, currencyCode: 'CNY',
      initialBalanceCents: 0, currentBalanceCents: 0,
      ownership: Ownership.personal, status: AccountStatus.active,
      notes: '我的备注内容',
    );
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<AccountBloc>(
        create: (_) => _bloc(),
        child: AccountFormPage(existing: existing),
      ),
    ));
    await tester.pump();

    expect(find.text('我的备注内容'), findsOneWidget);
  });
}
```

> **已确认全链路就绪**:`Account.notes` 存在([account_entity.dart:71](../../yucai/client/lib/account/domain/entities/account_entity.dart#L71) `final String notes;`),mapper `dto.hasNotes() ? dto.notes : ''`([account_mapper.dart:29](../../yucai/client/lib/account/data/mappers/account_mapper.dart#L29)),remote_ds `if (p.notes.isNotEmpty) req.notes = p.notes`([account_remote_ds.dart:120](../../yucai/client/lib/account/data/account_remote_ds.dart#L120)/180)已传 server。本 task 只补 form → params(Task 2 Step 7),remote_ds 已 params → proto。`AccountBloc` 构造签名参照 `account_bloc_test.dart`。

- [ ] **Step 2: Run test to verify it fails**

Run: `cd yucai/client && flutter test test/account/presentation/pages/account_form_page_test.dart`
Expected: FAIL(cat-hint banner/notes/badge 未实现;`find.text('资产')` 等找不到)。

- [ ] **Step 3: Add _notesCtrl + 预填 + dispose**

Modify `account_form_page.dart` `_AccountFormPageState`:

- 字段区(现有 `_nameCtrl` 旁)加:`final _notesCtrl = TextEditingController();`
- `initState`(现有预填块末尾,`_bundle.loanNextPaymentDate = e.loanNextPaymentDate;` 后)加:`_notesCtrl.text = e.notes;`
- `dispose`(`_nameCtrl.dispose();` 旁)加:`_notesCtrl.dispose();`

- [ ] **Step 4: Replace Text(description) → cat-hint banner**

`account_form_page.dart` build 方法,把 [:370-373](../../yucai/client/lib/account/presentation/pages/account_form_page.dart#L370):

```dart
                        const SizedBox(height: AppSpacing.sm),
                        Text(_category.description,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                        const SizedBox(height: AppSpacing.lg),
```

替换为:

```dart
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
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
                        ),
```

- [ ] **Step 5: Add dynTitle badge to category section**

`account_form_page.dart` category FormSection([:420](../../yucai/client/lib/account/presentation/pages/account_form_page.dart#L420)),把:

```dart
                        FormSection(
                          title: '${_category.label}信息',
                          children: categoryFieldsWidget(_category, _bundle,
                              currencySymbol: currencySymbolOf(_currency)),
                        ),
```

替换为:

```dart
                        FormSection(
                          title: '${_category.label}信息',
                          trailing: _kindBadge(_category),
                          children: categoryFieldsWidget(_category, _bundle,
                              currencySymbol: currencySymbolOf(_currency)),
                        ),
```

并在 `_AccountFormPageState` 加 `_kindBadge` 方法(类内,`_initialCentsForCreate` 后):

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

- [ ] **Step 6: Add notes 备注 section**

`account_form_page.dart` build,在 category FormSection 后、`FormActions` 前([:425](../../yucai/client/lib/account/presentation/pages/account_form_page.dart#L425) `const SizedBox(height: AppSpacing.xl)` 前)加:

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

- [ ] **Step 7: Pass notes to params**

`_buildCreate`([:250](../../yucai/client/lib/account/presentation/pages/account_form_page.dart#L250) `CreateAccountParams(...)` 内)加字段(在 `ownership: _ownership,` 后):

```dart
      notes: _notesCtrl.text.trim(),
```

`_buildUpdate`([:205](../../yucai/client/lib/account/presentation/pages/account_form_page.dart#L205) `UpdateAccountParams(...)` 内)加(在 `cardNumberTail: _bundle.cardNumberTailCtrl.text.trim(),` 后):

```dart
      notes: _notesCtrl.text.trim(),
```

- [ ] **Step 8: Run test to verify it passes + analyze**

Run: `cd yucai/client && flutter test test/account/presentation/pages/account_form_page_test.dart && flutter analyze lib/account/presentation/pages/account_form_page.dart`
Expected: test PASS(3 测:渲染/切换/预填);analyze 0 error。

- [ ] **Step 9: Commit**

```bash
git add yucai/client/lib/account/presentation/pages/account_form_page.dart yucai/client/test/account/presentation/pages/account_form_page_test.dart
git commit -m "feat(account/form): cat-hint banner + notes 字段 + dynTitle badge(对齐 OD)"
```

---

### Task 3: 回归 + analyze 基线

**Files:** 无新文件(验证)。

- [ ] **Step 1: account 全量测**

Run: `cd yucai/client && flutter test test/account/`
Expected: PASS(含 Task 1/2 新测;`account_detail_page_test` 预存 fail 跳过,out-of-scope)。

- [ ] **Step 2: analyze 基线**

Run: `cd yucai/client && flutter analyze lib/account/ lib/core/widgets/form_section.dart`
Expected: 22 基线(全 `*.pbserver.dart`,无新 error)。

- [ ] **Step 3: flutter run 手动验证(可选)**

Run: `cd yucai/client && flutter run -d windows`
验证:account form 创建/编辑模式 —— cat-hint banner(描述+示例)、notes 输入→保存→重开预填、dynTitle badge(资产/负债,切 category 变)。

- [ ] **Step 4: Commit(若有手动 fix)**

若手动验证发现小问题,fix + commit。否则无新 commit。

---

## 实施顺序依赖图

```
Task 1 (AccountCategory.example + FormSection.trailing) ─→ Task 2 (account_form_page 3 改动) ─→ Task 3 (回归)
```

Task 2 依赖 Task 1(example/trailing)。Task 3 最后。
