import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 担保人与合同文件字段组(2026-09 用户需求)—— 债务/债权两表单共用。
///
/// 全部可选:
///  - 担保人 / 担保人联系方式(自由文本,'' = 无);
///  - 合同文件(file_picker 选中之即由表单暂存,提交成功后绑定债务 id;
///    本地附件 v1,不上行)。
///
/// 视觉对齐两表单各自的 _ODField/_ODGrid2/_odDec 私有件(同 token 同尺寸),
/// 独立成件以免双份维护。
class DebtGuarantorContractFields extends StatelessWidget {
  const DebtGuarantorContractFields({
    super.key,
    required this.guarantorNameCtrl,
    required this.guarantorContactCtrl,
    required this.attachmentLabel,
    required this.onPickFile,
    this.onRemoveFile,
  });

  final TextEditingController guarantorNameCtrl;
  final TextEditingController guarantorContactCtrl;

  /// 当前合同文件展示名(已选新文件或编辑态已有附件);null = 未选。
  final String? attachmentLabel;
  final Future<void> Function() onPickFile;

  /// 移除已有附件(仅编辑态已有附件时显示);null = 不显示移除入口。
  final VoidCallback? onRemoveFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _grid2(context, [
          _field(
            context,
            label: '担保人',
            hint: '选填 · 例如：王五',
            child: TextField(
              key: const ValueKey('guarantorNameField'),
              controller: guarantorNameCtrl,
              decoration: _dec(context, hint: '选填 · 例如：王五'),
            ),
          ),
          _field(
            context,
            label: '担保人联系方式',
            hint: '选填 · 电话 / 微信等',
            child: TextField(
              key: const ValueKey('guarantorContactField'),
              controller: guarantorContactCtrl,
              decoration: _dec(context, hint: '选填 · 电话 / 微信等'),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        _field(
          context,
          label: '合同文件',
          hint: '选填 · 借条 / 借款合同等,保存在本机',
          child: _fileTile(context),
        ),
      ],
    );
  }

  Widget _fileTile(BuildContext context) {
    final has = attachmentLabel != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('contractFileTile'),
            onTap: onPickFile,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: context.yucai.surface,
                border: Border.all(color: context.yucai.border, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.paperclip,
                      size: 16,
                      color: has ? context.yucai.accent : context.yucai.muted),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      has ? attachmentLabel! : '点击选择合同文件(可选)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: has ? context.yucai.fg : context.yucai.muted,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(has ? '重新选择' : '选择文件',
                      style: TextStyle(
                          color: context.yucai.accent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        if (has && onRemoveFile != null)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: GestureDetector(
              key: const ValueKey('contractFileRemove'),
              onTap: onRemoveFile,
              child: Text('移除附件',
                  style: TextStyle(
                      color: context.yucai.muted,
                      fontSize: 12,
                      decoration: TextDecoration.underline)),
            ),
          ),
      ],
    );
  }

  // ---- 以下为两表单 _ODField/_ODGrid2/_odDec 的同风格副本(token 一致) ----

  Widget _field(BuildContext context,
      {required String label, String? hint, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.yucai.fg)),
        ),
        child,
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(hint,
                style: TextStyle(
                    color: context.yucai.muted,
                    fontSize: 11.5,
                    height: 1.4)),
          ),
      ],
    );
  }

  Widget _grid2(BuildContext context, List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

InputDecoration _dec(BuildContext context, {String? hint}) => InputDecoration(
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
    );
