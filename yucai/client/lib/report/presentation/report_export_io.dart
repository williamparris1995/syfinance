/// F45 T2 生产缝接线:ReportExportService 四缝的平台实现。
///
/// presentation 侧就近(T1 硬约束:export 域 report_export_service.dart
/// 保持纯 Dart,零 FilePicker/url_launcher/flutter 依赖;具体平台实现由
/// 页面 handler 经本文件注入)。先例:settings `_showExportArchive`
/// (FilePicker.saveFile + 防御性自写照守卫)、feedback_launcher
/// `LaunchUrlFn`(url_launcher externalApplication)。
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import 'package:yucai_client/report/export/report_export_service.dart';

/// Noto 字体资产路径(pdf 渲染中文字形源;pubspec assets 已注册)。
const String kReportFontAssetPath = 'assets/fonts/NotoSansSC-Regular.ttf';

/// 生产导出服务:注入缝接平台实现。
ReportExportService createReportExportService() => ReportExportService(
      // 桌面单后缀形态:格式切换由页面小菜单先行,保存对话框锁定单
      // 扩展名(file_picker 11 saveFile 的 allowedExtensions;文档注明
      // 过滤器仅为建议,不强制)。
      savePicker: ({dialogTitle, fileName, bytes}) {
        final dot = fileName?.lastIndexOf('.');
        final ext = (dot != null && dot >= 0 && dot + 1 < fileName!.length)
            ? fileName.substring(dot + 1)
            : null;
        return FilePicker.saveFile(
          dialogTitle: dialogTitle,
          fileName: fileName,
          type: ext == null ? FileType.any : FileType.custom,
          allowedExtensions: ext == null ? null : [ext],
          bytes: bytes,
        );
      },
      // 防御性自写照(settings _showExportArchive 同款守卫):Windows
      // file_picker saveFile(bytes:) 会自行落盘 —— 仅当目标文件尚不
      // 存在时才补写(幂等守卫,勿无条件双写)。
      writeBytes: (path, bytes) async {
        if (!kIsWeb && !File(path).existsSync()) {
          await File(path).writeAsBytes(bytes);
        }
      },
      // FR-4 exists 前置(照 debt_detail _openAttachment 先例):文件被
      // 移动/删除 → 直接失败(false)走页面兜底 toast,不触 url_launcher。
      launchUrl: (url) async {
        if (!File.fromUri(url).existsSync()) return false;
        return launchUrl(url, mode: LaunchMode.externalApplication);
      },
      fontSource: () => rootBundle.load(kReportFontAssetPath),
    );
