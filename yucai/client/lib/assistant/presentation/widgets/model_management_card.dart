/// F65 T4「AI 助手」端侧模型管理卡(spec FR-3;ADR-4;视觉事实源 =
/// prototype v19 ui/assistant-chat-states.html「AI 助手 · 端侧模型管理」卡,
/// 措辞照其基调)。
///
/// 与 F46「AI 分析师」(BYOK 报告解读)并列的独立卡,语义彻底分离:本卡
/// 零端点/零 Key/零云选项(纯内嵌独立运行),只做三件事——
/// - 启用开关:[AssistantSettings.setConfig]{enabled} 行内直改落盘,中文
///   语境无需弹窗确认(F46 的首启用免责流不适用:数据不出本机);
/// - 模型行:绑 [ModelManagerPort.state] 五态渲染(未下载引导下载 /
///   下载中进度条+暂停 / 已暂停续传 / 失败双因区分文案+重试(corrupt =
///   从零,删 .part 由 impl.download() 承担 ADR-3)/ 就绪展示占用+删除,
///   删除 destructive 必经确认对话框);
/// - 引擎行:绑 [EngineManager.state] 四态(未运行 / 启动中转圈小图标 —
///   F66 拍板:冷启 3-8s 须显动效 / 运行中 / 异常+重试)。
///
/// 装配:构造全依赖注入(照 LlmSettingsCard 家法);settings 页经
/// getIt isRegistered 守卫解析三依赖后挂卡(core/di 1m 段已全部注册,
/// 本卡不自注册)。零裸色:全部走 `context.yucai` 令牌。
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/assistant/data/assistant_settings_store.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_manager_port.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// 设置页「AI 助手」卡(v19:启用行 / 模型行(+下载进度对照) / 引擎行 /
/// 数据与隐私行)。
class ModelManagementCard extends StatelessWidget {
  const ModelManagementCard({
    super.key,
    required this.settings,
    required this.modelManager,
    required this.engineManager,
  });

  /// 助手配置仓储(启用开关读写缝;生产 = 1m 注册件,测试注入 fake)。
  final AssistantSettings settings;

  /// 端侧模型管理 port(下载/暂停/删除 + 状态流;测试注入 fake)。
  final ModelManagerPort modelManager;

  /// 引擎边车管理 port(状态流 + 异常重试;测试注入 fake)。
  final EngineManager engineManager;

  /// 模型体积按钮文案基数:kModelManifest.totalBytes(2497281120 → 2.5GB,
  /// 与 v19 演示数值同源;简报草案「约 2.4GB」为估写,以钉死清单实值为准)。
  static String _gb(int bytes) => '${(bytes / 1e9).toStringAsFixed(1)}GB';

  static String _mbps(int bytesPerSec) =>
      '${(bytesPerSec / 1e6).toStringAsFixed(1)}MB/s';

