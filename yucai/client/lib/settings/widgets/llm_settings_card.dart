/// F46 T2「AI 分析师」设置卡(FR-1;prototype v9 settings.html,照
/// TraySettings 卡范式 + F22 first_close_dialog 免责流)。
///
/// 六行:启用 Switch(未启用时配置行半透明禁用,v9 .llm-cfg.off)/服务商
/// 四选(切换预填 base_url + 默认模型名,自定义出「服务端点」输入行)/
/// API Key obscured 输入(仅存本机安全存储)/模型名/城市规模档位/
/// 订阅名明文 Switch。全部写入经 [LlmSettings.setConfig](secure storage
/// 家法);首启用弹 [showLlmDisclaimerDialog],确认才落 enabled+ack,
/// 取消回弹零持久化。
library;

import 'package:flutter/material.dart';

import 'package:yucai_client/core/llm/llm_settings.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/settings/widgets/llm_disclaimer_dialog.dart';

/// provider 切换的预填默认模型名(任务书:glm-4.6 / gpt-4o-mini /
/// deepseek-chat / 自定义=空)。
const _presetModels = <LlmProvider, String>{
  LlmProvider.zhipu: 'glm-4.6',
  LlmProvider.openai: 'gpt-4o-mini',
  LlmProvider.deepseek: 'deepseek-chat',
  LlmProvider.custom: '',
};

/// 设置页「AI 分析师」卡(独立 widget 文件,照 v9 设置页卡结构)。
class LlmSettingsCard extends StatefulWidget {
  const LlmSettingsCard({super.key, required this.settings});

  /// BYOK 配置仓储(写入缝;生产 = getIt 注册件,测试注入 fake)。
  final LlmSettings settings;

  @override
  State<LlmSettingsCard> createState() => _LlmSettingsCardState();
}

class _LlmSettingsCardState extends State<LlmSettingsCard> {
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  late final TextEditingController _baseUrl;

