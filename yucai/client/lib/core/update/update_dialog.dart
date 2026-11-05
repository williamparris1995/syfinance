// F24 更新链 v2(2026-11-05):app 自管更新对话框(替代 WinSparkle 英文
// 引擎 UI)。状态机:checking → latest / error / available(缓存命中 =
// 「直接安装」,未命中 = 「下载并安装」+ 进度条)→ installing(拉起安装
// 器 + 走退出链,进程 exit 不返回)。
//
// 复用语义(用户实测诉求):下载完成的安装包落 updates/ 缓存,安装失败
// 重试直接复用本地文件零重下;[UpdateCenter.isCached] 长度吻合才算命中。
//
// Zero bare colors(R8):颜色走 context.yucai;文案中文,注释/日志英文
// (照 feedback_form_dialog 先例)。
import 'package:flutter/material.dart';

import 'package:yucai_client/core/di/injection.dart' show getIt;
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/update/update_center.dart';

/// 弹出更新对话框(设置页「检查更新」与托盘菜单共用入口)。
///
/// [center] 注入缝(测试);生产缺省解析 getIt 注册实例(bootstrap 降级
/// 未注册 → null,对话框给出「组件未就绪」错误态,恒不炸)。
Future<void> showUpdateDialog(BuildContext context, {UpdateCenter? center}) {
  UpdateCenter? resolved = center;
  if (resolved == null) {
    try {
      resolved = getIt<UpdateCenter>();
    } catch (_) {
      resolved = null;
    }
  }
  return showDialog(
    context: context,
    builder: (_) => UpdateDialog(center: resolved),
  );
}

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, this.center});

  final UpdateCenter? center;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

enum _Phase { checking, latest, error, available, downloading, installing }

class _UpdateDialogState extends State<UpdateDialog> {
  _Phase _phase = _Phase.checking;
  UpdateInfo? _info;
  bool _cached = false;
  int _received = 0;
  int _total = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _phase = _Phase.checking);
    final center = widget.center;
    if (center == null) {
      setState(() {
        _phase = _Phase.error;
        _error = '更新组件未就绪';
      });
      return;
    }
    final info = await center.fetchLatest();
    if (!mounted) return;
    if (info == null) {
      setState(() {
        _phase = _Phase.error;
        _error = '无法获取版本信息,请检查网络后重试';
      });
      return;
    }
    final hasUpdate =
        await center.isUpdateAvailable(latestVersion: info);
    if (!mounted) return;
    if (!hasUpdate) {
      setState(() => _phase = _Phase.latest);
      return;
    }
    final cached = await center.isCached(info);
    if (!mounted) return;
    setState(() {
      _info = info;
      _cached = cached;
      _phase = _Phase.available;
    });
  }

  /// 下载(未命中缓存)或直接复用缓存安装。安装 = 拉起安装器 + 退出链,
  /// exitApp 不返回(进程结束);异常停留本对话框给出错误 + 重试。
  Future<void> _install() async {
    final center = widget.center;
    final info = _info;
    if (center == null || info == null) return;
    setState(() => _phase = _Phase.installing);
    try {
      if (!_cached) {
        setState(() => _phase = _Phase.downloading);
        await center.install(info, onProgress: (r, t) {
          if (mounted) {
            setState(() {
              _received = r;
              _total = t;
            });
          }
        });
      } else {
        await center.install(info);
      }
      // install → exitApp(never returns);到达此行 = 退出链异常。
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _error = '安装器启动失败,请重试';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _error = '下载或安装失败:$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yucai;
    final info = _info;
    return AlertDialog(
      title: const Text('软件更新'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            switch (_phase) {
              _Phase.checking => Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text('正在检查更新…',
                        style: TextStyle(fontSize: 13, color: t.muted)),
                  ],
                ),
              _Phase.latest => Text('已是最新版本',
                  style: TextStyle(fontSize: 13.5, color: t.fg)),
              _Phase.error => Text(_error ?? '检查失败',
                  style: TextStyle(fontSize: 13.5, color: t.fg)),
              _Phase.available => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('发现新版本 御财 v${info!.version}',
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: t.fg)),
                    const SizedBox(height: 6),
                    Text(
                        _cached
                            ? '安装包已就绪(${info.sizeLabel}),无需重新下载'
                            : '安装包 ${info.sizeLabel},下载后安装',
                        style: TextStyle(fontSize: 12.5, color: t.muted)),
                    if (_cached)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('安装时将自动退出御财并结束助手引擎',
                            style:
                                TextStyle(fontSize: 12, color: t.muted)),
                      ),
                  ],
                ),
              _Phase.downloading => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('正在下载 v${info!.version}(${info.sizeLabel})…',
                        style: TextStyle(fontSize: 13.5, color: t.fg)),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: (_total > 0 && _received >= _total)
                          ? 1
                          : (_total > 0 ? _received / _total : null),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        _total > 0
                            ? '${(_received / 1024 / 1024).toStringAsFixed(1)} / ${(_total / 1024 / 1024).toStringAsFixed(1)} MB'
                            : '连接中…',
                        style: TextStyle(fontSize: 12, color: t.muted)),
                  ],
                ),
              _Phase.installing => Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text('正在启动安装程序,御财即将退出…',
                        style: TextStyle(fontSize: 13, color: t.muted)),
                  ],
                ),
            },
          ],
        ),
      ),
      actions: [
        if (_phase == _Phase.available)
          TextButton(
            onPressed: _install,
            child: Text(_cached ? '直接安装' : '下载并安装'),
          ),
        if (_phase == _Phase.error)
          TextButton(onPressed: _check, child: const Text('重试')),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(
              _phase == _Phase.downloading || _phase == _Phase.installing
                  ? '后台继续'
                  : '稍后'),
        ),
      ],
    );
  }
}