  @override
  Widget build(BuildContext context) {
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
          Text('AI 助手',
              style: TextStyle(
                  color: context.yucai.fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          // 启用行:说明随模型就绪度切换(v19 ready 卡 / 下载卡两措辞)。
          ValueListenableBuilder<AssistantConfig>(
            valueListenable: settings.listenable,
            builder: (context, cfg, _) =>
                ValueListenableBuilder<ModelState>(
              valueListenable: modelManager.state,
              builder: (context, model, _) => _Row(
                label: '启用 AI 助手',
                description: model is ModelReady
                    ? '浮层问答 · 本机运行 · 只读查询(v1)'
                    : '下载完成后自动进入问答',
                control: Switch(
                  key: const ValueKey('assistantEnableSwitch'),
                  value: cfg.enabled,
                  onChanged: (v) => settings.setConfig(
                      settings.value.copyWith(enabled: v)),
                  activeThumbColor: context.yucai.accent,
                ),
              ),
            ),
          ),
          _sep(context),
          ValueListenableBuilder<ModelState>(
            valueListenable: modelManager.state,
            builder: (context, model, _) => _modelSection(context, model),
          ),
          _sep(context),
          ValueListenableBuilder<EngineState>(
            valueListenable: engineManager.state,
            builder: (context, engine, _) => _engineRow(context, engine),
          ),
          _sep(context),
          const _Row(
            label: '数据与隐私',
            description: '数据全程不出本机;零账号零密钥',
            control: _StatusChip(label: '纯端侧', tone: _ChipTone.neutral),
          ),
        ],
      ),
    );
  }

  /// 模型行 + (downloading 态)下载进度对照行(v19「正在下载模型」dl-row)。
  Widget _modelSection(BuildContext context, ModelState model) {
    final t = context.yucai;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switch (model) {
          ModelNotDownloaded() => _Row(
              label: '模型',
              description: '数据全程不出本机',
              control: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _StatusChip(label: '未下载', tone: _ChipTone.neutral),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    key: const ValueKey('assistantDownloadButton'),
                    onPressed: modelManager.download,
                    child: Text(
                        '下载模型(约 ${_gb(modelManager.manifest.totalBytes)})'),
                  ),
                ],
              ),
            ),
          ModelDownloading() => _Row(
              label: '模型',
              description:
                  'Qwen3-4B · ${_gb(model.totalBytes)} · v1',
              control: const _StatusChip(
                  label: '下载中', tone: _ChipTone.warn),
            ),
          ModelPaused() => _Row(
              label: '模型',
              description:
                  '已下载 ${_gb(model.receivedBytes)} / ${_gb(model.totalBytes)} · 可断点续传',
              control: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _StatusChip(label: '已暂停', tone: _ChipTone.warn),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    key: const ValueKey('assistantResumeButton'),
                    onPressed: modelManager.download,
                    child: const Text('继续下载'),
                  ),
                ],
              ),
            ),
          ModelError() => _Row(
              label: '模型',
              description: model.reason == ModelFailureReason.network
                  ? '网络中断 · 断点已保留,重试可续传'
                  : '文件校验失败 · 重试将从零重新下载',
              control: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _StatusChip(label: '下载失败', tone: _ChipTone.negative),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    key: const ValueKey('assistantModelRetryButton'),
                    onPressed: modelManager.download,
                    // corrupt 重试 = 从零重下(删 .part 由 impl 承担,
                    // ADR-3);network 重试 = .part 续传 —— 文案区分。
                    child: Text(model.reason == ModelFailureReason.network
                        ? '重试'
                        : '重新下载'),
                  ),
                ],
              ),
            ),
          ModelReady() => _Row(
              label: '模型',
              // 占用按文件实查(.gguf 求和)非清单常量(FR-3 版本/占用)。
              descriptionBuilder: (context) => FutureBuilder<int>(
                future: modelManager.diskUsageBytes(),
                builder: (context, snap) => Text(
                  'Qwen3-4B · 占用 ${_gb(snap.data ?? modelManager.manifest.totalBytes)} · v1',
                  style: TextStyle(color: context.yucai.muted, fontSize: 12),
                ),
              ),
              control: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _StatusChip(label: '已就绪', tone: _ChipTone.positive),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    key: const ValueKey('assistantDeleteModelButton'),
                    tooltip: '删除模型',
                    onPressed: () => _confirmDelete(context),
                    icon: Icon(LucideIcons.trash2,
                        size: 18, color: context.yucai.negative),
                  ),
                ],
              ),
            ),
        },
        // downloading 专属:进度对照行(v19 dl-row 逐字基调)。
        if (model is ModelDownloading) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text('正在下载模型',
                    style: TextStyle(
                        color: t.fg,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              TextButton(
                key: const ValueKey('assistantPauseButton'),
                onPressed: modelManager.pause,
                child: const Text('暂停'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${_gb(model.receivedBytes)} / ${_gb(model.totalBytes)} · '
            '${(model.receivedBytes / model.totalBytes * 100).round()}% · '
            '${_mbps(model.bytesPerSec)}',
            style: TextStyle(color: t.muted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: AppRadius.smBorder,
            child: LinearProgressIndicator(
              key: const ValueKey('assistantModelProgress'),
              value: model.receivedBytes / model.totalBytes,
              minHeight: 6,
              backgroundColor: t.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(t.accent),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('可断点续传 · 下载完成后即可离线使用',
              style: TextStyle(color: t.muted, fontSize: 12)),
        ],
      ],
    );
  }

  /// 引擎行:stopped/starting(转圈)/ready/error(异常+重试,FR-3 场景二)。
  Widget _engineRow(BuildContext context, EngineState engine) {
    final Widget control;
    final String description;
    switch (engine) {
      case EngineStopped():
        description = '本机引擎 · 随应用启动';
        control = const _StatusChip(label: '未运行', tone: _ChipTone.neutral);
      case EngineStarting():
        description = '本机引擎 · 随应用启动';
        // F66 拍板:冷启 3-8s 须显加载动效(v19 状态面「引擎启动中」一态)。
        control = const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.sm),
            _StatusChip(label: '启动中', tone: _ChipTone.warn),
          ],
        );
      case EngineReady():
        description = '本机引擎 · 随应用启动';
        control = const _StatusChip(label: '运行中', tone: _ChipTone.positive);
      case EngineError(:final reason):
        description = switch (reason) {
          EngineFailureReason.modelMissing => '模型文件缺失,请先完成模型下载',
          EngineFailureReason.crashed => '引擎进程异常退出',
          EngineFailureReason.startFailed => '引擎启动失败',
        };
        control = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _StatusChip(label: '异常', tone: _ChipTone.negative),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              key: const ValueKey('assistantEngineRetryButton'),
              onPressed: engineManager.ensureReady,
              child: const Text('重试'),
            ),
          ],
        );
    }
    return _Row(label: '引擎', description: description, control: control);
  }

  /// 删除模型确认门(destructive,照本地快照删除先例:AlertDialog + 红色
  /// 确认按钮);确认才调 [ModelManagerPort.delete](在途下载先 cancel +
  /// 引擎 shutdown 联动均由 impl 承担,ADR-5)。
  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除模型?'),
        content: Text(
            '删除后助手将不可用,再次使用需重新下载约 ${_gb(modelManager.manifest.totalBytes)} 模型文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.yucai.negative,
              // F27 FR-1② 豁免(照 settings 页危险按钮先例):negative
              // 状态身份彩底,固定白字双板可辨识(非 accent 面)。
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await modelManager.delete();
  }

  Widget _sep(BuildContext context) => Column(
        children: [
          Divider(height: 1, color: context.yucai.border),
          const SizedBox(height: AppSpacing.md),
        ],
      );
}

/// 设置行(label + description 左,control 右;照 settings 卡 _Row 形态,
/// 本文件私有)。description 可为 builder(ready 态占用走 FutureBuilder)。
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    this.description,
    this.descriptionBuilder,
    required this.control,
  });

  final String label;
  final String? description;
  final Widget Function(BuildContext context)? descriptionBuilder;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final desc = descriptionBuilder?.call(context);
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
              if (description != null || desc != null) ...[
                const SizedBox(height: 2),
                desc ??
                    Text(description!,
                        style: TextStyle(
                            color: context.yucai.muted, fontSize: 12)),
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

/// 状态 chip 色调(全部令牌派生,零裸色)。
enum _ChipTone { neutral, warn, positive, negative }

/// v19 .chip 形态的小状态标签:令牌色低透明底 + 同色描边/文字。
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});

  final String label;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    final color = switch (tone) {
      _ChipTone.neutral => t.muted,
      _ChipTone.warn => t.warn,
      _ChipTone.positive => t.positive,
      _ChipTone.negative => t.negative,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.smBorder,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}
