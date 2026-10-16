import 'package:flutter/material.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

/// F62 FR-2/ADR-2 —— 灰显过滤账户选择器。
///
/// 包装既有 [DropdownButtonFormField]:候选池全量渲染,不兼容项灰显
/// (disabled MenuItem)+ 副文案原因句(如「信用卡不能作为到账卡」)——
/// 冲突在设计上不可能选出,替代事后警示条(About Face:预防优于纠正;
/// NN/g 下拉准则:灰显而非隐藏,让用户知道选项存在且为何不可选)。
///
/// 兼容性数据源 = domain [DebtSubtypeAffinity] 白名单(语义单一事实源):
/// 「负债账户」原因句按 `account.category.name` 字符串比对消费其 compatible
/// 键集合(loan/creditCard/otherLiability)—— debt domain 对 account 的
/// port 约定沿用。其余判定(资产∧active / creditCard)在本组件内直接比对
/// account 域枚举 —— presentation 层 import account 域为既有约定,不走
/// 字符串 port(评审 M-1)。
enum FilteredAccountMode {
  /// 到账卡(sourceAccount:钱到账的资产账户)。
  disbursement,

  /// 挂接卡(信用卡分期的并账目标)。
  cardMount,
}

/// 灰显过滤选择器(无内部状态:选中值由父持有)。
class FilteredAccountPicker extends StatelessWidget {
  const FilteredAccountPicker({
    super.key,
    required this.mode,
    required this.accounts,
    required this.value,
    required this.onChanged,
    this.hint,
    this.validator,
  });

  final FilteredAccountMode mode;

  /// 全量候选池(调用方经 AccountVisibility.userVisible 滤掉 isSystem
  /// 载体户;灰显项保留在本组件内渲染)。
  final List<Account> accounts;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? hint;
  final FormFieldValidator<String>? validator;

  /// 兼容判定(design LLD:到账卡=资产类∧active;挂卡=creditCard)。
  bool _compatible(Account a) => switch (mode) {
        FilteredAccountMode.disbursement =>
          a.accountType == AccountType.asset &&
              a.status == AccountStatus.active,
        FilteredAccountMode.cardMount =>
            a.category == AccountCategory.creditCard,
      };

  /// 不可选原因句(prototype v18 debt-form-ux 文案口径)。
  String _reason(Account a) => switch (mode) {
        FilteredAccountMode.disbursement => a.category ==
                AccountCategory.creditCard
            ? '信用卡不能作为到账卡'
            // 载体类别 = DebtSubtypeAffinity.compatible 键集合(白名单
            // 数据源消费点:贷款/其他负债统一按「负债账户」给原因)。
            : DebtSubtypeAffinity.compatible.containsKey(a.category.name)
                ? '负债账户不可作为到账账户'
                : a.status != AccountStatus.active
                    ? '账户已归档'
                    : '不可作为到账账户',
        FilteredAccountMode.cardMount => '仅信用卡账户可挂接',
      };

  @override
  Widget build(BuildContext context) {
    final dec = InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.yucai.muted, fontSize: 14),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      filled: true,
      fillColor: context.yucai.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.yucai.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.yucai.accent, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.yucai.negative, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.yucai.negative, width: 1),
      ),
      errorStyle: TextStyle(color: context.yucai.negative, fontSize: 11.5),
    );
    return DropdownButtonFormField<String>(
      // 评审 M-2:新代码不用废弃 API(value → initialValue;FormField 的
      // didUpdateWidget 会随父态刷新回显,受控清空语义保留)。
      initialValue: value,
      isExpanded: true,
      decoration: dec,
      items: [
        for (final a in accounts)
          DropdownMenuItem(
            value: a.id,
            enabled: _compatible(a),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.yucai.fg, fontSize: 14),
                  ),
                ),
                if (!_compatible(a)) ...[
                  const SizedBox(width: 10),
                  // 副文案原因句:灰显项为何不可选(联动可解释性)。
                  Flexible(
                    child: Text(
                      _reason(a),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: context.yucai.muted, fontSize: 11.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
      onChanged: onChanged,
      validator: validator,
    );
  }
}
