/// F45 T2 导出入口 widget 测试(seam = FinancialReportPage 公共构造 +
/// exportService 注入缝替换;真实 bloc + mock ReportAssemblyService +
/// fake 导出四缝 —— FilePicker/url_launcher/rootBundle 零真实依赖)。
///
/// 覆盖:按钮态(非 Loaded 隐藏/Loaded 出现)、格式菜单两格式、
/// 导出成功流(写入 bytes 非空 + toast + 「打开」动作)、取消零副作用、
/// 错误兜底、导出中禁用 + spinner。
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/report/domain/report_assembly_service.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/export/report_export_service.dart';
import 'package:yucai_client/report/presentation/financial_report_bloc.dart';
import 'package:yucai_client/report/presentation/pages/financial_report_page.dart';
import 'package:yucai_client/report/presentation/report_export_io.dart'
    show kReportFontAssetPath;

import '../../export/export_fixture.dart';

class _MockAssembly extends Mock implements ReportAssemblyService {}

/// fake 导出缝记录仪:savePicker/writeBytes/launchUrl 全记录,行为可配置
/// ([cancelPick] 取消、[writeError] 落盘抛错、[pickGate] 悬挂保存对话框)。
class _ExportRecorder {
  final picked = <(String?, String?, Uint8List?)>[];
  final written = <(String, List<int>)>[];
  final launched = <Uri>[];

  bool cancelPick = false;
  Object? writeError;
  Completer<void>? pickGate;

  /// launch 缝抛错(true)—— url_launcher PlatformException 形态
  /// (feedback_launcher S-4 先例:抛错视同失败,兜底 toast)。
  bool launchThrows = false;

  ReportExportService build() => ReportExportService(
        savePicker: ({dialogTitle, fileName, bytes}) async {
          picked.add((dialogTitle, fileName, bytes));
          final gate = pickGate;
          if (gate != null) await gate.future;
          if (cancelPick) return null;
          return 'C:/out/$fileName';
        },
        writeBytes: (path, bytes) async {
          final err = writeError;
          if (err != null) throw err;
          written.add((path, bytes));
        },
        launchUrl: (url) async {
          if (launchThrows) throw Exception('platform');
          launched.add(url);
          return true;
        },
        // widget 测试跑在 FakeAsync:真异步 IO(readAsBytes)的完成回调
        // 永不触发 —— 用同步直读返回已完成的 Future;路径与生产 rootBundle
        // 同源(kReportFontAssetPath,report_export_io 已导出)。
        fontSource: () async => ByteData.sublistView(
            File(kReportFontAssetPath).readAsBytesSync()),
      );
}

/// 把 mock 的 onPhase 命名参数取出并逐阶段回调(同 financial_report_page_test)。
void Function(ReportPhase)? _onPhaseOf(Invocation inv) =>
    inv.namedArguments[const Symbol('onPhase')]
        as void Function(ReportPhase)?;

