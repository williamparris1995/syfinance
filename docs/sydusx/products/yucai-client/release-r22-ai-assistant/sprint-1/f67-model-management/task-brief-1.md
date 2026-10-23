# Task Brief T1 — domain 契约

- worktree `.claude/worktrees/r22-f67`(分支 feature/r22-f67)。TDD;不碰 server/F46/既有生产文件。
- 必读:同目录 design.md(ADR-7/ADR-4/HLD);`lib/assistant/domain/engine_state.dart`(ModelState 照此家法:sealed+值相等+toString 全 ASCII);`lib/assistant/domain/model_store_port.dart`(既有 port 不动)。
- 产出:
  1. `lib/assistant/domain/model_state.dart`:sealed 五态——ModelNotDownloaded/ModelDownloading({int receivedBytes,int totalBytes,int bytesPerSec})/ModelPaused({int receivedBytes,int totalBytes})/ModelReady/ModelError(ModelFailureReason{network,corrupt,canceled?按需});值相等(带参态按字段);toString 全 ASCII。
  2. `lib/assistant/domain/model_manager_port.dart`:abstract ModelManagerPort{Future<void> download();void pause();void cancel();Future<void> delete();ValueListenable<ModelState> get state;Future<int> diskUsageBytes();ModelManifest get manifest;} + class ModelManifest{repo,file,sha256,totalBytes}——**钉死常量**:repo=`Qwen/Qwen3-4B-Instruct-2507-GGUF`、file=官方仓 Q4_K_M 文件名(执行期以官方仓实名为准,查证后钉死写注释来源)、sha256 与 totalBytes 留 TODO 占位(T3 前由控制器补真值——或你可用 WebSearch 查证官方仓文件与体积,sha256 若不可得则标注「发布前首下校验回填」,机制上校验逻辑照写)。
  3. 单测:五态构造/值相等/ASCII/manifest 常量形状。
- 验证门:flutter test test/assistant/ 绿;analyze 459 零新增;git diff yucai/server 空。
- commit:`feat(assistant): F67-T1 模型域契约`。汇报含:官方仓文件名查证结论与来源。
