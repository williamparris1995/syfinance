// F52 FR-1/NFR-2:建户预设目录 —— account domain 纯常量(零 flutter/数据层
// 依赖),presentation 消费。预设是加速层不是类别替代:category 恒为
// creditCard(spec「类别体系原样保留」,花呗落库即 creditCard),故不入字段;
// 经预设建出的账户与手建账户无差别,目录随发版更新但不回溯已建账户。

/// 建户预设值对象:打开表单时预填的字段(全量可编辑,ADR-3)。
class AccountPreset {
  const AccountPreset({
    required this.name,
    required this.institution,
    this.billingDay,
    this.repaymentDay,
    this.hint = '',
  });

  /// 产品名,预填表单名称。
  final String name;

  /// 发放机构,预填表单机构。
  final String institution;

  /// 账单日;null = 不预填(白条类按激活日,建后可改)。
  final int? billingDay;

  /// 还款日;null = 不预填。
  final int? repaymentDay;

  /// 日期为空时的表单提示;空串 = 无提示(花呗日期固定,无需提示)。
  final String hint;
}

/// 预设目录(app 内置,随发版更新;spec FR-1)。
const accountPresets = <AccountPreset>[
  AccountPreset(
    name: '花呗',
    institution: '蚂蚁消费金融',
    billingDay: 1,
    repaymentDay: 9,
  ),
  AccountPreset(
    name: '京东白条',
    institution: '京东',
    hint: '账单日按激活日,建后可改',
  ),
  AccountPreset(
    name: '美团月付',
    institution: '美团',
    hint: '账单日按激活日,建后可改',
  ),
  AccountPreset(
    name: '微信分付',
    institution: '腾讯',
    hint: '账单日按激活日,建后可改',
  ),
];