  @override
  void initState() {
    super.initState();
    final cfg = widget.settings.value;
    _apiKey = TextEditingController(text: cfg.apiKey);
    _model = TextEditingController(text: cfg.model);
    _baseUrl = TextEditingController(text: cfg.baseUrl);
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _model.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  /// 全量落盘:文本三字段取控制器现值 + 离散字段取覆盖值(copyWith 忽略
  /// null),一次 setConfig 广播(家法:存储即通知)。
  Future<void> _save({
    bool? enabled,
    bool? disclaimerAck,
    LlmProvider? provider,
    LlmCityTier? cityTier,
    bool? includeNames,
  }) =>
      widget.settings.setConfig(widget.settings.value.copyWith(
        apiKey: _apiKey.text,
        model: _model.text,
        baseUrl: _baseUrl.text,
        enabled: enabled,
        disclaimerAck: disclaimerAck,
        provider: provider,
        cityTier: cityTier,
        includeNames: includeNames,
      ));

  /// 启用开关:关 = 直接落;开 = 首次(未 ack)先弹免责 —— 确认才写
  /// disclaimerAck + enabled,取消/.dismiss 回弹(零持久化,UI 经
  /// listenable 未变即回);已 ack 则直接生效不再弹(FR-1)。
  Future<void> _onEnableChanged(bool v) async {
    if (!v) {
      await _save(enabled: false);
      return;
    }
    if (widget.settings.value.disclaimerAck) {
      await _save(enabled: true);
      return;
    }
    final acked = await showLlmDisclaimerDialog(context);
    if (!mounted || !acked) return; // 取消:开关回弹,不持久化
    await _save(enabled: true, disclaimerAck: true);
  }

  /// 服务商切换:预填 base_url + 默认模型名(写入控制器后统一 _save;
  /// 预设商 URL 钉死 resolvedBaseUrl,自定义留空待用户填)。
  Future<void> _selectProvider(LlmProvider p) async {
    _model.text = _presetModels[p] ?? '';
    _baseUrl.text = LlmEndpoints.preset[p] ?? '';
    await _save(provider: p);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LlmConfig>(
      valueListenable: widget.settings.listenable,
      builder: (context, cfg, _) {
        final enabled = cfg.enabled;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.yucai.surface,
            borderRadius: AppRadius.lgBorder,
            border: Border.all(color: context.yucai.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI 分析师',
                  style: TextStyle(
                      color: context.yucai.fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              _Row(
                label: '启用 AI 分析师',
                control: Switch(
                  key: const ValueKey('llmEnableSwitch'),
                  value: enabled,
                  onChanged: _onEnableChanged,
                  activeThumbColor: context.yucai.accent,
                ),
              ),
              // v9 .llm-cfg.off:未启用 = 半透明 + pointer-events:none。
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: enabled ? 1 : 0.55,
                child: IgnorePointer(
                  ignoring: !enabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sep(context),
                      // 服务商四选:label + 换行铺满(设置页 560px 版心内
                      // 四段 pill 与标签同行放不下,v9 宽画布的行式布局
                      // 适配为堆叠;禁用罩仍覆盖本行)。
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('服务商',
                              style: TextStyle(
                                  color: context.yucai.fg,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: AppSpacing.sm),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<LlmProvider>(
                              key: const ValueKey('llmProviderSeg'),
                              segments: const [
                                ButtonSegment(
                                    value: LlmProvider.zhipu,
                                    label: Text('智谱')),
                                ButtonSegment(
                                    value: LlmProvider.openai,
                                    label: Text('OpenAI')),
                                ButtonSegment(
                                    value: LlmProvider.deepseek,
                                    label: Text('DeepSeek')),
                                ButtonSegment(
                                    value: LlmProvider.custom,
                                    label: Text('自定义')),
                              ],
                              selected: {cfg.provider},
                              showSelectedIcon: false,
                              onSelectionChanged: (s) =>
                                  _selectProvider(s.first),
                            ),
                          ),
                        ],
                      ),
                      _sep(context),
                      _Row(
                        label: 'API Key',
                        description: '仅存本机安全存储',
                        control: _field(
                          key: const ValueKey('llmApiKeyInput'),
                          hint: '••••••••••••••',
                          controller: _apiKey,
                          enabled: enabled,
                          obscure: true,
                        ),
                      ),
                      _sep(context),
                      _Row(
                        label: '模型名',
                        control: _field(
                          key: const ValueKey('llmModelInput'),
                          hint: 'glm-4.6',
                          controller: _model,
                          enabled: enabled,
                        ),
                      ),
                      // 自定义服务商:服务端点输入行(spec FR-1「自定义
                      // base_url 四选」;预设商端点钉死,不出此行)。
                      if (cfg.provider == LlmProvider.custom) ...[
                        _sep(context),
                        _Row(
                          label: '服务端点',
                          description: 'OpenAI 兼容 API 地址(base_url)',
                          control: _field(
                            key: const ValueKey('llmBaseUrlInput'),
                            hint: 'https://api.example.com/v1',
                            controller: _baseUrl,
                            enabled: enabled,
                          ),
                        ),
                      ],
                      _sep(context),
                      _Row(
                        label: '城市规模',
                        control: SegmentedButton<LlmCityTier>(
                          key: const ValueKey('llmCitySeg'),
                          segments: const [
                            ButtonSegment(
                                value: LlmCityTier.tier1, label: Text('一线')),
                            ButtonSegment(
                                value: LlmCityTier.tier2, label: Text('新一线')),
                            ButtonSegment(
                                value: LlmCityTier.tier3, label: Text('二三线')),
                          ],
                          selected: {cfg.cityTier},
                          showSelectedIcon: false,
                          onSelectionChanged: (s) => _save(cityTier: s.first),
                        ),
                      ),
                      _sep(context),
                      _Row(
                        label: '订阅名明文',
                        control: Switch(
                          key: const ValueKey('llmIncludeNamesSwitch'),
                          value: cfg.includeNames,
                          onChanged: (v) => _save(includeNames: v),
                          activeThumbColor: context.yucai.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sep(BuildContext context) => Column(
        children: [
          Divider(height: 1, color: context.yucai.border),
          const SizedBox(height: AppSpacing.md),
        ],
      );

  Widget _field({
    required Key key,
    required String hint,
    required TextEditingController controller,
    required bool enabled,
    bool obscure = false,
  }) =>
      SizedBox(
        width: 200,
        child: TextField(
          key: key,
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          style: const TextStyle(fontSize: 12.5),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
          ),
          onChanged: (_) => _save(),
        ),
      );
}

/// 设置行(label + 可选 description 左,control 右;照 settings_page
/// _PreferenceRow 形态,本文件私有)。
class _Row extends StatelessWidget {
  const _Row({required this.label, this.description, required this.control});

  final String label;
  final String? description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: context.yucai.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(description!,
                    style:
                        TextStyle(color: context.yucai.muted, fontSize: 12)),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        control,
      ],
    );
  }
}
