import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/assistant/data/model_store_impl.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';

/// F66-T3:ModelStoreImpl 简版(ADR-7)——固定路径存在性三态:
/// 文件在位 / 目录在而文件缺 / 全缺。supportDirFn 缝指 temp 目录,
/// 零真 AppData 触碰(照 LocalSnapshotService.supportDirFn 同款缝)。
void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('f66_model_store_test');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  ModelStoreImpl makeStore() => ModelStoreImpl(supportDirFn: () async => temp);

  /// 期望落位:`<temp>/yucai/models/<defaultModel>.gguf`(ADR-7 固定路径;
  /// 文件名单一事实源 = AssistantConfig.defaultModel)。
  String expectedPath() => [
        temp.path,
        'yucai',
        'models',
        '${AssistantConfig.defaultModel}.gguf',
      ].join(Platform.pathSeparator);

  test('文件在位:modelPath 返回精确路径,isReady=true', () async {
    final file = File(expectedPath())
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);

    final store = makeStore();

    expect(await store.modelPath(), file.path);
    expect(await store.modelPath(), expectedPath());
    expect(await store.isReady(), isTrue);
  });

  test('目录在而文件缺:modelPath=null,isReady=false(FR-2 modelMissing 源)',
      () async {
    Directory([temp.path, 'yucai', 'models'].join(Platform.pathSeparator))
        .createSync(recursive: true);

    final store = makeStore();

    expect(await store.modelPath(), isNull);
    expect(await store.isReady(), isFalse);
  });

  test('全缺:modelPath=null 不抛、不建目录', () async {
    final store = makeStore();

    expect(await store.modelPath(), isNull);
    expect(await store.isReady(), isFalse);
    // 存在性检查不产生副作用(检查非下载,F67 才有创建语义)。
    expect(
      Directory([temp.path, 'yucai'].join(Platform.pathSeparator))
          .existsSync(),
      isFalse,
    );
  });

  test('缺省缝构造零 IO(getApplicationSupportDirectory 引用延迟到首调)',
      () {
    // 构造只存函数引用,不触路径解析 —— 可在无插件环境直接构造。
    expect(ModelStoreImpl(), isNotNull);
  });
}