void main() {
  late _MockAssembly assembly;

  setUpAll(() {
    registerFallbackValue(ReportPeriod.monthly(2026, 8));
  });

  setUp(() {
    assembly = _MockAssembly();
  });

  void stubGenerate(ReportDocument doc) {
    when(() => assembly.generate(any(), onPhase: any(named: 'onPhase')))
        .thenAnswer((inv) async {
      final onPhase = _onPhaseOf(inv);
      for (final p in ReportPhase.values) {
        onPhase?.call(p);
      }
      return doc;
    });
  }

  Widget harness({ReportExportService? exportService}) {
    final bloc = FinancialReportBloc(assembly);
    return MaterialApp(
      home: BlocProvider<FinancialReportBloc>.value(
        value: bloc,
        child: FinancialReportPage(
          initialPeriod: const ReportMonthly(2026, 8),
          exportService: exportService,
        ),
      ),
    );
  }

  /// 生成到 Loaded 并 settle(导出前提态;exportService 须全程同实例
  /// 注入 —— pumpWidget 换树会复用 State 并替换 widget,漏传即丢缝)。
  Future<void> pumpLoaded(
    WidgetTester t, {
    ReportExportService? exportService,
  }) async {
    await t.pumpWidget(harness(exportService: exportService));
    await t.tap(find.byKey(const ValueKey('generateReportButton')));
    await t.pumpAndSettle();
  }

  testWidgets('按钮态:Initial 无导出按钮,Loaded 后页头出现', (t) async {
    stubGenerate(minimalDocument());
    await t.pumpWidget(harness());
    await t.pumpAndSettle();

    // Initial:无报告可导出 → 按钮不渲染(仅 Loaded 态可用)。
    expect(find.byKey(const ValueKey('reportExportButton')), findsNothing);

    await t.tap(find.byKey(const ValueKey('generateReportButton')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('reportExportButton')), findsOneWidget);
    // tooltip 与保存对话框标题同词(文案统一)。
    expect(find.byTooltip('导出财务报告'), findsOneWidget);
  });

  testWidgets('格式菜单:PDF/Markdown 两项;选择即按该格式弹保存对话框',
      (t) async {
    stubGenerate(minimalDocument());
    final rec = _ExportRecorder();
    await pumpLoaded(t, exportService: rec.build());

    await t.tap(find.byKey(const ValueKey('reportExportButton')));
    await t.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('reportExportFormatPdf')), findsOneWidget);
    expect(find.byKey(const ValueKey('reportExportFormatMarkdown')),
        findsOneWidget);

    // 选 Markdown → 保存对话框缝收到该格式默认文件名(T1 defaultFileName:
    // minimalDocument 期 = 2026-08);对话框标题按 T2 任务书「导出财务报告」。
    await t.tap(find.byKey(const ValueKey('reportExportFormatMarkdown')));
    await t.pumpAndSettle();
    expect(rec.picked, hasLength(1));
    expect(rec.picked.single.$1, '导出财务报告');
    expect(rec.picked.single.$2, '御财财务报告-2026年08月.md');
    expect(rec.written, hasLength(1), reason: 'fake 返回路径 → 落盘一次');
  });

  testWidgets('导出成功:PDF 落盘非空 + 成功 toast + 「打开」调 launch 缝',
      (t) async {
    stubGenerate(minimalDocument());
    final rec = _ExportRecorder();
    await pumpLoaded(t, exportService: rec.build());

    await t.tap(find.byKey(const ValueKey('reportExportButton')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('reportExportFormatPdf')));
    await t.pumpAndSettle();

    // fake save 返回路径 → 写入 bytes 非空且为 PDF 头(独立来源断言)。
    expect(rec.written, hasLength(1));
    expect(rec.written.single.$1, 'C:/out/御财财务报告-2026年08月.pdf');
    final bytes = rec.written.single.$2;
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    // 成功 toast + 「打开」动作。
    expect(find.text('报告已导出'), findsOneWidget);
    final openAction = find.byKey(const ValueKey('reportExportOpenAction'));
    expect(openAction, findsOneWidget);

    // 「打开」→ openExported → launch 缝以 file Uri 打开落盘路径。
    await t.tap(openAction);
    await t.pumpAndSettle();
    expect(rec.launched, hasLength(1));
    expect(
        rec.launched.single, Uri.file('C:/out/御财财务报告-2026年08月.pdf'));
  });

  testWidgets('取消保存对话框:零写入零提示零打开', (t) async {
    stubGenerate(minimalDocument());
    final rec = _ExportRecorder()..cancelPick = true;
    await pumpLoaded(t, exportService: rec.build());

    await t.tap(find.byKey(const ValueKey('reportExportButton')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('reportExportFormatPdf')));
    await t.pumpAndSettle();

    // 用户取消 = 零文件写入零状态变化(FR-1):无落盘、无任何 toast、
    // 无打开调用。
    expect(rec.written, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    expect(rec.launched, isEmpty);
  });

  testWidgets('落盘异常:错误 toast 兜底,不误报成功', (t) async {
    stubGenerate(minimalDocument());
    final rec = _ExportRecorder()..writeError = Exception('disk full');
    await pumpLoaded(t, exportService: rec.build());

    await t.tap(find.byKey(const ValueKey('reportExportButton')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('reportExportFormatMarkdown')));
    await t.pumpAndSettle();

    expect(find.text('导出失败,请重试'), findsOneWidget);
    expect(find.text('报告已导出'), findsNothing);
    expect(rec.launched, isEmpty);
  });

  testWidgets('导出中:按钮禁用换 spinner;菜单不再弹;完成恢复', (t) async {
    stubGenerate(minimalDocument());
    final gate = Completer<void>();
    final rec = _ExportRecorder()..pickGate = gate;
    await pumpLoaded(t, exportService: rec.build());

    await t.tap(find.byKey(const ValueKey('reportExportButton')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('reportExportFormatMarkdown')));
    // spinner 为无限动画:活跃期禁用 pumpAndSettle,用定长 pump。
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    // 导出中:按钮内 spinner 顶替图标。
    final spinnerInButton = find.descendant(
      of: find.byKey(const ValueKey('reportExportButton')),
      matching: find.byType(CircularProgressIndicator),
    );
    expect(spinnerInButton, findsOneWidget);

    // 再点按钮:禁用,小菜单不弹(两格式均不可见)。
    await t.tap(find.byKey(const ValueKey('reportExportButton')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(
        find.byKey(const ValueKey('reportExportFormatPdf')), findsNothing);
    expect(
        find.byKey(const ValueKey('reportExportFormatMarkdown')), findsNothing);

    // 放行 → 导出完成:成功 toast,spinner 退场按钮恢复。
    gate.complete();
    await t.pumpAndSettle();
    expect(find.text('报告已导出'), findsOneWidget);
    expect(spinnerInButton, findsNothing);
  });

  testWidgets('「打开」launch 缝抛错:兜底 toast,不静默', (t) async {
    stubGenerate(minimalDocument());
    final rec = _ExportRecorder()..launchThrows = true;
    await pumpLoaded(t, exportService: rec.build());

    await t.tap(find.byKey(const ValueKey('reportExportButton')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('reportExportFormatMarkdown')));
    await t.pumpAndSettle();
    expect(find.text('报告已导出'), findsOneWidget);

    // url_launcher 形态异常 → 视同失败:toast 兜底。
    await t.tap(find.byKey(const ValueKey('reportExportOpenAction')));
    await t.pumpAndSettle();
    expect(find.text('打开失败'), findsOneWidget);
    expect(rec.launched, isEmpty, reason: '抛错路径不应记入成功打开');
  });
}
